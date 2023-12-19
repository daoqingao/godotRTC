extends Node
#stores all the const and global players


#CONSTS 
const ChinesePokerScenePath = "res://cardGame/CardGame_ChinesePoker/ChinesePoker.tscn"
const LobbyScenePath = "res://connection/scene/ClientConnect.tscn"
const RPSScenePath = "res://cardGame/CardGame_RPS/CardGame_RPS.tscn"
const HOST_ID = 1;
enum ConnectionActionType {
	PLAYER_SIGNAL_CONNECTED_AND_READIED,
	INIT,
	CARD_PLAYED,
	RESTART,
	PROPAGATE_GAME_ACTION,
}
enum GameType {
	CHINESE_POKER,RPS
}

#all player data that are involved
var peerPlayers = {}
var playerId = 1
var pregeneratedSeed 
var playersSignalConnectedAndReadiedCount = -1
# @onready var RPSScene = preload("res://cardGame/CardGame_RPS/CardGame_RPS.tscn")


func _ready():
	#get_tree().change_scene_to_file(LobbyScenePath)
	# get_tree().change_scene_to_file(ChinesePokerScenePath)


	return

@rpc("any_peer", "call_local")
#propagatedActionType argument is optional argument
func propagateActionType(connectionActionType, newRPSData, propagatedGameActionType=-1):
	if(connectionActionType==ConnectionActionType.RESTART):
		startGame(newRPSData)
	elif(connectionActionType==ConnectionActionType.PLAYER_SIGNAL_CONNECTED_AND_READIED):
		playersSignalConnectedAndReadiedCount+=1
		print("nums amount readied updated",playersSignalConnectedAndReadiedCount)
	elif(connectionActionType==ConnectionActionType.INIT):
		propagateActionToPeers.emit(connectionActionType,newRPSData)
	elif(connectionActionType==ConnectionActionType.PROPAGATE_GAME_ACTION):
		propagateActionToPeers.emit(connectionActionType,newRPSData, propagatedGameActionType)
	else:
		print("propagated action type not found",connectionActionType)
		
func startGame(gameType):
	if(gameType==GameType.RPS):
		hostStartGameInitRPSData()
	elif(gameType==GameType.CHINESE_POKER):
		hostStartGameInitChinesePoker()

func hostStartGameInitRPSData():
	var playerSize = peerPlayers.size()
	playersSignalConnectedAndReadiedCount = 0
	if(playerSize != 2):
		printerr("requires 2 players in the lobby, 2 players not detected")
		return
	get_tree().change_scene_to_file(RPSScenePath)

	if(playerId == 1):
		#must wait for scene to hook up .connect before they can handle propagated action....
		while (self.playersSignalConnectedAndReadiedCount!= 2):
			await get_tree().create_timer(0.25).timeout
		pregeneratedSeed = randi() #this thing will ALWAYS BE THE SAME throughout the game
		propagateActionType.rpc(ConnectionActionType.INIT,{
			peerPlayers= peerPlayers,
			pregeneratedSeed=  pregeneratedSeed
		}) #list of all the players basically.


func hostStartGameInitChinesePoker():
	var humanPlayerSize = peerPlayers.size()

	var propagatedPeerPlayerSize = peerPlayers.duplicate(true)
	var requiredPlayers = 4 #TODO: is at 2 but should be 4
	playersSignalConnectedAndReadiedCount = 0
	# if(playerSize != requiredPlayers):
	# 	printerr("chinese poker requires 4 players")
	# 	print("unable to start chinese poker because it requires 4 players.")
	# 	return

	if(humanPlayerSize < 4):
		#make it so that we fill the rest of the players with bots 
		#bot peerPlayerId will be negative
		for i in range(4-humanPlayerSize): #4-2 = -2
			propagatedPeerPlayerSize[-i-1-1] = -1
		print("not enough people, starting lobby with robots")
		print(propagatedPeerPlayerSize)
		# peerPlayers= {
		# 		1:1, 
		# 		-20:22,
		# 		-3333:3333,
		# 		-4444:4444
		# 	}
	print("starting chinese poker")
	# get_tree().change_scene_to_file(LobbyScenePath)
	get_tree().change_scene_to_file(ChinesePokerScenePath)
	if(playerId == HOST_ID):
		print("waiting for players to connect")
		print(playersSignalConnectedAndReadiedCount)
		print(humanPlayerSize)
		#must wait for scene to hook up .connect before they can handle propagated action....
		while (self.playersSignalConnectedAndReadiedCount < humanPlayerSize):
			await get_tree().create_timer(0.25).timeout
			# print("waiting")
		print("all players are conneted, ready to start")
		print("amount of players connected as humans: ",playersSignalConnectedAndReadiedCount)
		pregeneratedSeed = randi() #this thing will ALWAYS BE THE SAME throughout the game
		# pregeneratedSeed = 2046808109
		propagateActionType.rpc(
			ConnectionActionType.INIT,{
			peerPlayers= propagatedPeerPlayerSize, #this can contain robots and humans
			pregeneratedSeed=pregeneratedSeed
		}) #list of all the players basically.


signal propagateActionToPeers(actionType, newRPSData)

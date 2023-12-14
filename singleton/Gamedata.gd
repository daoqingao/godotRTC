extends Node
#stores all the const and global players


#CONSTS 
const ChinesePokerScenePath = "res://cardGame/CardGame_ChinesePoker/ChinesePoker.tscn"
const LobbyScenePath = "res://connection/scene/ClientConnect.tscn"
const RPSScenePath = "res://cardGame/CardGame_RPS/CardGame_RPS.tscn"
const HOST_ID = 1;
enum ActionType {
	PLAYER_SIGNAL_CONNECTED_AND_READIED,
	INIT,
	CARD_PLAYED,
	RESTART
}
enum GameType {
	CHINESE_POKER,RPS
}

#all player data that are involved
var peerPlayers = {}
var playerId = 20
var pregeneratedSeed 
var playersSignalConnectedAndReadiedCount = -1
# @onready var RPSScene = preload("res://cardGame/CardGame_RPS/CardGame_RPS.tscn")


func _ready():
	# get_tree().change_scene_to_file(LobbyScenePath)
	get_tree().change_scene_to_file(ChinesePokerScenePath)

	return

@rpc("any_peer", "call_local")
func propagateActionType(actionType, newRPSData):
	if(actionType==ActionType.RESTART):
		startGame(newRPSData)
	elif(actionType==ActionType.PLAYER_SIGNAL_CONNECTED_AND_READIED):
		playersSignalConnectedAndReadiedCount+=1
		print("nums amount readied updated",playersSignalConnectedAndReadiedCount)
	else:
		propagateActionToGamemanager.emit(actionType,newRPSData)

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
		propagateActionType.rpc(ActionType.INIT,{
			peerPlayers= peerPlayers,
			pregeneratedSeed=  pregeneratedSeed
		}) #list of all the players basically.


func hostStartGameInitChinesePoker():
	var playerSize = peerPlayers.size()
	var requiredPlayers = 2 #TODO: is at 2 but should be 4
	playersSignalConnectedAndReadiedCount = 0
	if(playerSize != requiredPlayers):
		printerr("chinese poker requires 4 players")
		return

	print("starting chinese poker")
	get_tree().change_scene_to_file(ChinesePokerScenePath)
	if(playerId == HOST_ID):
		#must wait for scene to hook up .connect before they can handle propagated action....
		while (self.playersSignalConnectedAndReadiedCount!= requiredPlayers):
			await get_tree().create_timer(0.25).timeout
		print("all players are conneted, ready to start")
		pregeneratedSeed = randi() #this thing will ALWAYS BE THE SAME throughout the game
		propagateActionType.rpc(
			ActionType.INIT,{
			peerPlayers= peerPlayers,
			pregeneratedSeed=pregeneratedSeed
		}) #list of all the players basically.

signal propagateActionToGamemanager(actionType, newRPSData)

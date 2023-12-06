extends Node
#store for all the data I suppose


#all player data that are involved
var peerPlayers = {}
var playerId = -1
var playerSize = -1


#all the data needed to play rock papers scissor
var RPSData = {
	hostId = -1,
	clientId = -1,

	hostCardsId = [1,2,3],
	clientCardsId = [4,5,6],

	cardsPlayedId = [],

	cardsPlayed = {
		"HOST" = null,
		"CLIENT" = null,
	},
	# playerOrientation = {
	# 	"top": -1,
	# 	"bot": -1,
	# } #who is going to be exactly where
}


@rpc("any_peer", "call_local")
func propagateActionType(actionType, newRPSData):
	propagateActionToGamemanager.emit(actionType,newRPSData)
signal propagateActionToGamemanager(actionType, newRPSData)

@rpc("any_peer", "call_local")
func updateRPSData(HostRPSData):
	print("everyone received data from someone...", str(HostRPSData))
	self.RPSData = HostRPSData

func startGame(gameType):
	playerSize = peerPlayers.size()
		#only the host should have control of what to be doing.
		#there is only one host. is a must 
	if(gameType=="RPS"):
		hostStartGameInitRPSData()



func hostStartGameInitRPSData():
	get_tree().change_scene_to_file("res://cardGame/CardGame_RPS/CardGame_RPS.tscn")
	if(playerSize != 2):
		printerr("requires 2 players in the lobby, 2 players not detected")
		return
	if(playerId!=1):
		return
	#means you are the host, you should do this
	var playerList = peerPlayers.keys()
	RPSData.hostId = 1
	RPSData.clientId = playerList.filter(func(p): return p!=1)[0]
	updateRPSData.rpc(self.RPSData)

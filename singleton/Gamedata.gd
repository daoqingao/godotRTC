extends Node
#store for all the data I suppose


#all player data that are involved
var peerPlayers = {}
var playerId = -1

var pregeneratedSeed 

@onready var RPSScene = preload("res://cardGame/CardGame_RPS/CardGame_RPS.tscn")

func _ready():
	pregeneratedSeed = randi() #this thing will ALWAYS BE THE SAME throughout the game
	

@rpc("any_peer", "call_local")
func propagateActionType(actionType, newRPSData):
	if(actionType=="RESTART"):
		startGame(newRPSData)
	else:
		propagateActionToGamemanager.emit(actionType,newRPSData)

func startGame(gameType):
	if(gameType=="RPS"):
		hostStartGameInitRPSData()

# func handlePropagatedRestartGame(gameType): basically the same 
# 	if(gameType=="RPS"):
# 		hostStartGameInitRPSData()

func hostStartGameInitRPSData():
	var playerSize = peerPlayers.size()
	if(playerSize != 2):
		printerr("requires 2 players in the lobby, 2 players not detected")
		return
	# get_tree().root.add_child(RPSScene)
	print("called to start game.")
	get_tree().change_scene_to_file("res://cardGame/CardGame_RPS/CardGame_RPS.tscn")
	#NOTE oh god this is a race condition, we must WAIT for the node to be ready and connect.... before to propagate anything.
	#must wait for scene to hook up .connect before they can handle propagated action....
	# i dotn know how to make this without making things extra complicated ;
	await get_tree().create_timer(0.5).timeout
	pregeneratedSeed = randi() #this thing will ALWAYS BE THE SAME throughout the game
	if(playerId == 1):
		#you are the host, the following should only be called once to propagate twice.
		print("$$$$$$$$$ attempting to propagate to both here should be called once")
		propagateActionType.rpc("INIT",{
			peerPlayers= peerPlayers,
			pregeneratedSeed=  pregeneratedSeed
		}) #list of all the players basically.

#this gets called twice, already propagated.

signal propagateActionToGamemanager(actionType, newRPSData)

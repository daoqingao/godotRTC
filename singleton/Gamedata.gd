extends Node
#store for all the data I suppose


#all player data that are involved
var peerPlayers = {}
var playerId = -1

var pregeneratedSeed 

@onready var RPSScene = preload("res://cardGame/CardGame_RPS/CardGame_RPS.tscn")

func _ready():
	#debug stuff, dont use this
	get_tree().change_scene_to_file("res://cardGame/CardGame_RPS/CardGame_RPS.tscn")
	#var tr = get_tree()
	#var r = get_tree().current_scene
	get_tree().change_scene_to_file("res://connection/scene/ClientConnect.tscn")

	pregeneratedSeed = randi() #this thing will ALWAYS BE THE SAME throughout the game
	
var playersHandleEmitHookedup = -1
@rpc("any_peer", "call_local")
func propagateActionType(actionType, newRPSData):
	if(actionType=="RESTART"):
		startGame(newRPSData)
	elif(actionType=="playersHandleEmitHookedupREADIED"):
		playersHandleEmitHookedup+=1
		print("nums amount readied updated",playersHandleEmitHookedup)
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
	playersHandleEmitHookedup = 0
	if(playerSize != 2):
		printerr("requires 2 players in the lobby, 2 players not detected")
		return
	get_tree().change_scene_to_file("res://cardGame/CardGame_RPS/CardGame_RPS.tscn")

	if(playerId == 1):
		#must wait for scene to hook up .connect before they can handle propagated action....
		while (self.playersHandleEmitHookedup!= 2):
			await get_tree().create_timer(0.25).timeout
		pregeneratedSeed = randi() #this thing will ALWAYS BE THE SAME throughout the game
		propagateActionType.rpc("INIT",{
			peerPlayers= peerPlayers,
			pregeneratedSeed=  pregeneratedSeed
		}) #list of all the players basically.

#this gets called twice, already propagated.

signal propagateActionToGamemanager(actionType, newRPSData)

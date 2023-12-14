extends Node2D
#chinese poker, aka BT
@onready var BTCard = preload("res://cardGame/CardGame_ChinesePoker/BTCard.tscn")
@onready var camera = $Camera2D
#CONST for this game
enum PlayerLocation {
	SOUTH,WEST,NORTH,EAST
}

## local data that should be kept the same across all instance
#BTData stores the data the represents the state of the game, that should be shared
#only store the things that needs to be shared in here and nothing else to reduce bandwidth
var BTData = {
}
var allPlayerIdList = []
var selfPlayerId = -1

func _ready():
	# print("reading, sohuld be called twice") #gets called twice thats good.....
	Gamedata.propagateActionToGamemanager.connect(handlePropagatedAction)
	Gamedata.propagateActionType.rpc_id(1,Gamedata.ActionType.PLAYER_SIGNAL_CONNECTED_AND_READIED,{})
	


#rpc signals
func handlePropagatedAction(actionType, propagatedData):
	if(actionType==Gamedata.ActionType.CARD_PLAYED):
		handlePropagatedCardPlayed(propagatedData)
	if(actionType==Gamedata.ActionType.INIT):
		handlePropagatedInit(propagatedData)

func handlePropagatedCardPlayed(propagatedData):
	return

func handlePropagatedInit(propagatedData):
	allPlayerIdList = propagatedData.peerPlayers.keys()
	selfPlayerId = Gamedata.playerId
	seed(propagatedData.pregeneratedSeed)
	startGame()



func createCard(cardType,pos,ownerId):
	var card = BTCard.instantiate()
	card.construct({
		cardType = cardType,
		cardPos = pos,
		ownerId = ownerId,
	})
	add_child(card)
	# allCards[cardId] = card
	# card.isPlayed.connect(handleOnCardIsPlayed)	
	return card
func startGame():
	print("started game")
	print(allPlayerIdList)

	#initiate cards for all 4 positions!
	var assignedOrientation = -1 
	for playerIdListIdx in range(allPlayerIdList.size()):
		var playerId = allPlayerIdList[playerIdListIdx] 
		createCard("",Vector2(200,200)*playerIdListIdx,playerId).rotation_degrees = 90*playerIdListIdx
		if selfPlayerId == playerId:
			assignedOrientation = playerIdListIdx
	print("assigned the location of, ", assignedOrientation)
	camera.rotation_degrees = 90*assignedOrientation

# 	if(Gamedata.playerIDList == 1): #you are always on the bottom.....
# 		camera.rotation_degrees = 0
# 	else:
# 		camera.rotation_degrees = 90
# 	initCardsOwn()
# 	initCardsOthers()

# func initCardsOwn():
# 	createCard("",Vector2.ZERO,true,Gamedata.playerId)
# func initCardsOthers():
# 	createCard("",Vector2(200,100),false,Gamedata.playerId)
	

# ###local data
# var allCards = {}
# var cardsOwnId = []
# var cardsNotOwnId = []

# var cardsOwnType = []
# var cardsNotOwnType = []
# var playerType = null

# ###synchronize data
# var RPSRPCData = {
# 	hostId = -1,
# 	clientId = -1,

# 	maxTurns = 3,
# 	hostCardsId = [1,2,3],
# 	clientCardsId = [4,5,6],
# 	#cardRandType = {
# 		#playerTypes.HOST : [], #array of predetermined rock paper or scissor
# 		#playerTypes.CLIENT : [],	
# 	#},
# 	#cardsPlayedId = {
# 		#playerTypes.HOST : null,
# 		#playerTypes.CLIENT : null,	#default is null. 
# 	#},
# 	#score = {
# 		#playerTypes.HOST : 0,
# 		#playerTypes.CLIENT : 0,
# 		#"TIE": 0,
# 	#}
# }

# #rpc signals
# func handlePropagatedAction(actionType, newRPSData):
# 	print("receives", actionType)
# 	if(actionType==actionTypes.CARD_PLAYED):
# 		handlePropagatedCardPlayed(newRPSData)
# 	if(actionType==actionTypes.INIT):
# 		handlePropagatedInit(newRPSData)



	
# func handlePropagatedCardPlayed(propagatedData):	
# 	var card = allCards[propagatedData.cardIdPlayed]
# 	RPSRPCData.cardsPlayedId[propagatedData.playerTypeThatPlayedIt] = card.cardId
# 	card.restSnapPos = Vector2.ZERO
# 	if(RPSRPCData.cardsPlayedId[playerTypes.HOST] != null and RPSRPCData.cardsPlayedId[playerTypes.CLIENT] != null): #wait wyou can just check right here...
# 		#you can just check here when both cards are played
# 		var hostCard = allCards[RPSRPCData.cardsPlayedId[playerTypes.HOST]]
# 		var clientCard = allCards[RPSRPCData.cardsPlayedId[playerTypes.CLIENT]]
# 		var cardToFlip = null

# 		if(hostCard.isOwner == false):
# 			cardToFlip = hostCard
# 		else:
# 			cardToFlip = clientCard
# 		cardToFlip.restSnapPos = TopRevealPos		
# 		await cardToFlip.flipCard()

# 		RPSRPCData.score[checkWhoWonCard()] +=1
# 		RPSRPCData.cardsPlayedId[playerTypes.HOST] = null
# 		RPSRPCData.cardsPlayedId[playerTypes.CLIENT] = null
# 		#check who won bruh 


# func checkWhoWonCard():
# 	var hostCard = allCards[RPSRPCData.cardsPlayedId[playerTypes.HOST]].cardType
# 	var clientCard = allCards[RPSRPCData.cardsPlayedId[playerTypes.CLIENT]].cardType
# 	if(winningCombinations[hostCard]==clientCard):
# 		return playerTypes.HOST
# 	elif winningCombinations[clientCard]==hostCard:
# 		return playerTypes.CLIENT
# 	return "TIE"

# #card signals . no RPC should be set here
# func handleOnCardIsPlayed(card):
# 	print(RPSRPCData.cardsPlayedId)
# 	if(RPSRPCData.cardsPlayedId[playerType]!= null):
# 		return #not allowing you to play more cards until both are cleared
# 	Gamedata.propagateActionType.rpc(actionTypes.CARD_PLAYED,{
# 		cardIdPlayed = card.cardId,
# 		playerTypeThatPlayedIt = playerType
# 	})


# # func handleOnBothCardPlayed():
# # 	Gamedata.propagateActionType.rpc(actionTypes.BOTH_CARDS_PLAYED,{})


# func _ready():
# 	# print("reading, sohuld be called twice") #gets called twice thats good.....
# 	Gamedata.propagateActionToGamemanager.connect(handlePropagatedAction)
# 	Gamedata.propagateActionType.rpc_id(1,"playersHandleEmitHookedupREADIED",{})

# func _process(delta):
# 	ScoreboardText.text = "You are currently: ,"+ str(Gamedata.playerId) + "Host: "+ str(RPSRPCData.score[playerTypes.HOST]) + "CLIENT: "+ str(RPSRPCData.score[playerTypes.CLIENT]) + "TIE: "+ str(RPSRPCData.score["TIE"])

# func test():
# 	print("test herlooo@@@@@@@@@@@@@@@@@@@@@@@")


# func initializeCardsOnBot():
# 	createCard(cardsOwnType[0],		Vector2(100,200),true,cardsOwnId[0])
# 	createCard(cardsOwnType[1],		Vector2(300,200),true,cardsOwnId[1])
# 	createCard(cardsOwnType[2],	Vector2(500,200),true,cardsOwnId[2])
# func initializeCardsOnTop():
# 	createCard(cardsNotOwnType[0],		Vector2(100,-200),false,cardsNotOwnId[0])
# 	createCard(cardsNotOwnType[1],		Vector2(300,-200),false,cardsNotOwnId[1])
# 	createCard(cardsNotOwnType[2],	Vector2(500,-200),false,cardsNotOwnId[2])
	

	
	
# func _on_card_drop_area_2d_area_entered(area):
# 	if(not area is Card):
# 		return
# 	var card: Card = area
# 	card.isInDroppableArea = true

# func _on_card_drop_area_2d_area_exited(area):
# 	if(not area is Card):
# 		return
# 	var card: Card = area
# 	card.isInDroppableArea = false

# func _on_restart_game_button_pressed():
# 	Gamedata.propagateActionType.rpc("RESTART","RPS")

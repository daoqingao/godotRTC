extends Node2D
#chinese poker, aka BT
class_name ChinesePokerGameManager

@onready var BTCard = preload("res://cardGame/CardGame_ChinesePoker/BTCard.tscn")
@onready var camera = $Camera2D

#CONST for this game

enum DirectionOrientation {
	SOUTH,WEST,NORTH,EAST
}

enum ScreenOrientation {
	BOT,LEFT,TOP,RIGHT
}
const PLAYER_COUNT = 4 #ALWAYS 4, the people in the lobby is ALWAYS 4 
const NUM_CARDS_PER_PLAYER = 13 #13 cards per play

## local data that should be kept the same across all instance

var CardsOnPlayersHands = { #THESE ARE ALSO THE INDEX!!!!!!! 0,1,2,3
	DirectionOrientation.SOUTH:{},
	DirectionOrientation.WEST:{},
	DirectionOrientation.NORTH:{},
	DirectionOrientation.EAST:{},
}


var allCards = {} # <cardid : BTCard>
var playedCards = {} # <

# var allPlayerToOrientation = {} #<PlayerId : DirectionOrientation >
# var allOrientationToPlayer = {} #<DirectionOrientation, PlayerId> #idk these should be interchangable right


var allPlayerIdList = []

#this one is not the same across all instance
var selfPlayerId = -1
var selfPlayerOrientation = -1

var selfDirectionOriToScreenOri = {
	# DirectionOrientation.SOUTH:bot,
	# DirectionOrientation.WEST:left,
	# DirectionOrientation.NORTH:top,
	# DirectionOrientation.EAST:right, #each being different depending on the self player 
}

var selfCardsOnHand = {}
var selfCardsPosArrX = []
# var ownCards = CardsOnPlayersHands[selfPlayerOrientation]

func _ready():
	# print("reading, sohuld be called twice") #gets called twice thats good.....
	Gamedata.propagateActionToGamemanager.connect(handlePropagatedAction)
	Gamedata.propagateActionType.rpc_id(1,Gamedata.ActionType.PLAYER_SIGNAL_CONNECTED_AND_READIED,{})

	#stubbed data to init with 4 players
	handlePropagatedInit({
			peerPlayers= {
				1:1,
				20:22,
				3333:3333,
				4444:4444
			},
			pregeneratedSeed=1
	})	
	# Gamedata.playerId = 20 this is done in the gamedata, also need to remove that stub




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
	allPlayerIdList.sort() #make sure the things are consistent, because the index you are in determines the orientation
	#0 is SOUTH, 1 is WEST, 2 IS NORTH, 3 IS EAST, (EXACTLY LIKE THE ENUM)
	selfPlayerId = Gamedata.playerId
	seed(propagatedData.pregeneratedSeed)
	initAllBTCards()
	startGame()



# func createBTCard(cardType,pos,ownerId):
# 	var card = BTCard.instantiate()
# 	card.construct({
# 		cardType = cardType,
# 		cardPos = pos,
# 		ownerId = ownerId,
# 	})
# 	add_child(card)
# 	# allCards[cardId] = card
# 	# card.isPlayed.connect(handleOnCardIsPlayed)	
# 	return card

func initAllBTCards(): 
	return
	
func startGame():
	###init the card game

	#shufflign deck
	var suits = ['hearts', 'diamonds', 'clubs', 'spades']
	var ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
	# suits.shuffle()
	# ranks.shuffle()
	var temporaryCardStack = [] 
	var countsId = 1
	for suit in suits:
		for rank in ranks:
			var card = BTCard.instantiate()
			add_child(card)
			card.initBTCardType(suit,rank,countsId)
			allCards[countsId] = card
			temporaryCardStack.push_back(card)
			countsId +=1
	temporaryCardStack.shuffle()


	print("started game #pretend we are drawing cards here")

	#assigning screen positions and orientations
	for playerIdListIdx in range(PLAYER_COUNT):
		var playerId = allPlayerIdList[playerIdListIdx] 
		var orientation = playerIdListIdx
		if selfPlayerId == playerId:
			selfPlayerOrientation = orientation #which one is you...

	var directionOrientationArr = [
		DirectionOrientation.SOUTH,
		DirectionOrientation.WEST,
		DirectionOrientation.NORTH,
		DirectionOrientation.EAST,
	] #making sure that the OUR player in the FRONT will be FIRST AND BOTTOM
	var firstHalf = directionOrientationArr.slice(0, selfPlayerOrientation)
	var secondHalf = directionOrientationArr.slice(selfPlayerOrientation, directionOrientationArr.size())
	directionOrientationArr =  secondHalf + firstHalf
	

	for currentScreenOrientation in range(PLAYER_COUNT): #bot left top right, in that order, the game will be played like that too.
		var currentDirectionOrientation = directionOrientationArr[currentScreenOrientation] #first one will be selfPlayerOrientation #could be west and you are bot
		selfDirectionOriToScreenOri[currentDirectionOrientation] = currentScreenOrientation

		var playerId = allPlayerIdList[currentDirectionOrientation] #playerOrientation is interchangable with the index in the allPlayerIdList
		distributeCards({
			temporaryCardStack = temporaryCardStack,
			currentDirectionOrientation = currentDirectionOrientation,
			isOwnedByCurrentPlayer = currentScreenOrientation==ScreenOrientation.BOT,
			playerId = playerId,
			currentScreenOrientation = currentScreenOrientation
		})



	

	#selfDirectionOriToScreenOri will be used in the future to determine where teh cards was played and spawn from where

func distributeCards(data):
	var initY = 300
	var initX = 0
	var offSetX = -600
	var distance = 1280/13
	var counter = 0
	for i in range(NUM_CARDS_PER_PLAYER):
		var card = data.temporaryCardStack.pop_back()
		CardsOnPlayersHands[data.currentDirectionOrientation][card.id] = card
		card.initBTCardOwner(data.isOwnedByCurrentPlayer,data.playerId,data.currentDirectionOrientation,data.currentScreenOrientation)
		if(!data.isOwnedByCurrentPlayer):
			card.restSnapPos = Vector2(initX+distance*counter+offSetX,
			randi() % 600-300
			)
		else: #you do own the card so lets put it on the bottom!!!
			card.restSnapPos = Vector2(initX+distance*counter+offSetX,initY)
		counter+=1  


	


		#bottom player first iteration.
func getDirectionOriEnumStr(value):
	return getEnumStr(DirectionOrientation,value)
func getScreenOriEnumStr(value):
	return getEnumStr(ScreenOrientation,value)
func getEnumStr(enums,value):
	return enums.keys()[value]

# 	if(Gamedata.playerIDList == 1): #you are always on the bottom.....
# 		camera.rotation_degrees = 0
# 	else:
# 		camera.rotation_degrees = 90
# 	initCardsOwn()
# 	initCardsOthers()

# func initCardsOwn():
# 	createBTCard("",Vector2.ZERO,true,Gamedata.playerId)
# func initCardsOthers():
# 	createBTCard("",Vector2(200,100),false,Gamedata.playerId)
	

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
# 	createBTCard(cardsOwnType[0],		Vector2(100,200),true,cardsOwnId[0])
# 	createBTCard(cardsOwnType[1],		Vector2(300,200),true,cardsOwnId[1])
# 	createBTCard(cardsOwnType[2],	Vector2(500,200),true,cardsOwnId[2])
# func initializeCardsOnTop():
# 	createBTCard(cardsNotOwnType[0],		Vector2(100,-200),false,cardsNotOwnId[0])
# 	createBTCard(cardsNotOwnType[1],		Vector2(300,-200),false,cardsNotOwnId[1])
# 	createBTCard(cardsNotOwnType[2],	Vector2(500,-200),false,cardsNotOwnId[2])
	

	
	
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

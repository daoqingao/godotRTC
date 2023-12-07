extends Node2D

@onready var Card = preload("res://fab/card/Card.tscn")
@onready var TopRevealPos = $TopRevealPos.position
#let just play rock paper sissors bruh
@onready var ScoreboardText = $ScoreboardText
###schemas

var cardTypes = {
	ROCK="ROCK",
	PAPER="PAPER",
	SCISSOR="SCISSOR",
} 

var winningCombinations = {
	  "ROCK": "SCISSOR",
	  "PAPER": "ROCK",
	  "SCISSOR": "PAPER",
  }
var playerTypes = {
	HOST="HOST",
	CLIENT = "CLIENT"
}
var actionTypes = {
	INIT = "INIT",
	CARD_PLAYED="CARD_PLAYED",
}

var cardRandNumToType = {
	0:"ROCK",
	1:"PAPER",
	2:"SCISSOR",
}
###local data
var allCards = {}
var cardsOwnId = []
var cardsNotOwnId = []

var cardsOwnType = []
var cardsNotOwnType = []
var playerType = null

###synchronize data
var RPSRPCData = {
	hostId = -1,
	clientId = -1,

	maxTurns = 3,
	hostCardsId = [1,2,3],
	clientCardsId = [4,5,6],
	cardRandType = {
		playerTypes.HOST : [], #array of predetermined rock paper or scissor
		playerTypes.CLIENT : [],	
	},
	cardsPlayedId = {
		playerTypes.HOST : null,
		playerTypes.CLIENT : null,	#default is null. 
	},
	score = {
		playerTypes.HOST : 0,
		playerTypes.CLIENT : 0,
		"TIE": 0,
	}
}

#rpc signals
func handlePropagatedAction(actionType, newRPSData):
	print("receives", actionType)
	if(actionType==actionTypes.CARD_PLAYED):
		handlePropagatedCardPlayed(newRPSData)
	if(actionType==actionTypes.INIT):
		handlePropagatedInit(newRPSData)


#handlers RPC should only be set here, this gets called in both sides
func handlePropagatedInit(propagatedData):
	print("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ called to init, should only be claled rtwice")
	#this only just sets the 
	var playerList = propagatedData.peerPlayers.keys()
	RPSRPCData.hostId = 1
	RPSRPCData.clientId = playerList.filter(func(p): return p!=1)[0]
	seed(propagatedData.pregeneratedSeed)
	for i in RPSRPCData.maxTurns:
		RPSRPCData.cardRandType[playerTypes.HOST].push_back(cardRandNumToType[randi()%2]) #can be 1 2 3 but they should be both be in sync... I hope
		RPSRPCData.cardRandType[playerTypes.CLIENT].push_back(cardRandNumToType[randi()%2])
	print("are these 2 data in sync please", RPSRPCData)
	startGame()

	
func handlePropagatedCardPlayed(propagatedData):	
	var card = allCards[propagatedData.cardIdPlayed]
	RPSRPCData.cardsPlayedId[propagatedData.playerTypeThatPlayedIt] = card.cardId
	card.restSnapPos = Vector2.ZERO
	if(RPSRPCData.cardsPlayedId[playerTypes.HOST] != null and RPSRPCData.cardsPlayedId[playerTypes.CLIENT] != null): #wait wyou can just check right here...
		#you can just check here when both cards are played
		var hostCard = allCards[RPSRPCData.cardsPlayedId[playerTypes.HOST]]
		var clientCard = allCards[RPSRPCData.cardsPlayedId[playerTypes.CLIENT]]
		var cardToFlip = null

		if(hostCard.isOwner == false):
			cardToFlip = hostCard
		else:
			cardToFlip = clientCard
		cardToFlip.restSnapPos = TopRevealPos		
		await cardToFlip.flipCard()

		RPSRPCData.score[checkWhoWonCard()] +=1
		RPSRPCData.cardsPlayedId[playerTypes.HOST] = null
		RPSRPCData.cardsPlayedId[playerTypes.CLIENT] = null
		#check who won bruh 


func checkWhoWonCard():
	var hostCard = allCards[RPSRPCData.cardsPlayedId[playerTypes.HOST]].cardType
	var clientCard = allCards[RPSRPCData.cardsPlayedId[playerTypes.CLIENT]].cardType
	if(winningCombinations[hostCard]==clientCard):
		return playerTypes.HOST
	elif winningCombinations[clientCard]==hostCard:
		return playerTypes.CLIENT
	return "TIE"

#card signals . no RPC should be set here
func handleOnCardIsPlayed(card):
	print(RPSRPCData.cardsPlayedId)
	if(RPSRPCData.cardsPlayedId[playerType]!= null):
		return #not allowing you to play more cards until both are cleared
	Gamedata.propagateActionType.rpc(actionTypes.CARD_PLAYED,{
		cardIdPlayed = card.cardId,
		playerTypeThatPlayedIt = playerType
	})


# func handleOnBothCardPlayed():
# 	Gamedata.propagateActionType.rpc(actionTypes.BOTH_CARDS_PLAYED,{})


func _ready():
	# print("reading, sohuld be called twice") #gets called twice thats good.....
	Gamedata.propagateActionToGamemanager.connect(handlePropagatedAction)

func _process(delta):
	ScoreboardText.text = "You are currently: ,"+ str(Gamedata.playerId) + "Host: "+ str(RPSRPCData.score[playerTypes.HOST]) + "CLIENT: "+ str(RPSRPCData.score[playerTypes.CLIENT]) + "TIE: "+ str(RPSRPCData.score["TIE"])

func startGame():
	var hostId = RPSRPCData.hostCardsId
	var clientId =  RPSRPCData.clientCardsId
	if(Gamedata.playerId == 1): #you are always on the bottom.....
		cardsOwnType = RPSRPCData.cardRandType[playerTypes.HOST]
		cardsNotOwnType = RPSRPCData.cardRandType[playerTypes.CLIENT]
		playerType = playerTypes.HOST
		cardsOwnId = hostId
		cardsNotOwnId = clientId
	else: #you are client
		cardsOwnType = RPSRPCData.cardRandType[playerTypes.CLIENT]
		cardsNotOwnType = RPSRPCData.cardRandType[playerTypes.HOST]
		playerType = playerTypes.CLIENT
		cardsNotOwnId = hostId
		cardsOwnId = clientId
	initializeCardsOnBot()
	initializeCardsOnTop()

func initializeCardsOnBot():
	createCard(cardsOwnType[0],		Vector2(100,200),true,cardsOwnId[0])
	createCard(cardsOwnType[1],		Vector2(300,200),true,cardsOwnId[1])
	createCard(cardsOwnType[2],	Vector2(500,200),true,cardsOwnId[2])
func initializeCardsOnTop():
	createCard(cardsOwnType[0],		Vector2(100,-200),false,cardsNotOwnId[0])
	createCard(cardsOwnType[1],		Vector2(300,-200),false,cardsNotOwnId[1])
	createCard(cardsOwnType[2],	Vector2(500,-200),false,cardsNotOwnId[2])
	
func createCard(cardType,pos,isOwner,cardId):
	var card = Card.instantiate()
	card.construct({
		cardType = cardType,
		cardPos = pos,
		isOwner = isOwner,
		cardId = cardId
	})
	add_child(card)
	allCards[cardId] = card
	card.isPlayed.connect(handleOnCardIsPlayed)	
	return card
	
	
func _on_card_drop_area_2d_area_entered(area):
	if(not area is Card):
		return
	var card: Card = area
	card.isInDroppableArea = true

func _on_card_drop_area_2d_area_exited(area):
	if(not area is Card):
		return
	var card: Card = area
	card.isInDroppableArea = false

func _on_restart_game_button_pressed():
	Gamedata.propagateActionType.rpc("RESTART","RPS")

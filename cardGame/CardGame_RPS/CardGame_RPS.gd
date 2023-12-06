extends Node2D

@onready var Card = preload("res://fab/card/Card.tscn")
#let just play rock paper sissors bruh

var allCards = {}
var cardsOwnId = []
var cardsNotOwnId = []

var cardTypes = {
	ROCK="ROCK",
	PAPER="PAPER",
	SCISSOR="SCISSOR",
} 

var playerTypes = {
	HOST="HOST",
	CLIENT = "CLIENT"
}
var playerType = null

var actionTypes = {
	CARD_PLAYED="CARD_PLAYED"
}


#rpc signals
func handlePropagatedAction(actionType, newRPSData):
	print("receives", actionType)
	if(actionType==actionTypes.CARD_PLAYED):
		handlePropagatedCardPlayed(newRPSData)
	

func handlePropagatedCardPlayed(propagatedData):
	print("card played...")
	var card = allCards[propagatedData.cardIdPlayed]
	card.restSnapPos = Vector2.ZERO


#card signals
func handleCardIsPlayed(card):
	if(Gamedata.RPSData.cardsPlayed[playerType]!= null):
		return #not allowing you to play more cards until both are cleared
	Gamedata.propagateActionType.rpc(actionTypes.CARD_PLAYED,{
		cardIdPlayed = card.cardId,
		cardOwner = card.ownerId,
	})
	print("a card got played huh", card)


func _ready():
	Gamedata.propagateActionToGamemanager.connect(handlePropagatedAction)
	startGame()


func startGame():
	#two cases, you are host, or you are client. lets jsut make it easy.
	var hostId = Gamedata.RPSData.hostCardsId
	var clientId =  Gamedata.RPSData.clientCardsId
	if(Gamedata.playerId == 1): #you are always on the bottom.....
		playerType = playerTypes.HOST
		cardsOwnId = hostId
		cardsNotOwnId = clientId
		initializeCardsOnBot()
		initializeCardsOnTop()
	else: #you are client
		playerType = playerTypes.CLIENT
		cardsNotOwnId = hostId
		cardsOwnId = clientId
		initializeCardsOnBot()
		initializeCardsOnTop()

func initializeCardsOnBot():
	createCard(cardTypes.ROCK,		Vector2(100,200),true,cardsOwnId[0])
	createCard(cardTypes.PAPER,		Vector2(300,200),true,cardsOwnId[1])
	createCard(cardTypes.SCISSOR,	Vector2(500,200),true,cardsOwnId[2])
func initializeCardsOnTop():
	createCard(cardTypes.ROCK,		Vector2(100,-200),false,cardsNotOwnId[0])
	createCard(cardTypes.PAPER,		Vector2(300,-200),false,cardsNotOwnId[1])
	createCard(cardTypes.SCISSOR,	Vector2(500,-200),false,cardsNotOwnId[2])
	
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
	card.isPlayed.connect(handleCardIsPlayed)	
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





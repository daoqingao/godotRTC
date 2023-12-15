extends Node2D
#chinese poker, aka BT
class_name ChinesePokerGameManager

@onready var BTCard = preload("res://cardGame/CardGame_ChinesePoker/BTCard.tscn")
@onready var camera = $Camera2D
@onready var playCardsButton = $PlayCardsButton
#CONST for this game
enum DirectionOrientation {
	SOUTH,WEST,NORTH,EAST
}
enum ScreenOrientation {
	BOT,LEFT,TOP,RIGHT
}
const PLAYER_COUNT = 4 #ALWAYS 4, the people in the lobby is ALWAYS 4 
const NUM_CARDS_PER_PLAYER = 13 #13 cards per play



enum CardPlayedComboType {
	SINGLE,
	DOUBLE,
	COMBO,
	INVALID_COMBO,
	FIRST_CARD_TO_PLAY_NO_CARDS_BEFORE
}
const PlayedSizeToComboType = {
	1:CardPlayedComboType.SINGLE,
	2:CardPlayedComboType.DOUBLE,
	5:CardPlayedComboType.COMBO
}

var SuitOrder = {
	'diamonds':0,
	'clubs':1,
	'hearts':2,
	'spades':3,
}
var RankOrder = {
	'3':0,
	'4':1,
	'5':2,
	'6':3,
	'7':4,
	'8':5,
	'9':6,
	'10':7,
	'J':8,
	'Q':9,
	'K':10,
	'A':11,
	'2':12,
}

const PokerCard5ComboType = {
	'straight':0, #5 cards in a row, different color
	'flush':1, #colors
	'full_house':2, #3 + 2 
	'four_of_a_kind':3, #4 + 1
	'straight_flush':4, #5 cards in a row, same color
}
@onready var PLAYED_CARDS_SNAP_POSITION = $DropArea/DropSnapPos.global_position

################################################# DATA THAT ARE RELATED TO THE GAME AND SHOULD BE THE SAME ACROSS ALL INSTANCE
var allPlayerIdList = []

var CardsOnPlayersHands = { #THESE ARE ALSO THE INDEX!!!!!!! 0,1,2,3
	DirectionOrientation.SOUTH:{},
	DirectionOrientation.WEST:{},
	DirectionOrientation.NORTH:{},
	DirectionOrientation.EAST:{},
}
var allCards = {} # <cardid : BTCard>





################################################# DATA THAT are related to the cards being played,
#cards that are were last played. we need to compare to this
var cardslastPlayedList = [] #array of card ids that werw last played
var cardsLastPlayedComboType = CardPlayedComboType.FIRST_CARD_TO_PLAY_NO_CARDS_BEFORE #something like that	

var cardsSelectedToPlayList = [] #array of card ids that are selected
var cardsSelectedToPlayComboType = CardPlayedComboType.FIRST_CARD_TO_PLAY_NO_CARDS_BEFORE #something like that



#this one is not the same across all instance ############################# DATA THAT ARE RELATED TO SELF CLIENT PLAYER
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
	Gamedata.propagateActionToPeers.connect(handlePropagatedAction)
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
	cardslastPlayedList = propagatedData.cardsIdPlayedList
	cardsLastPlayedComboType = propagatedData.cardsPlayedType

	print("players played a card, ", cardslastPlayedList, cardsLastPlayedComboType)
	lerpLastPlayedCardsToCenter()
	# var cardIdList = propagatedData
	# # var card = allCards[cardId]
	# card.restSnapPos = PLAYED_CARDS_SNAP_POSITION
	# card.z_index = cardPlayedSize + 3
	# cardPlayedSize +=1
	# print(PLAYED_CARDS_SNAP_POSITION)
	# print("another player played a card!")
	return

func handlePropagatedInit(propagatedData):
	allPlayerIdList = propagatedData.peerPlayers.keys()
	allPlayerIdList.sort() #make sure the things are consistent, because the index you are in determines the orientation
	#0 is SOUTH, 1 is WEST, 2 IS NORTH, 3 IS EAST, (EXACTLY LIKE THE ENUM)
	selfPlayerId = Gamedata.playerId
	seed(propagatedData.pregeneratedSeed)
	startGame()



#card signals

# func handleOnCardIsPlayed(card):
# 	# card.restSnapPos = PLAYED_CARDS_SNAP_POSITION
# 	# print(card,"is played")
# 	# Gamedata.propagateActionType(Gamedata.ActionType.CARD_PLAYED,card.id)
# 	return



#event handlers

# func _on_drop_area_area_entered(area):
# 	if(not area is BTCard):
# 		return
# 	var card: BTCard = area
# 	card.isInDroppableArea = true

# func _on_drop_area_area_exited(area):
# 	if(not area is BTCard):
# 		return
# 	var card: BTCard = area
# 	card.isInDroppableArea = false

var testCardPlayed = 1



####################### Event Handlers For Buttons On UI
func _on_play_cards_button_pressed():
	pass # Replace with function body.

func _on_button_pressed():
	Gamedata.propagateActionType(Gamedata.ActionType.CARD_PLAYED,{
		cardsIdPlayedList = [1],
		cardsPlayedType = CardPlayedComboType.SINGLE
	})
	# Gamedata.propagateActionType(Gamedata.ActionType.CARD_PLAYED,{
	# 	cardsIdPlayedList = [1,5,6,7,8],
	# 	cardsPlayedType = CardPlayedComboType.COMBO
	# })
	#another played played a card!
	pass # Replace with function body.


####################### Event Handlers For Cards


#function to move the cards slight up when selected and back down when deselected
func handleOnCardIsSelected(card):
	if(!card.isSelected):
		card.restSnapPos = card.restSnapPos + Vector2(0,-50)
		cardsSelectedToPlayList.push_back(card)
	else:
		card.restSnapPos = card.restSnapPos + Vector2(0,50)
		cardsSelectedToPlayList.erase(card)
	print("selected card list",cardsSelectedToPlayList)
	card.isSelected = !card.isSelected
	playCardsButton.disabled = false if checkIfCardsSelectedIsPlayable() else true
	return
	










####################### GAMEPLAY FUNCTIONS

#card is only palyable if it beats the last card
func checkIfCardsSelectedIsPlayable():
	cardsSelectedToPlayComboType = getCardsListComboType(cardsSelectedToPlayList)
	print("the combo ranking is")
	print(cardsSelectedToPlayComboRanking)
	# checkIfCardToPlayBeatsLastPlayedCard(cardsSelectedToPlayList,cardsSelectedToPlayComboType,cardslastPlayedList,cardsLastPlayedComboType)

var cardsSelectedToPlayComboRanking = -1

func getCardsListComboType(cardsList):
	var cardPlayedSize = cardsList.size()
	if(cardPlayedSize == 1):
		cardsSelectedToPlayComboRanking = getSingleComboRanking(cardsList)
		return CardPlayedComboType.SINGLE
	if(cardPlayedSize == 2):
		if(cardsList[0].rank == cardsList[1].rank):
			cardsSelectedToPlayComboRanking = getDoubleComboRanking(cardsList)
			return CardPlayedComboType.DOUBLE
	if(cardPlayedSize == 5):
		return getQuintComboRanking(cardsList)
	#invalid combo includes 0, non matching pairs, and non matching 5 card combos
	return CardPlayedComboType.INVALID_COMBO
	

func getSingleComboRanking(cardsList):
	var card = cardsList[0]
	var cardSuit = card.suit
	var cardRank = card.rank
	var rankScalability = 5 #1 rank higher means 5 times higher than climbing a suit , just making so that pairs are easier to track
	return RankOrder[cardRank]*rankScalability  + SuitOrder[cardSuit ]

func getDoubleComboRanking(cardsList):
	var card1 = cardsList[0]
	var card2 = cardsList[1]
	var doubleRanking = getSingleComboRanking([card1]) + getSingleComboRanking([card2])
	#if any of them has a spade, it gets a +1
	if(card1.suit == 'spades' or card2.suit == 'spades'):
		doubleRanking += 1
	return doubleRanking

func getQuintComboRanking(cardsList):
	var card1 = cardsList[0]
	var card2 = cardsList[1]
	var card3 = cardsList[2]
	var card4 = cardsList[3]
	var card5 = cardsList[4]

	var comboRanking = 0
	var ranksList = [card1.rank,card2.rank,card3.rank,card4.rank,card5.rank]
	var suitsList = [card1.suit,card2.suit,card3.suit,card4.suit,card5.suit]
	var ranksListRankings = [RankOrder[card1.rank],RankOrder[card2.rank],RankOrder[card3.rank],RankOrder[card4.rank],RankOrder[card5.rank]]
	
	
	#check for straight....
	ranksListRankings.sort()
	if(ranksListRankings[0] == ranksListRankings[1]-1 and ranksListRankings[1] == ranksListRankings[2]-1 and ranksListRankings[2] == ranksListRankings[3]-1 and ranksListRankings[3] == ranksListRankings[4]-1):
		#what determines the rank is the biggest single card in that straight
		#goes through all the cardslist and returns the biggest number return by getSingleComboRanking
		comboRanking = cardsList.reduce(	func(card1,card2): return card1 if getSingleComboRanking([card1]) > getSingleComboRanking([card2]) else card2)

	
	# #check for flush
	# var suitsRankingMultiplier = 13 #
	# if(suitsList[0] == suitsList[1] and suitsList[1] == suitsList[2] and suitsList[2] == suitsList[3] and suitsList[3] == suitsList[4]):
	# 	comboRanking = RankOrder[suitsList[4]] #the highest ranking card in a flush would be 3
	return comboRanking

# func checkIfCardToPlayBeatsLastPlayedCard(cardsToPlayList,cardsToPlayComboType,cardsToBeatList,cardToBeatComboType):
# 	if(cardToBeatComboType != cardsToPlayComboType):
# 		return false #if the combo type is not the same, then it is not playable
# 	##switch case for the combo type
# 	if(cardsToPlayComboType == CardPlayedComboType.SINGLE):
# 		return checkIfSingleBeatable(cardsToPlayList,cardsToBeatList)
# 	elif(cardsToPlayComboType == CardPlayedComboType.DOUBLE):
# 		return checkIfDoubleBeatable(cardsToPlayList,cardsToBeatList)

# func checkIfSingleBeatable(cardsToPlayList,cardsToBeatList):
# 	var cardToPlay = cardsToPlayList[0]
# 	var cardToBeat = cardsToBeatList[0]
# 	print(cardToPlay,cardToBeat)
# func checkIfDoubleBeatable(cardsToPlayList,cardsToBeatList):
# 	var cardToPlay1 = allCards[cardsToPlayList[0]]
# 	var cardToPlay2 = allCards[cardsToPlayList[1]]
# 	var cardToBeat1 = allCards[cardsToBeatList[0]]
# 	var cardToBeat2 = allCards[cardsToBeatList[1]]
# 	if(cardToPlay1.cardRank == cardToPlay2.cardRank):
# 		return cardToPlay1.cardRank > cardToBeat1.cardRank
# 	else:
# 		return cardToPlay1.cardRank > cardToBeat1.cardRank and cardToPlay2.cardRank > cardToBeat2.cardRank
	


func lerpLastPlayedCardsToCenter():
	if(cardsLastPlayedComboType == CardPlayedComboType.SINGLE):
		var card = allCards[cardslastPlayedList[0]]
		card.restSnapPos = PLAYED_CARDS_SNAP_POSITION
		card.z_index = 3
		return
	elif(cardsLastPlayedComboType == CardPlayedComboType.DOUBLE):
		var card1 = allCards[cardslastPlayedList[0]]
		var card2 = allCards[cardslastPlayedList[1]]
		card1.restSnapPos = PLAYED_CARDS_SNAP_POSITION
		card2.restSnapPos = PLAYED_CARDS_SNAP_POSITION + Vector2(100,0)
		card1.z_index = 3
		card2.z_index = 3
		return
	elif(cardsLastPlayedComboType == CardPlayedComboType.COMBO):
		var card1 = allCards[cardslastPlayedList[0]]
		var card2 = allCards[cardslastPlayedList[1]]
		var card3 = allCards[cardslastPlayedList[2]]
		var card4 = allCards[cardslastPlayedList[3]]
		var card5 = allCards[cardslastPlayedList[4]]
		card1.restSnapPos = PLAYED_CARDS_SNAP_POSITION
		card2.restSnapPos = PLAYED_CARDS_SNAP_POSITION + Vector2(100,0)
		card3.restSnapPos = PLAYED_CARDS_SNAP_POSITION + Vector2(200,0)
		card4.restSnapPos = PLAYED_CARDS_SNAP_POSITION + Vector2(300,0)
		card5.restSnapPos = PLAYED_CARDS_SNAP_POSITION + Vector2(400,0)
		card1.z_index = 3
		card2.z_index = 3
		card3.z_index = 3
		card4.z_index = 3
		card5.z_index = 3
		return
	else:
		print("error, card combo type not found")
		return
























####################### GAME INITIALIZATION FUNCTIONS
func createBTCard():
	var card = BTCard.instantiate()
	add_child(card)
	# card.isPlayed.connect(handleOnCardIsPlayed)
	card.isSelectedSignal.connect(handleOnCardIsSelected)
	return card
func startGame():
	###init the card game
	#shufflign deck
	var suits = ['diamonds', 'clubs', 'hearts', 'spades']
	var ranks = [ '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A' ,'2']
	# suits.shuffle()
	# ranks.shuffle()
	var temporaryCardStack = [] 
	var countsId = 1
	for rank in ranks:
		for suit in suits:
			var card = createBTCard()
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
	#now this means, THE INDEX OF THE ARR IS THE CURRENT SCREEN ORIENTATION
	# THE ELEMETNS OF THE ARR IS THE DIRECTIONAL ORIENTATION
	# NOW THEY ARE MAPPED TO EACH OTHER!
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
		card.initBTCardOwner(data.isOwnedByCurrentPlayer,data.playerId,data.currentDirectionOrientation,data.currentScreenOrientation)
		CardsOnPlayersHands[data.currentDirectionOrientation][card.id] = card
		if(!data.isOwnedByCurrentPlayer):
			card.restSnapPos = Vector2(initX+distance*counter+offSetX,randi() % 600-300) * Vector2.ZERO 
		else: #you do own the card so lets put it on the bottom!!!
			card.restSnapPos = Vector2(initX+distance*counter+offSetX,initY)
		counter+=1  


	


####################### UTILITY FUNCTIONS
func getDirectionOriEnumStr(value):
	return getEnumStr(DirectionOrientation,value)
func getScreenOriEnumStr(value):
	return getEnumStr(ScreenOrientation,value)
func getEnumStr(enums,value):
	return enums.keys()[value]

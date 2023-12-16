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
	QUINT,
	INVALID_COMBO,
	FIRST_CARD_TO_PLAY_NO_CARDS_BEFORE
}
const PlayedSizeToComboType = {
	1:CardPlayedComboType.SINGLE,
	2:CardPlayedComboType.DOUBLE,
	5:CardPlayedComboType.QUINT
}

const SPADES = "spades"
const CLUBS = "clubs"
const HEARTS = "hearts"
const DIAMONDS = "diamonds"

var SuitOrdering = {
	'diamonds':1,
	'clubs':2,
	'hearts':3,
	'spades':4,
}


var RankOrdering = {
	'3':1,
	'4':2,
	'5':3,
	'6':4,
	'7':5,
	'8':6,
	'9':7,
	'10':8,
	'J':9,
	'Q':10,
	'K':11,
	'A':12,
	'2':13,
}


enum QuintComboType {
	STRAIGHT, #5 cards in a row, different color
	FLUSH, #colors
	FULL_HOUSE, #3 + 2 
	FOUR_OF_A_KIND, #4 + 1
	STRAIGHT_FLUSH, #5 cards in a row, same color
	NO_QUINT_COMBO,
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
var currentTurnDirectionalOrientation = DirectionOrientation.EAST #the player that is currently playing #





################################################# DATA THAT are related to the cards being played,
#cards that are were last played. we need to compare to this
var cardsLastPlayedList = [] #array of card ids that werw last played
var cardsLastPlayedComboType = CardPlayedComboType.FIRST_CARD_TO_PLAY_NO_CARDS_BEFORE #something like that	
var cardsLastPlayedQuintComboType = QuintComboType.NO_QUINT_COMBO #something like that
var cardsLastPlayedComboOrdering = 0 #the ranking of the combo, used to compare with the next combo

var cardsLastPlayedPlayerId = -1
var cardsLastPlayedDirectionalOrientation = -1


var cardsSelectedToPlayList = [] #array of card that are selected
var cardsSelectedToPlayComboType = CardPlayedComboType.INVALID_COMBO #something like that
var cardsSelectedToPlayQuintComboType = QuintComboType.NO_QUINT_COMBO #something like that
var cardsSelectedToPlayComboOrdering = -1



#this one is not the same across all instance ############################# DATA THAT ARE RELATED TO SELF CLIENT PLAYER
var selfPlayerId = -1
var selfPlayerDirectionalOrientation = -1

var selfDirectionOriToScreenOri = {
	# DirectionOrientation.SOUTH:bot,
	# DirectionOrientation.WEST:left,
	# DirectionOrientation.NORTH:top,
	# DirectionOrientation.EAST:right, #each being different depending on the self player 
}

# var selfCardsOnHand = {}
# var selfCardsPosArrX = []
# var ownCards = CardsOnPlayersHands[selfPlayerDirectionalOrientation]

func _ready():
	# print("reading, sohuld be called twice") #gets called twice thats good.....
	Gamedata.propagateActionToPeers.connect(handlePropagatedAction)
	Gamedata.propagateActionType.rpc_id(1,Gamedata.ConnectionActionType.PLAYER_SIGNAL_CONNECTED_AND_READIED,{})
	#stubbed data to init with 4 players
	handlePropagatedInit({
			peerPlayers= {
				1:1, 
				20:22,
				3333:3333,
				4444:4444
			},
			pregeneratedSeed= randi()
	})	
	# Gamedata.playerId = 20 this is done in the gamedata, also need to remove that stub


#
enum BTActionType {
	TURN_PLAYED,
	TURN_PASSED
}

#rpc signals
func handlePropagatedAction(connectionActionType, propagatedData, propagatedGameActionType = -1):
	if(connectionActionType==Gamedata.ConnectionActionType.INIT):
		handlePropagatedInit(propagatedData)
	if(connectionActionType==Gamedata.ConnectionActionType.PROPAGATE_GAME_ACTION):
		print("handling a propagated game action")
		if(propagatedGameActionType==BTActionType.TURN_PLAYED):
			handlePropagatedTurnPlayed(propagatedData)
		if(propagatedGameActionType==BTActionType.TURN_PASSED):
			handlePropagatedTurnPassed(propagatedData)


func handlePropagatedTurnPlayed(propagatedData):

	var cardsLastToPlayIdList = propagatedData.propagatedCardsSelectedToPlayIdList
	cardsLastPlayedComboType = propagatedData.propagatedCardsSelectedToPlayComboType
	cardsLastPlayedQuintComboType = propagatedData.propagatedCardsSelectedToPlayQuintComboType
	cardsLastPlayedComboOrdering = propagatedData.propagatedCardsSelectedToPlayComboOrdering
	cardsLastPlayedList = cardsLastToPlayIdList.map(func(cardId): return allCards[cardId])
	cardsLastPlayedPlayerId = propagatedData.propagatedCardsPlayedByPlayerId
	cardsLastPlayedDirectionalOrientation = propagatedData.propagatedCardsPlayedByDirectionalOrientation


	currentTurnDirectionalOrientation = cycleToNextPlayerTurn(cardsLastPlayedDirectionalOrientation) #this is the next player turn

	lerpCardsToCenter(cardsLastPlayedList,cardsLastPlayedComboType)


	_log(getDirectionOriEnumStr(cardsLastPlayedDirectionalOrientation) + " played a " + getEnumStr(CardPlayedComboType,cardsLastPlayedComboType) + " ordering" + str(cardsLastPlayedComboOrdering))
	return

func handlePropagatedTurnPassed(propagatedData):
	var playerDirectionPassed = propagatedData.propagatedCardsPlayedByDirectionalOrientation
	_log(getDirectionOriEnumStr(playerDirectionPassed)+ " passed")
	currentTurnDirectionalOrientation = cycleToNextPlayerTurn(propagatedData.propagatedCardsPlayedByDirectionalOrientation) #this is the next player turn
	return

func handlePropagatedInit(propagatedData):
	allPlayerIdList = propagatedData.peerPlayers.keys()
	allPlayerIdList.sort() #make sure the things are consistent, because the index you are in determines the orientation
	#0 is SOUTH, 1 is WEST, 2 IS NORTH, 3 IS EAST, (EXACTLY LIKE THE ENUM)
	selfPlayerId = Gamedata.playerId
	seed(propagatedData.pregeneratedSeed)
	startGame()

####################### Event Handlers For Buttons On UI
func _on_play_cards_button_pressed():


	if(!currentTurnDirectionalOrientation == selfPlayerDirectionalOrientation):
		print("not your turn")
		return
	Gamedata.propagateActionType(Gamedata.ConnectionActionType.PROPAGATE_GAME_ACTION,{
		propagatedCardsPlayedByPlayerId = Gamedata.playerId,
		propagatedCardsPlayedByDirectionalOrientation = selfPlayerDirectionalOrientation,
		propagatedCardsSelectedToPlayIdList = cardsSelectedToPlayList.map(func(card): return card.id),
		propagatedCardsSelectedToPlayComboType = cardsSelectedToPlayComboType,
		propagatedCardsSelectedToPlayQuintComboType = cardsSelectedToPlayQuintComboType,
		propagatedCardsSelectedToPlayComboOrdering = cardsSelectedToPlayComboOrdering
	}, BTActionType.TURN_PLAYED)
	lerpCardsToCenter(cardsSelectedToPlayList,cardsSelectedToPlayComboType)
 
	pass # Replace with function body.

func _on_pass_turn_button_pressed():
	if(!currentTurnDirectionalOrientation == selfPlayerDirectionalOrientation):
		print("not your turn")
		return
	Gamedata.propagateActionType(Gamedata.ConnectionActionType.PROPAGATE_GAME_ACTION,{
		propagatedCardsPlayedByPlayerId = Gamedata.playerId,
		propagatedCardsPlayedByDirectionalOrientation = selfPlayerDirectionalOrientation,
	}, BTActionType.TURN_PASSED)
	pass # Replace with function body.



func _on_button_pressed():
	#a bot plays a card randomly
	makeComputerPlayACard()


func makeComputerPlayACard():
	#make a random card play
	print("making a computer play a card")
	print("for the player of directional orientation",getEnumStr(DirectionOrientation,currentTurnDirectionalOrientation))
	var computerCardsOnHand = CardsOnPlayersHands[currentTurnDirectionalOrientation]
	var computerCardsSelectedToPlayList = []
	var computerCardsSelectedToPlayComboType = CardPlayedComboType.INVALID_COMBO
	var computerCardsSelectedToPlayQuintComboType = QuintComboType.NO_QUINT_COMBO
	var computerCardsSelectedToPlayComboOrdering = -1
	var foundAPlayableCard = false

	if cardsLastPlayedComboType == CardPlayedComboType.FIRST_CARD_TO_PLAY_NO_CARDS_BEFORE or cardsLastPlayedComboType == CardPlayedComboType.SINGLE:
		#play a single card that is allowed to be played. else pass
		#check for every single card.
		for card in computerCardsOnHand.values():
			var cardsSelectedToPlayList = [card]
			var cardsSelectedComboAndOrderingData = getCardsListComboTypeAndOrdering(cardsSelectedToPlayList)
			foundAPlayableCard = cardsSelectedComboAndOrderingData.comboCanBePlayedFlag
			if(foundAPlayableCard):
				computerCardsSelectedToPlayList.push_back(card)
				computerCardsSelectedToPlayComboType = cardsSelectedComboAndOrderingData.comboType
				computerCardsSelectedToPlayComboOrdering = cardsSelectedComboAndOrderingData.comboOrdering
				computerCardsSelectedToPlayQuintComboType = cardsSelectedComboAndOrderingData.quintComboType
				break

	if(foundAPlayableCard):
		Gamedata.propagateActionType(Gamedata.ConnectionActionType.PROPAGATE_GAME_ACTION,{
			propagatedCardsPlayedByPlayerId = -1000,
			propagatedCardsPlayedByDirectionalOrientation = currentTurnDirectionalOrientation,
			propagatedCardsSelectedToPlayIdList = computerCardsSelectedToPlayList.map(func(card): return card.id),
			propagatedCardsSelectedToPlayComboType = computerCardsSelectedToPlayComboType,
			propagatedCardsSelectedToPlayQuintComboType = computerCardsSelectedToPlayQuintComboType,
			propagatedCardsSelectedToPlayComboOrdering = computerCardsSelectedToPlayComboOrdering
		}, BTActionType.TURN_PLAYED)
	else:
		Gamedata.propagateActionType(Gamedata.ConnectionActionType.PROPAGATE_GAME_ACTION,{
			propagatedCardsPlayedByPlayerId = -1000,
			propagatedCardsPlayedByDirectionalOrientation = currentTurnDirectionalOrientation,
		}, BTActionType.TURN_PASSED)

####################### Event Handlers For Cards


#function to move the cards slight up when selected and back down when deselected

#move from SOTUH to WEST to NORTH to EAST to SOUTH
func cycleToNextPlayerTurn(directionalOrientation):
	print("current turn is",getDirectionOriEnumStr(directionalOrientation))

	var nextPlayerTurn = (directionalOrientation+1) % PLAYER_COUNT
	print("next turn is",getDirectionOriEnumStr(nextPlayerTurn))
	return nextPlayerTurn

func handleOnCardIsSelected(card):
	if(!card.isSelected):
		card.restSnapPos = card.restSnapPos + Vector2(0,-50)
		cardsSelectedToPlayList.push_back(card)
	else:
		card.restSnapPos = card.restSnapPos + Vector2(0,50)
		cardsSelectedToPlayList.erase(card)
	print("selected card list",cardsSelectedToPlayList)
	card.isSelected = !card.isSelected


	var cardsComboAndOrderingData = getCardsListComboTypeAndOrdering(cardsSelectedToPlayList)
	var comboCanBePlayedFlag = cardsComboAndOrderingData.comboCanBePlayedFlag
	# playCardsButton.disabled = false if comboCanBePlayedFlag else true
	print(comboCanBePlayedFlag)
	if(comboCanBePlayedFlag):
		playCardsButton.disabled = false
		#set global variable to the cards selected to play
		cardsSelectedToPlayComboType = cardsComboAndOrderingData.comboType
		cardsSelectedToPlayComboOrdering = cardsComboAndOrderingData.comboOrdering
		cardsSelectedToPlayQuintComboType = cardsComboAndOrderingData.quintComboType
	else:
		playCardsButton.disabled = true


####################### GAMEPLAY FUNCTIONS


#returns 3 things, the combo type, the combo ordering, and the quint combo type
#modular function to get the combo type and ordering of the cards
func getCardsListComboTypeAndOrdering(cardsList):
	var localCardsSelectedToPlayComboOrdering = -1
	var localCardsSelectedToPlayComboType = CardPlayedComboType.INVALID_COMBO
	var localCardsSelectedToPlayQuintComboType = QuintComboType.NO_QUINT_COMBO #something like that
	var localCardsSelectedCanBePlayedFlagComparedToLastPlayedCard = false

	var cardPlayedSize = cardsList.size()
	if(cardPlayedSize == 1):
		localCardsSelectedToPlayComboOrdering = getSingleComboOrdering(cardsList)
		localCardsSelectedToPlayComboType = CardPlayedComboType.SINGLE
	elif(cardPlayedSize == 2):
		if(cardsList[0].rank == cardsList[1].rank):
			localCardsSelectedToPlayComboOrdering = getDoubleComboOrdering(cardsList)
			localCardsSelectedToPlayComboType = CardPlayedComboType.DOUBLE
	elif(cardPlayedSize == 5):
		var quintComboData = getQuintComboOrdering(cardsList)
		localCardsSelectedToPlayComboOrdering = quintComboData.comboOrdering
		localCardsSelectedToPlayQuintComboType = quintComboData.quintComboType
		if(localCardsSelectedToPlayQuintComboType == QuintComboType.NO_QUINT_COMBO):
			localCardsSelectedToPlayComboType = CardPlayedComboType.INVALID_COMBO
		else: 
			localCardsSelectedToPlayComboType = CardPlayedComboType.QUINT
	else:
		localCardsSelectedToPlayComboType = CardPlayedComboType.INVALID_COMBO
	
	# check if the cards can be played compared to the last played card

	#they need to be the same combo type, and the ranking needs to be greater
	if(localCardsSelectedToPlayComboType != CardPlayedComboType.INVALID_COMBO):
		if(cardsLastPlayedComboType == CardPlayedComboType.FIRST_CARD_TO_PLAY_NO_CARDS_BEFORE):
			localCardsSelectedCanBePlayedFlagComparedToLastPlayedCard = true
		elif(localCardsSelectedToPlayComboType == cardsLastPlayedComboType):
			if(localCardsSelectedToPlayComboOrdering > cardsLastPlayedComboOrdering):
				localCardsSelectedCanBePlayedFlagComparedToLastPlayedCard = true
		# 	else:
		# 		localCardsSelectedCanBePlayedFlagComparedToLastPlayedCard = false
		# else:
		# 	localCardsSelectedCanBePlayedFlagComparedToLastPlayedCard = false

	return {
		"comboType":localCardsSelectedToPlayComboType,
		"comboOrdering":localCardsSelectedToPlayComboOrdering,
		"quintComboType":localCardsSelectedToPlayQuintComboType,
		"comboCanBePlayedFlag":localCardsSelectedCanBePlayedFlagComparedToLastPlayedCard
	}

func getSingleComboOrdering(cardsList):
	var card = cardsList[0]
	var cardSuit = card.suit
	var cardRank = card.rank
	var rankScalability = 5 #1 rank higher means 5 times higher than climbing a suit , just making so that pairs are easier to track
	return RankOrdering[cardRank]*rankScalability  + SuitOrdering[cardSuit ]
	#max is 13*5 + 4 = 69

func getDoubleComboOrdering(cardsList):
	var card1 = cardsList[0]
	var card2 = cardsList[1]
	var doubleRanking = getSingleComboOrdering([card1]) + getSingleComboOrdering([card2])
	#if any of them has a spade, it gets a +1
	if(card1.suit == 'spades' or card2.suit == 'spades'):
		doubleRanking += 1
	#max is 69 + 1 = 70
	return doubleRanking

func getQuintComboOrdering(cardsList):

	var card1 = cardsList[0]
	var card2 = cardsList[1]
	var card3 = cardsList[2]
	var card4 = cardsList[3]
	var card5 = cardsList[4]

	var localCardsSelectedToPlayQuintComboType = QuintComboType.NO_QUINT_COMBO #something like that
	var localComboOrdering = -1
	# var ranksList = [card1.rank,card2.rank,card3.rank,card4.rank,card5.rank]
	var suitsList = [card1.suit,card2.suit,card3.suit,card4.suit,card5.suit]
	var ranksListRankings = [RankOrdering[card1.rank],RankOrdering[card2.rank],RankOrdering[card3.rank],RankOrdering[card4.rank],RankOrdering[card5.rank]]
	

	var straightsMaxRanking = 69
	var flushMaxRanking = 69 + 4*13
	var fullHouseMaxRanking = 139 + 13
	var fourOfAKindMaxRanking = 152 + 13

	#check for straight....
	ranksListRankings.sort()

	var isStraightFlag = false
	if(ranksListRankings[0] == ranksListRankings[1]-1 and ranksListRankings[1] == ranksListRankings[2]-1 and ranksListRankings[2] == ranksListRankings[3]-1 and ranksListRankings[3] == ranksListRankings[4]-1):
		#what determines the rank is the biggest single card in that straight
		var singleCard = cardsList.reduce(	func(cardA,cardB): return cardA if getSingleComboOrdering([cardA]) > getSingleComboOrdering([cardB]) else cardB)
		localComboOrdering += getSingleComboOrdering([singleCard])
		#max is 69
		localCardsSelectedToPlayQuintComboType = QuintComboType.STRAIGHT
		isStraightFlag = true
	#check for flush
	if(suitsList[0] == suitsList[1] and suitsList[1] == suitsList[2] and suitsList[2] == suitsList[3] and suitsList[3] == suitsList[4]):
		localComboOrdering+= straightsMaxRanking #always bigger than straight
		#biggest card of the flush determines the ranking
		var singleCard = cardsList.reduce(	func(cardA,cardB): return cardA if getSingleComboOrdering([cardA]) > getSingleComboOrdering([cardB]) else cardB)
		localComboOrdering += SuitOrdering[singleCard.suit]*13 + RankOrdering[singleCard.rank]
		localCardsSelectedToPlayQuintComboType = QuintComboType.FLUSH
		#min is 69 + 1*13 + 1 = 83
		#max is 69 + 4*13 + 12 = 139
		if(isStraightFlag):
			localCardsSelectedToPlayQuintComboType = QuintComboType.STRAIGHT_FLUSH
			localComboOrdering+= fourOfAKindMaxRanking #will get the added bonus of always being bigger than 4 of a kind
			#special condition for the royal flush.
			return {
				"comboOrdering":localComboOrdering,
				"quintComboType":localCardsSelectedToPlayQuintComboType
			}
			#min is 83 + 165 = 248
			#max is 139 + 165 = 304
			#max is 165 + 139 

	#check for full house
	#contains a pair and a triple
	if( (ranksListRankings[0] == ranksListRankings[1] and ranksListRankings[2] == ranksListRankings[3] and ranksListRankings[3] == ranksListRankings[4]) #pair is at the front
		or (ranksListRankings[0] == ranksListRankings[1] and ranksListRankings[1] == ranksListRankings[2] and ranksListRankings[3] == ranksListRankings[4]) #pair is at the back
		):
		localComboOrdering+= flushMaxRanking #always bigger than flush
		#check which rank is the triple
		var tripleRank =  ranksListRankings[2] #IT ALWAYS NEEDS TO BE IN THE MIDDLE... its either 22333 or 33322 lol
		localComboOrdering+= tripleRank
		#min is 139 + 1 = 140
		#max is 139 + 13 = 152
		localCardsSelectedToPlayQuintComboType = QuintComboType.FULL_HOUSE

	#check for four of a kind
	#contains a single and a quad
	if( (ranksListRankings[0] == ranksListRankings[1] and ranksListRankings[1] == ranksListRankings[2] and ranksListRankings[2] == ranksListRankings[3]) #quad is at the front
		or (ranksListRankings[1] == ranksListRankings[2] and ranksListRankings[2] == ranksListRankings[3] and ranksListRankings[3] == ranksListRankings[4]) #quad is at the back
		):
		localComboOrdering+= fullHouseMaxRanking #always bigger than full house
		var quadRank =  ranksListRankings[2] #quad would be in the middle if its 22223 or 32222
		localComboOrdering+= quadRank
		#min is 152 + 1 = 153
		#max is 152 + 13 = 165
		localCardsSelectedToPlayQuintComboType = QuintComboType.FOUR_OF_A_KIND

	#check for royal flush
	#contains a straight and a flush

	return {
		"comboOrdering":localComboOrdering,
		"quintComboType":localCardsSelectedToPlayQuintComboType
	}

var numCardsZIndexCounter = 3
func lerpCardsToCenter(cardsList,cardComboType):
	if(cardComboType == CardPlayedComboType.SINGLE):
		var card = cardsList[0]
		card.restSnapPos = PLAYED_CARDS_SNAP_POSITION
		card.z_index = numCardsZIndexCounter
		numCardsZIndexCounter+=1
		return
	elif(cardComboType == CardPlayedComboType.DOUBLE):
		var card1 = cardsList[0]
		var card2 = cardsList[1]
		card1.restSnapPos = PLAYED_CARDS_SNAP_POSITION
		card2.restSnapPos = PLAYED_CARDS_SNAP_POSITION + Vector2(100,0)
		card1.z_index = numCardsZIndexCounter
		card2.z_index = numCardsZIndexCounter
		numCardsZIndexCounter += 1
		return
	elif(cardComboType == CardPlayedComboType.QUINT):
		var card1 = cardsList[0]
		var card2 = cardsList[1]
		var card3 = cardsList[2]
		var card4 = cardsList[3]
		var card5 = cardsList[4]
		card1.restSnapPos = PLAYED_CARDS_SNAP_POSITION
		card2.restSnapPos = PLAYED_CARDS_SNAP_POSITION + Vector2(100,0)
		card3.restSnapPos = PLAYED_CARDS_SNAP_POSITION + Vector2(200,0)
		card4.restSnapPos = PLAYED_CARDS_SNAP_POSITION + Vector2(300,0)
		card5.restSnapPos = PLAYED_CARDS_SNAP_POSITION + Vector2(400,0)
		card1.z_index = numCardsZIndexCounter
		card2.z_index = numCardsZIndexCounter
		card3.z_index = numCardsZIndexCounter
		card4.z_index = numCardsZIndexCounter
		card5.z_index = numCardsZIndexCounter
		numCardsZIndexCounter +=1
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
	for suit in suits:
		for rank in ranks:
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
			selfPlayerDirectionalOrientation = orientation #which one is you...

	var directionOrientationArr = [
		DirectionOrientation.SOUTH,
		DirectionOrientation.WEST,
		DirectionOrientation.NORTH,
		DirectionOrientation.EAST,
	] #making sure that the OUR player in the FRONT will be FIRST AND BOTTOM
	var firstHalf = directionOrientationArr.slice(0, selfPlayerDirectionalOrientation)
	var secondHalf = directionOrientationArr.slice(selfPlayerDirectionalOrientation, directionOrientationArr.size())
	directionOrientationArr =  secondHalf + firstHalf
	#now this means, THE INDEX OF THE ARR IS THE CURRENT SCREEN ORIENTATION
	# THE ELEMETNS OF THE ARR IS THE DIRECTIONAL ORIENTATION
	# NOW THEY ARE MAPPED TO EACH OTHER!
	for currentScreenOrientation in range(PLAYER_COUNT): #bot left top right, in that order, the game will be played like that too.
		var currentDirectionOrientation = directionOrientationArr[currentScreenOrientation] #first one will be selfPlayerDirectionalOrientation #could be west and you are bot
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


func _log(msg):
	print(msg)
	$DebugLog.text += str(msg) + "\n"

func _process(delta):
	$PlayerInfo.text = "
	You are player: " + str(selfPlayerId) + "
	Your directional orientation is: " + getDirectionOriEnumStr(selfPlayerDirectionalOrientation) + "
	Your # of card on hand is: " + str(CardsOnPlayersHands[selfPlayerDirectionalOrientation].size()) + "
	You have selected to Play: " + str(cardsSelectedToPlayList.size()) + " cards
	Your combo is: " + getEnumStr(CardPlayedComboType,cardsSelectedToPlayComboType) + "
	Your quint combo is: " + getEnumStr(QuintComboType,cardsSelectedToPlayQuintComboType) + "
	Your combo ordering is: " + str(cardsSelectedToPlayComboOrdering) + "
	Current turn is: " + getDirectionOriEnumStr(currentTurnDirectionalOrientation) + "
	Last Player Played Directional Orientation is: " + getDirectionOriEnumStr(cardsLastPlayedDirectionalOrientation) + "
	"

	$OtherPlayerCardsPlayedInfo.text = "
	Last played combo is: " + getEnumStr(CardPlayedComboType,cardsLastPlayedComboType) + "
	Last played quint combo is: " + getEnumStr(QuintComboType,cardsLastPlayedQuintComboType) + "
	Last played combo ordering is: " + str(cardsLastPlayedComboOrdering) + "
	Last played by player id: " + str(cardsLastPlayedPlayerId) + "
	Last played by directional orientation: " + getDirectionOriEnumStr(cardsLastPlayedDirectionalOrientation) + "
	"



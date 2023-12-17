extends Node2D
#chinese poker, aka BT
class_name ChinesePokerGameManager

@onready var BTCard = preload("res://cardGame/CardGame_ChinesePoker/BTCard.tscn")
@onready var camera = $Camera2D
@onready var playerInfoLabel = $TestRelated/PlayerInfo

@onready var restartButton = $RestartGameButton
@onready var autoPlayToggle = $GameButtonContainer/AutoPlayToggle
@onready var passTurnButton = $GameButtonContainer/PassTurnButton
@onready var playCardsButton = $GameButtonContainer/PlayCardsButton

@onready var leftAvatar = $PlayerAvatarsCollection/BtPlayerAvatarLeft
@onready var topAvatar = $PlayerAvatarsCollection/BtPlayerAvatarTop
@onready var rightAvatar = $PlayerAvatarsCollection/BtPlayerAvatarRight
@onready var botAvatar = $PlayerAvatarsCollection/BtPlayerAvatarBot


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
	OPEN_TURN,
	FIRST_TO_PLAY_MUST_PLAY_THREE_OF_DIAMONDS
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

var winnersListDirectionalOrientation = [] #the player that is currently playing 




################################################# DATA THAT are related to the cards being played,
#cards that are were last played. we need to compare to this
var cardsLastPlayedList = [] #array of card ids that werw last played
var cardsLastPlayedComboType = CardPlayedComboType.FIRST_TO_PLAY_MUST_PLAY_THREE_OF_DIAMONDS #something like that	
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

@onready var screenOriToPlayerAvatar = {
	ScreenOrientation.BOT:botAvatar,
	ScreenOrientation.LEFT:leftAvatar,
	ScreenOrientation.TOP:topAvatar,
	ScreenOrientation.RIGHT:rightAvatar,
}


var lobbyContainsRobot = false
var robotPositions = []

var selfAutoRobotPlay = false

var gameIsFinished = false
var currentGameRNGSeed = -1
func _ready():
	# print("reading, sohuld be called twice") #gets called twice thats good.....
	Gamedata.propagateActionToPeers.connect(handlePropagatedAction)
	Gamedata.propagateActionType.rpc_id(Gamedata.HOST_ID,Gamedata.ConnectionActionType.PLAYER_SIGNAL_CONNECTED_AND_READIED,{})
	restartButton.disabled = true
	#stubbed data to init with 4 players

	#TODO: !!!!!!!!!! REMOVE THIS WHEN MAKING MULTIPLAYER!!!!!!!!!!!!!!!!!!!!!!!
	# initAsSinglePlayer()


	# Gamedata.playerId = 20 this is done in the gamedata, also need to remove that stub

func initAsSinglePlayer():
	handlePropagatedInit({
			peerPlayers= {
				1:1, 
				-20:22,
				-3333:3333,
				-4444:4444
			},
			pregeneratedSeed= randi()
	})	

#
enum BTActionType {
	TURN_PLAYED,
	TURN_PASSED
}

#rpc signals
func handlePropagatedAction(connectionActionType, propagatedData, propagatedGameActionType = -1):
	checkIfIsAnOpenTurn()
	if(connectionActionType==Gamedata.ConnectionActionType.INIT):
		handlePropagatedInit(propagatedData)
	if(connectionActionType==Gamedata.ConnectionActionType.PROPAGATE_GAME_ACTION):
		if(propagatedGameActionType==BTActionType.TURN_PLAYED):
			handlePropagatedTurnPlayed(propagatedData)
		if(propagatedGameActionType==BTActionType.TURN_PASSED):
			handlePropagatedTurnPassed(propagatedData)


func handlePropagatedTurnPlayed(propagatedData):
	# checkIfIsAnOpenTurn()
	var cardsLastToPlayIdList = propagatedData.propagatedCardsSelectedToPlayIdList
	cardsLastPlayedComboType = propagatedData.propagatedCardsSelectedToPlayComboType
	cardsLastPlayedQuintComboType = propagatedData.propagatedCardsSelectedToPlayQuintComboType
	cardsLastPlayedComboOrdering = propagatedData.propagatedCardsSelectedToPlayComboOrdering
	cardsLastPlayedList = cardsLastToPlayIdList.map(func(cardId): return allCards[cardId])
	cardsLastPlayedPlayerId = propagatedData.propagatedCardsPlayedByPlayerId
	cardsLastPlayedDirectionalOrientation = propagatedData.propagatedCardsPlayedByDirectionalOrientation

	lerpCardsToCenter(cardsLastPlayedList,cardsLastPlayedComboType)
	_log(getDirectionOriEnumStr(cardsLastPlayedDirectionalOrientation) + " played " + getEnumStr(CardPlayedComboType,cardsLastPlayedComboType) + " " + str(cardsLastPlayedComboOrdering) + " " 
	+ getEnumStr(QuintComboType,cardsLastPlayedQuintComboType) + ": " + str(cardsLastPlayedList.map(func(card): return card.getShortRankAndSuitString())) + ""
	)
	
	#if you played a card. those ares dont belong to you anymore

	var yourCardsOnHandData = CardsOnPlayersHands[cardsLastPlayedDirectionalOrientation]
	#remove all the cards that were played in cardslastPlayedIdList
	# print("your cards on hand before",yourCardsOnHandData)
	for cardId in cardsLastToPlayIdList:
		#is you are the owner of the cards, make the flag false
		if(yourCardsOnHandData.get(cardId).isOwnedByCurrentPlayer):
			yourCardsOnHandData.get(cardId).isOwnedByCurrentPlayer = false
		yourCardsOnHandData.erase(cardId)
	#check if the player won!

	#check if the player has no more cards left
	if(yourCardsOnHandData.size() == 0):
		winnersListDirectionalOrientation.push_back(cardsLastPlayedDirectionalOrientation)
		_log(getDirectionOriEnumStr(cardsLastPlayedDirectionalOrientation) + " has won the game!")
	if(winnersListDirectionalOrientation.size() == 4):
		#GAME OVER!
		gameIsFinished = true;
		_log("GAME OVER!")
		return

	currentTurnDirectionalOrientation = cycleToNextPlayerTurn(cardsLastPlayedDirectionalOrientation) #this is the next player turn
	# clear the previous board 
	for card in propagatedData.propagatedLASTLASTCardsPlayedIdList.map(func(cardId): return allCards[cardId]):
		# card.restSnapPos = PLAYED_CARDS_SNAP_POSITION
		card.setCardRestSnapPos(PLAYED_CARDS_SNAP_POSITION)
		handleCardSFX(CardAction.DISCARDED)



	#check for the robot to play a card if required... ;(
	checkIfHostShouldAllowRobotToPlay()
	enablePassButtonOnYourTurn()
func handlePropagatedTurnPassed(propagatedData):

	_log(getDirectionOriEnumStr(propagatedData.propagatedCardsPlayedByDirectionalOrientation)+ " passed")
	currentTurnDirectionalOrientation = cycleToNextPlayerTurn(propagatedData.propagatedCardsPlayedByDirectionalOrientation) #this is the next player turn
	checkIfHostShouldAllowRobotToPlay()
	enablePassButtonOnYourTurn()

func checkIfHostShouldAllowRobotToPlay():
	if(selfPlayerId == Gamedata.HOST_ID):
		if(lobbyContainsRobot):
			if(robotPositions.find(currentTurnDirectionalOrientation) != -1):
				await get_tree().create_timer(0.2).timeout
				_log("robot is thinking to playing a card")
				makeComputerPlayACard()
				return
			else:
				print("@@@@@@@@@@@@@@@@ robot is not playing a card, the turn is now on a PLAYER!")
	if selfAutoRobotPlay and currentTurnDirectionalOrientation == selfPlayerDirectionalOrientation:
		await get_tree().create_timer(0.2).timeout
		_log("player has elected to be auto played by the robot... to playing a card")
		makeComputerPlayACard()
func handlePropagatedInit(propagatedData):
	print("all players are here..")
	print(allPlayerIdList)
	allPlayerIdList = propagatedData.peerPlayers.keys()
	allPlayerIdList.sort() #make sure the things are consistent, because the index you are in determines the orientation
	#if any of the playerid are negative, that means it is a robot

	#find doesnt take a function, so we need another way to check if the array contains a negative number
	if(	allPlayerIdList.filter(func(playerId): return playerId < 0).size() > 0):
		print('has a lobby with a robot')
		lobbyContainsRobot = true


	#0 is SOUTH, 1 is WEST, 2 IS NORTH, 3 IS EAST, (EXACTLY LIKE THE ENUM)
	selfPlayerId = Gamedata.playerId
	currentGameRNGSeed = propagatedData.pregeneratedSeed
	seed(propagatedData.pregeneratedSeed)
	startGame()
	doneInitialized = true
	checkIfHostShouldAllowRobotToPlay()
	#terribly bootleg scuffed way to init the text.
	currentTurnDirectionalOrientation = cycleToNextPlayerTurn(currentTurnDirectionalOrientation) #this is the next player turn
	currentTurnDirectionalOrientation = cycleToNextPlayerTurn(currentTurnDirectionalOrientation) #this is the next player turn
	currentTurnDirectionalOrientation = cycleToNextPlayerTurn(currentTurnDirectionalOrientation) #this is the next player turn
	currentTurnDirectionalOrientation = cycleToNextPlayerTurn(currentTurnDirectionalOrientation) #this is the next player turn
	handleSortSelfCardsOnHand()
	restartButton.disabled = false
####################### Event Handlers For Buttons On UI

func enablePassButtonOnYourTurn():
	if(currentTurnDirectionalOrientation == selfPlayerDirectionalOrientation):
		playCardsButton.disabled = true
		passTurnButton.disabled = false
	else:
		playCardsButton.disabled = true
		passTurnButton.disabled = true

func _on_play_cards_button_pressed():
	if(gameIsFinished):
		print("game is finished")
		return
	if(!currentTurnDirectionalOrientation == selfPlayerDirectionalOrientation):
		print("not your turn")
		return
	Gamedata.propagateActionType.rpc(Gamedata.ConnectionActionType.PROPAGATE_GAME_ACTION,{
		propagatedCardsPlayedByPlayerId = Gamedata.playerId,
		propagatedCardsPlayedByDirectionalOrientation = selfPlayerDirectionalOrientation,
		propagatedCardsSelectedToPlayIdList = cardsSelectedToPlayList.map(func(card): return card.id),
		propagatedCardsSelectedToPlayComboType = cardsSelectedToPlayComboType,
		propagatedCardsSelectedToPlayQuintComboType = cardsSelectedToPlayQuintComboType,
		propagatedCardsSelectedToPlayComboOrdering = cardsSelectedToPlayComboOrdering,
		propagatedLASTLASTCardsPlayedIdList = cardsLastPlayedList.map(func(card): return card.id),
	}, BTActionType.TURN_PLAYED)
	lerpCardsToCenter(cardsSelectedToPlayList,cardsSelectedToPlayComboType)

	#clear all the cards that were selected to be played!
	cardsSelectedToPlayList = []
	playCardsButton.disabled = true
 
	pass # Replace with function body.

func _on_pass_turn_button_pressed():
	if(gameIsFinished):
		print("game is finished")
		return
	if(!currentTurnDirectionalOrientation == selfPlayerDirectionalOrientation):
		print("not your turn")
		return
	Gamedata.propagateActionType.rpc(Gamedata.ConnectionActionType.PROPAGATE_GAME_ACTION,{
		propagatedCardsPlayedByPlayerId = Gamedata.playerId,
		propagatedCardsPlayedByDirectionalOrientation = selfPlayerDirectionalOrientation,
	}, BTActionType.TURN_PASSED)
	pass # Replace with function body.



func _on_button_pressed():
	#a bot plays a card randomly

	#auto play for yourself only....
	if(!currentTurnDirectionalOrientation == selfPlayerDirectionalOrientation):
		print("not your turn")
		return
	makeComputerPlayACard()



func _on_auto_play_toggle_toggled(toggled_on):
	if(gameIsFinished):
		print("game is finished")
		return

	# autoPlayToggle.pressed = !autoPlayToggle.pressed
	selfAutoRobotPlay = toggled_on
	if(toggled_on  == true):
		_log("auto play is on")
		checkIfHostShouldAllowRobotToPlay()
	pass # Replace with function body.




func _on_sort_cards_pressed():
	handleSortSelfCardsOnHand()


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
	var isOnAnOpenTurn = checkIfIsAnOpenTurn()
	isOnAnOpenTurn = true if cardsLastPlayedComboType == CardPlayedComboType.OPEN_TURN else isOnAnOpenTurn

	if(isOnAnOpenTurn):
		_log("robot is on a open turn, and will play quint first then double then singles if possible if not just pass")
		cardsLastPlayedComboType = CardPlayedComboType.OPEN_TURN
		cardsLastPlayedComboOrdering = 0

	var computerCardsOnHandListSorted = computerCardsOnHand.values()
	computerCardsOnHandListSorted.sort_custom(func(cardA,cardB): return getSingleComboOrdering([cardA]) < getSingleComboOrdering([cardB]))
	#the robot will only check the first half of the cards in the list for a playable quint set.
	var prematureQuintBreakFlag = true 
	var prematureQuintCheckSize = 8 #only check the first 8 cards for a quint
	if !foundAPlayableCard and (cardsLastPlayedComboType == CardPlayedComboType.QUINT or isOnAnOpenTurn  or cardsLastPlayedComboType== CardPlayedComboType.FIRST_TO_PLAY_MUST_PLAY_THREE_OF_DIAMONDS):
		#check for every half a quint card
		var cardsToCheckArr = computerCardsOnHandListSorted
		if(prematureQuintBreakFlag):
			cardsToCheckArr = cardsToCheckArr.slice(0,prematureQuintCheckSize)
		for card1 in cardsToCheckArr:
			for card2 in cardsToCheckArr:
				if(card1.id == card2.id):
					continue
				for card3 in cardsToCheckArr:
					if(card1.id == card3.id or card2.id == card3.id):
						continue
					for card4 in cardsToCheckArr:
						if(card1.id == card4.id or card2.id == card4.id or card3.id == card4.id):
							continue
						for card5 in cardsToCheckArr:
							if(card1.id == card5.id or card2.id == card5.id or card3.id == card5.id or card4.id == card5.id):
								continue
							var cardsSelectedToPlayList = [card1,card2,card3,card4,card5]
							var cardsSelectedComboAndOrderingData = getCardsListComboTypeAndOrdering(cardsSelectedToPlayList)
							foundAPlayableCard = cardsSelectedComboAndOrderingData.comboCanBePlayedFlag
							if(foundAPlayableCard):
								computerCardsSelectedToPlayList.push_back(card1)
								computerCardsSelectedToPlayList.push_back(card2)
								computerCardsSelectedToPlayList.push_back(card3)
								computerCardsSelectedToPlayList.push_back(card4)
								computerCardsSelectedToPlayList.push_back(card5)
								computerCardsSelectedToPlayComboType = cardsSelectedComboAndOrderingData.comboType
								computerCardsSelectedToPlayComboOrdering = cardsSelectedComboAndOrderingData.comboOrdering
								computerCardsSelectedToPlayQuintComboType = cardsSelectedComboAndOrderingData.quintComboType
								break
						if(foundAPlayableCard):
							break
					if(foundAPlayableCard):
						break
				if(foundAPlayableCard):
					break
			if(foundAPlayableCard):
				break
	if !foundAPlayableCard and (cardsLastPlayedComboType == CardPlayedComboType.DOUBLE or isOnAnOpenTurn or cardsLastPlayedComboType== CardPlayedComboType.FIRST_TO_PLAY_MUST_PLAY_THREE_OF_DIAMONDS):
		#play a double card that is allowed to be played. else pass
		#check for every double card.
		for card1 in computerCardsOnHandListSorted:
			for card2 in computerCardsOnHandListSorted:
				if(card1.id == card2.id):
					continue
				var cardsSelectedToPlayList = [card1,card2]
				var cardsSelectedComboAndOrderingData = getCardsListComboTypeAndOrdering(cardsSelectedToPlayList)
				foundAPlayableCard = cardsSelectedComboAndOrderingData.comboCanBePlayedFlag
				if(foundAPlayableCard):
					computerCardsSelectedToPlayList.push_back(card1)
					computerCardsSelectedToPlayList.push_back(card2)
					computerCardsSelectedToPlayComboType = cardsSelectedComboAndOrderingData.comboType
					computerCardsSelectedToPlayComboOrdering = cardsSelectedComboAndOrderingData.comboOrdering
					computerCardsSelectedToPlayQuintComboType = cardsSelectedComboAndOrderingData.quintComboType
					break
			if(foundAPlayableCard):
				break
	if !foundAPlayableCard and (cardsLastPlayedComboType == CardPlayedComboType.SINGLE or isOnAnOpenTurn or cardsLastPlayedComboType== CardPlayedComboType.FIRST_TO_PLAY_MUST_PLAY_THREE_OF_DIAMONDS):
		#play a single card that is allowed to be played. else pass
		#check for every single card.
		#break out of the if statement if you found a playable card
		for card in computerCardsOnHandListSorted:
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
		print("THE ROBOT DECIDE TO PLAY: ",computerCardsSelectedToPlayList.map(func(card): return card.getShortRankAndSuitString()))

		Gamedata.propagateActionType.rpc(Gamedata.ConnectionActionType.PROPAGATE_GAME_ACTION,{
			propagatedCardsPlayedByPlayerId = -1000,
			propagatedCardsPlayedByDirectionalOrientation = currentTurnDirectionalOrientation,
			propagatedCardsSelectedToPlayIdList = computerCardsSelectedToPlayList.map(func(card): return card.id),
			propagatedCardsSelectedToPlayComboType = computerCardsSelectedToPlayComboType,
			propagatedCardsSelectedToPlayQuintComboType = computerCardsSelectedToPlayQuintComboType,
			propagatedCardsSelectedToPlayComboOrdering = computerCardsSelectedToPlayComboOrdering,
			propagatedLASTLASTCardsPlayedIdList = cardsLastPlayedList.map(func(card): return card.id),

		}, BTActionType.TURN_PLAYED)
		# remove the cards from the selected list
		for card in computerCardsSelectedToPlayList:
			if(cardsSelectedToPlayList.find(card) != -1):
				cardsSelectedToPlayList.erase(card)
	else:
		Gamedata.propagateActionType.rpc(Gamedata.ConnectionActionType.PROPAGATE_GAME_ACTION,{
			propagatedCardsPlayedByPlayerId = -1000,
			propagatedCardsPlayedByDirectionalOrientation = currentTurnDirectionalOrientation,
		}, BTActionType.TURN_PASSED)

####################### Event Handlers For Cards


#function to move the cards slight up when selected and back down when deselected

#move from SOTUH to WEST to NORTH to EAST to SOUTH
func cycleToNextPlayerTurn(directionalOrientation):

	var previousDirectionalOri = directionalOrientation
	var nextPlayerTurn = (directionalOrientation+1) % PLAYER_COUNT

	#check if the next player turn is a winner, if so, cycle again
	while(winnersListDirectionalOrientation.find(nextPlayerTurn) != -1):
		nextPlayerTurn = (nextPlayerTurn+1) % PLAYER_COUNT

	# print("previous turn is",getDirectionOriEnumStr(directionalOrientation))
	# print("now it is cycled to turn is",getDirectionOriEnumStr(nextPlayerTurn))


	var getLastScreenOri = selfDirectionOriToScreenOri[previousDirectionalOri]
	var lastTurnAvatar = screenOriToPlayerAvatar[getLastScreenOri].get_node("PlayerName")
	var currentTurnAvatar = screenOriToPlayerAvatar[selfDirectionOriToScreenOri[nextPlayerTurn]].get_node("PlayerName")

	lastTurnAvatar.text = getDirectionOriEnumStr(previousDirectionalOri)
	currentTurnAvatar.text = getDirectionOriEnumStr(nextPlayerTurn)	

	#the text should display the amount of cards left in their hand
	lastTurnAvatar.text += " " + str(CardsOnPlayersHands[previousDirectionalOri].size())
	currentTurnAvatar.text += " " + str(CardsOnPlayersHands[nextPlayerTurn].size())

	#check if the current turn is a robot, if so, append text saying its a robot:
	if(robotPositions.find(nextPlayerTurn) != -1):
		currentTurnAvatar.text += "[BOT]"
	if(robotPositions.find(previousDirectionalOri) != -1):
		lastTurnAvatar.text += "[BOT]"

	if(cardsLastPlayedDirectionalOrientation == nextPlayerTurn):
		currentTurnAvatar.text += " OPEN TURN! " 
	

	lastTurnAvatar.modulate = Color(1,1,1,1)
	currentTurnAvatar.modulate = Color(1,1,0.5,0.5)
	
	return nextPlayerTurn

func checkIfIsAnOpenTurn():
	#called to check if we are on a open turn
	#also a open turn if the last player that played finished their cards
	if(winnersListDirectionalOrientation.find(cardsLastPlayedDirectionalOrientation) != -1):
		return true

	return cardsLastPlayedDirectionalOrientation == currentTurnDirectionalOrientation
	# if(currentTurnDirectionalOrientation == selfPlayerDirectionalOrientation and passCounter == 3):
	# 	isOnAnOpenTurn = true
	# else:
	# 	isOnAnOpenTurn = false
	# return isOnAnOpenTurn
func handleOnCardIsSelected(card):
	handleCardSFX(CardAction.SELECTED)
	if(!card.isSelected):
		card.setCardRestSnapPos(card.restSnapPos + Vector2(0,-50))
		cardsSelectedToPlayList.push_back(card)
	else:
		card.setCardRestSnapPos(card.restSnapPos + Vector2(0,50))
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

	#if playing the 3 of diamonds then check if the list has a 3 of diamonds
	if(cardsLastPlayedComboType == CardPlayedComboType.FIRST_TO_PLAY_MUST_PLAY_THREE_OF_DIAMONDS):
		# print("checking if you have a three of diamonds")
		if(cardsList.filter(func(card): return card.rank == '3' and card.suit == 'diamonds').size() == 0):
			# print("you must play the 3 of diamonds")
			localCardsSelectedToPlayComboType = CardPlayedComboType.INVALID_COMBO
			return {
				"comboType":localCardsSelectedToPlayComboType,
				"comboOrdering":localCardsSelectedToPlayComboOrdering,
				"quintComboType":localCardsSelectedToPlayQuintComboType,
				"comboCanBePlayedFlag":false
			}
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

	# print("comparing the ordering right now, previous ordering is",cardsLastPlayedComboOrdering,"current ordering is",localCardsSelectedToPlayComboOrdering)
	if(localCardsSelectedToPlayComboType != CardPlayedComboType.INVALID_COMBO):
		if(cardsLastPlayedComboType == CardPlayedComboType.OPEN_TURN or cardsLastPlayedComboType == CardPlayedComboType.FIRST_TO_PLAY_MUST_PLAY_THREE_OF_DIAMONDS):
			localCardsSelectedCanBePlayedFlagComparedToLastPlayedCard = true
		elif(localCardsSelectedToPlayComboType == cardsLastPlayedComboType):
			if(localCardsSelectedToPlayComboOrdering > cardsLastPlayedComboOrdering):
				localCardsSelectedCanBePlayedFlagComparedToLastPlayedCard = true
		#if everyone passed, and it is now back at your own turn, you can play anything you want
		if(checkIfIsAnOpenTurn()):
			localCardsSelectedCanBePlayedFlagComparedToLastPlayedCard = true
	# print("result is",localCardsSelectedCanBePlayedFlagComparedToLastPlayedCard)
	if(localCardsSelectedCanBePlayedFlagComparedToLastPlayedCard):
		print("the local cardselect to play combo type is = ",getEnumStr(CardPlayedComboType,localCardsSelectedToPlayComboType))
		print("the card play list is = ",cardsList.map(func(card): return card.getShortRankAndSuitString()))	
		# if(currentTurnDirectionalOrientation == selfPlayerDirectionalOrientation):
			# localCardsSelectedCanBePlayedFlagComparedToLastPlayedCard = true
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
	#flip cards up
	if(cardComboType == CardPlayedComboType.SINGLE):
		var card = cardsList[0]
		card.setCardRestSnapPos(PLAYED_CARDS_SNAP_POSITION)
		card.z_index = numCardsZIndexCounter
		numCardsZIndexCounter+=1
		card.flipCardUp()
		handleCardSFX(CardAction.PLAYED)
		return
	elif(cardComboType == CardPlayedComboType.DOUBLE):
		var card1 = cardsList[0]
		var card2 = cardsList[1]
		card1.setCardRestSnapPos(PLAYED_CARDS_SNAP_POSITION)
		card2.setCardRestSnapPos(PLAYED_CARDS_SNAP_POSITION + Vector2(100,0))
		card1.z_index = numCardsZIndexCounter
		card2.z_index = numCardsZIndexCounter
		numCardsZIndexCounter += 1
		card1.flipCardUp()
		card2.flipCardUp()
		handleCardSFX(CardAction.PLAYED)
		return
	elif(cardComboType == CardPlayedComboType.QUINT):
		var card1 = cardsList[0]
		var card2 = cardsList[1]
		var card3 = cardsList[2]
		var card4 = cardsList[3]
		var card5 = cardsList[4]
		# card1.restSnapPos = PLAYED_CARDS_SNAP_POSITION
		# card2.restSnapPos = PLAYED_CARDS_SNAP_POSITION + Vector2(100,0)
		# card3.restSnapPos = PLAYED_CARDS_SNAP_POSITION + Vector2(200,0)
		# card4.restSnapPos = PLAYED_CARDS_SNAP_POSITION + Vector2(300,0)
		# card5.restSnapPos = PLAYED_CARDS_SNAP_POSITION + Vector2(400,0)
		card1.setCardRestSnapPos(PLAYED_CARDS_SNAP_POSITION)
		card2.setCardRestSnapPos(PLAYED_CARDS_SNAP_POSITION + Vector2(100,0))
		card3.setCardRestSnapPos(PLAYED_CARDS_SNAP_POSITION + Vector2(200,0))
		card4.setCardRestSnapPos(PLAYED_CARDS_SNAP_POSITION + Vector2(300,0))
		card5.setCardRestSnapPos(PLAYED_CARDS_SNAP_POSITION + Vector2(400,0))

		handleCardSFX(CardAction.QUINT_PLAYED)

		card1.z_index = numCardsZIndexCounter
		card2.z_index = numCardsZIndexCounter
		card3.z_index = numCardsZIndexCounter
		card4.z_index = numCardsZIndexCounter
		card5.z_index = numCardsZIndexCounter
		numCardsZIndexCounter +=1
		card1.flipCardUp()
		card2.flipCardUp()
		card3.flipCardUp()
		card4.flipCardUp()
		card5.flipCardUp()
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
	#the first guy will always have diamond three, whoever is the host will get d3 if no shuffle
	print("started game #pretend we are drawing cards here")
	#assigning screen positions and orientations

	#playeridlistidx is the same listing always.
	for playerIdListIdx in range(PLAYER_COUNT):
		var playerId = allPlayerIdList[playerIdListIdx] 
		var dirOri = playerIdListIdx
		if selfPlayerId == playerId:
			selfPlayerDirectionalOrientation = dirOri #which one is you...
			#if you are first, you are assigned SOUTH, second is WEST, third is NORTH, fourth is EAST

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
	# NOW THEY ARE MAPPED TO EACH OTHER! <ScreenOrientation : DirectionOrientation>

	for currentScreenOrientation in range(PLAYER_COUNT): #bot left top right, in that order, the game will be played like that too.
		var currentDirectionOrientation = directionOrientationArr[currentScreenOrientation] #first one will be selfPlayerDirectionalOrientation #could be west and you are bot
		selfDirectionOriToScreenOri[currentDirectionOrientation] = currentScreenOrientation



	for currentDirectionalOrientation in range(PLAYER_COUNT):

		var playerId = allPlayerIdList[currentDirectionalOrientation] #
		# print("what tf")
		# print(allPlayerIdList)
		# print(playerId)
		if(lobbyContainsRobot and playerId < 0):

			robotPositions.push_back(currentDirectionalOrientation)

		var currentScreenOrientation = selfDirectionOriToScreenOri[currentDirectionalOrientation] #first one will be selfPlayerDirectionalOrientation #could be west and you are bot
		distributeCards({
			temporaryCardStack = temporaryCardStack,
			currentDirectionOrientation = currentDirectionalOrientation,
			currentScreenOrientation = currentScreenOrientation,
			isOwnedByCurrentPlayer = playerId == selfPlayerId,
			playerId = playerId,
		})

func distributeCards(data):
	var initY = 300
	var initX = 0
	var offSetX = -600
	var distance = 1280/13
	var counter = 0
	var posAvatarSnapPos = screenOriToPlayerAvatar[data.currentScreenOrientation].get_node("CardSnapPos").global_position

	for i in range(NUM_CARDS_PER_PLAYER):
		var card = data.temporaryCardStack.pop_back()
		if(card.suit == 'diamonds' and card.rank == '3'):
			currentTurnDirectionalOrientation = data.currentDirectionOrientation # the player with 3 of diamonds goes first.
			_log("player with 3 of diamonds goes first, and it is " + getDirectionOriEnumStr(currentTurnDirectionalOrientation))
		card.initBTCardOwner(data.isOwnedByCurrentPlayer,data.playerId,data.currentDirectionOrientation,data.currentScreenOrientation)
		CardsOnPlayersHands[data.currentDirectionOrientation][card.id] = card
		if(!data.isOwnedByCurrentPlayer):
			# card.restSnapPos = posAvatarSnapPos
			card.setCardRestSnapPos(posAvatarSnapPos)
			card.flipCardDown()

		else: #you do own the card so lets put it on the bottom!!!
			card.setCardRestSnapPos(Vector2(initX+distance*counter+offSetX,initY))
			# card.restSnapPos = Vector2(initX+distance*counter+offSetX,initY)
			card.flipCardUp()
		counter+=1  
	handleCardSFX(CardAction.DISTRIBUTED)
####################### making things look pretty ANIMATION FUNCTIONS
var isSortedAscending = false
func handleSortSelfCardsOnHand():
	
	var cardsOnHand = CardsOnPlayersHands[selfPlayerDirectionalOrientation]
	var cardsOnHandArr = cardsOnHand.values()
	if(cardsOnHandArr.size() == 0):
		return	

	if(isSortedAscending):
		cardsOnHandArr.sort_custom(func(cardA,cardB): return getSingleComboOrdering([cardA]) > getSingleComboOrdering([cardB]))
		isSortedAscending = false
	else:
		cardsOnHandArr.sort_custom(func(cardA,cardB): return getSingleComboOrdering([cardA]) < getSingleComboOrdering([cardB]))
		isSortedAscending = true;


	print("sorted cards on hand",cardsOnHandArr.map(func(card): return card.getShortRankAndSuitString()))
	var initY = 300
	var initX = 0
	var offSetX = -600
	var distance = 1280/13
	var counter = 0

	handleCardSFX(CardAction.SORTED)
	for card in cardsOnHandArr:
		card.setCardRestSnapPos(Vector2(initX+distance*counter+offSetX,initY))
		counter+=1

@onready var cardSlide_SFX = 	$SoundSFX/cardSlideSFX
@onready var cardPlaced_SFX = 	$SoundSFX/cardPlacedSFX
@onready var cardDiscarded_SFX =$SoundSFX/cardDiscardedSFX
enum CardAction {
	PLAYED,DISTRIBUTED,SELECTED,DISCARDED,QUINT_PLAYED,SORTED
}
func handleCardSFX(cardAction):
	if(cardAction == CardAction.PLAYED):
		cardPlaced_SFX.play()
	elif(cardAction == CardAction.DISTRIBUTED):
		cardSlide_SFX.play()
	elif(cardAction == CardAction.SELECTED):
		cardSlide_SFX.play()
	elif(cardAction == CardAction.DISCARDED):
		cardDiscarded_SFX.play()
	elif(cardAction == CardAction.QUINT_PLAYED):
		cardPlaced_SFX.play()
	elif(cardAction == CardAction.SORTED):
		cardSlide_SFX.play()
	else:
		print("error, card action not found")

####################### UTILITY FUNCTIONS
func getDirectionOriEnumStr(value):
	return getEnumStr(DirectionOrientation,value)
func getScreenOriEnumStr(value):
	return getEnumStr(ScreenOrientation,value)
func getEnumStr(enums,value):
	return enums.keys()[value]
func enumToStr(enums,value):
	return enums.keys()[value]

var maxLogSize = 10
func _log(msg):
	maxLogSize+=1
	if(maxLogSize > 10):
		$TestRelated/DebugLog.text = ""
		maxLogSize = 0
	$TestRelated/DebugLog.text += str(msg) + "\n"




	
var doneInitialized = false
func _process(delta):
	
	if(!doneInitialized):
		return
	playerInfoLabel.text = "
		You are player: " + str(selfPlayerId) + "
		Your directional orientation is: " + getDirectionOriEnumStr(selfPlayerDirectionalOrientation) + "
		Your # of card on hand is: " + str(CardsOnPlayersHands[selfPlayerDirectionalOrientation].size()) + "
		You have selected to Play: " + str(cardsSelectedToPlayList.size()) + " cards
		Your combo is: " + getEnumStr(CardPlayedComboType,cardsSelectedToPlayComboType) + "
		Your quint combo is: " + getEnumStr(QuintComboType,cardsSelectedToPlayQuintComboType) + "
		Your combo ordering is: " + str(cardsSelectedToPlayComboOrdering) + "
		Current turn is: " + getDirectionOriEnumStr(currentTurnDirectionalOrientation) + "
		Last Player Played Directional Orientation is: " + getDirectionOriEnumStr(cardsLastPlayedDirectionalOrientation) + "
		Last played combo is: " + getEnumStr(CardPlayedComboType,cardsLastPlayedComboType) + "
		Last played quint combo is: " + getEnumStr(QuintComboType,cardsLastPlayedQuintComboType) + "
		Last played combo ordering is: " + str(cardsLastPlayedComboOrdering) + "
		Last played by player id: " + str(cardsLastPlayedPlayerId) + "
		Last played by directional orientation: " + getDirectionOriEnumStr(cardsLastPlayedDirectionalOrientation) + "
		Is on open turn: " + str(checkIfIsAnOpenTurn()) + "
		North: " + str(CardsOnPlayersHands[DirectionOrientation.NORTH].values().map(func (card): return card.getShortRankAndSuitString())) + "
		East: " + str(CardsOnPlayersHands[DirectionOrientation.EAST].values().map(func (card): return card.getShortRankAndSuitString())) + "
		South: " + str(CardsOnPlayersHands[DirectionOrientation.SOUTH].values().map(func (card): return card.getShortRankAndSuitString())) + "
		West: " + str(CardsOnPlayersHands[DirectionOrientation.WEST].values().map(func (card): return card.getShortRankAndSuitString())) + "
		currentRNGSeed: " + str(currentGameRNGSeed) + "
		"
	return







func _on_restart_game_button_pressed():
	restartButton.disabled = true
	Gamedata.propagateActionType.rpc(Gamedata.ConnectionActionType.RESTART,Gamedata.GameType.CHINESE_POKER)
	pass # Replace with function body.




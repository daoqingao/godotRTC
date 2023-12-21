extends Area2D
class_name BTCard
#these models should be shared
enum DirectionOrientation {
	SOUTH,WEST,NORTH,EAST
}

enum ScreenOrientation {
	BOT,LEFT,TOP,RIGHT
}
enum CardAction {
	PLAYED,DISTRIBUTED,SELECTED,DISCARDED,QUINT_PLAYED
}
func getDirectionOriEnumStr(value):
	return getEnumStr(DirectionOrientation,value)
func getScreenOriEnumStr(value):
	return getEnumStr(ScreenOrientation,value)
func getEnumStr(enums,value):
	return enums.keys()[value]



const lerpSpeed = 12

#all of the drag and drop animation stuff below
var selected = false
var flippedUp = false; #anything at card front z-index 6 is up, 4 is down
var restSnapPos:Vector2 = Vector2.ZERO;
var isInDroppableArea = false


# @onready var cardCanvasLayer = $CardCL
@onready var animation = 	 $FlipCardAnimation
@onready var cardTextLabel = $CardTextLabel
@onready var cardFront = 	 $CardFront
@onready var cardBack =		 $CardBack

@onready var cardCollision = $CardCollision
@onready var cardController = $CardController

#chinese poker related things
var suit := ""
var rank := ""
var id := -1

var isOwnedByCurrentPlayer = false
var ownerPlayerId = -1
var directionOrientation = 0
var screenOrientation = -1

var isSelected = false


# var beforeLerpingToMousePos = Vector2.ZERO
var lerpToMousePos = Vector2.ZERO
var isLerpingToMouse = false


var selectedPos = Vector2.ZERO
var unSelectedPos = Vector2.ZERO
func getSelectedPos():
	return selectedPos
	return self.global_position + Vector2(0,-50)
func getUnSelectedPos():
	return unSelectedPos
	return self.global_position + Vector2(0,50)

func initBTCardType(suit,rank,id): #this like shuffling the deck physically
	self.suit = suit
	self.rank = rank
	self.id = id

	var useCardsWithNumbersTogether = true
	var cardNum =  "0"+rank if 	rank.is_valid_int() && rank.length() < 2 else rank
	var cardImgPathStr = ("res://asset/Cards (large)/" +"card_" + self.suit + "_" + cardNum + ".png")


	if(useCardsWithNumbersTogether):
		#making the first letter of the card suit str uppercase
		var cardSuitFirstLetterUpper= self.suit[0].to_upper() + self.suit.substr(1,self.suit.length())
		cardImgPathStr = ("res://asset//CardsLetterNumsTogether/" +"card" + cardSuitFirstLetterUpper + rank + ".png")
		print(cardImgPathStr)
	# print(cardImgPathStr)
	var cardImgTexture = load(cardImgPathStr)
	cardFront.texture = cardImgTexture



func initBTCardOwner(isOwnedByCurrentPlayer,ownerPlayerId,directionOrientation,screenOrientation): #its like drawing the cards physically
	self.isOwnedByCurrentPlayer = isOwnedByCurrentPlayer
	self.ownerPlayerId = ownerPlayerId
	self.directionOrientation = directionOrientation
	self.screenOrientation = screenOrientation
func _physics_process(delta):
	if(isLerpingToMouse):
		global_position=lerp(global_position,get_global_mouse_position(),lerpSpeed * delta)
	# isOwner = $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()
	# isOwnedByCurrentPlayer = true
	# if selected and isOwnedByCurrentPlayer:
	# 	position = lerp(position,get_global_mouse_position(),25 * delta)
	# 	restSnapPos = position
	# else:
	# position = lerp(position,restSnapPos,lerpSpeed * delta)
	return
func _ready():
	pass 

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	cardTextLabel.text = getShortRankAndSuitString() + "z " + str(z_index) + "l" + str(visibility_layer)
	pass


func setCardRestSnapPos(pos,reason=-1):
	var tweenTime = .2
	if(reason==CardAction.DISTRIBUTED):
		self.selectedPos = pos + Vector2(0,-50)
		self.unSelectedPos = pos + Vector2(0,0)
		tweenTime = 1
	var tween = get_tree().create_tween()
	tween.tween_property(self,
	"position",
	pos,tweenTime).set_trans(4)

	restSnapPos = pos
	
	# cardCanvasLayer.offset = pos
	return 	tween.tween_interval(tweenTime)

	#use tween to move the card to the restSnapPos



func _to_string():
	return getShortRankAndSuitString()
	return "Card ID: %d, Suit: %s, Rank: %s, Is Owned by Player? %s (Player ID: %d), Orientation: %d" % [
		id,
		suit,
		rank,
		str(isOwnedByCurrentPlayer),
		ownerPlayerId,
		directionOrientation,
	]

func getShortRankAndSuitString():
	return "%s%s" % [
		rank,
		getEmojiSuitString(),
	]



func getEmojiSuitString():
	if(suit == "spades"):
		return "♠"
	elif(suit == "hearts"):
		return "♥"
	elif(suit == "diamonds"):
		return "♦"
	elif(suit == "clubs"):
		return "♣"
	else:
		return "?"





#all the drag and drop functionalities and flip animation stuff...
func flipCard():
	if(animation.is_playing()):
		return
	if(flippedUp):
		print("flipping down with")
		animation.play("card_flip_down")	
		flippedUp = false
	else:
		animation.play("card_flip_up")	
		flippedUp = true
	await animation.animation_finished
	return animation


func flipCardDown():
	if(animation.is_playing()):
		await animation.animation_finished
	if(flippedUp):
		animation.play("card_flip_down")	
		flippedUp = false
	await animation.animation_finished
	return animation
func flipCardUp():
	if(animation.is_playing()):
		await animation.animation_finished
	if(!flippedUp):
		animation.play("card_flip_up")	
		flippedUp = true
	await animation.animation_finished
	return animation

# func _input(event):
# 	if(!isOwnedByCurrentPlayer):
# 		return # not allowed to do anything with this card
# 	if event is InputEventMouseButton:
# 		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
# 			selected = false
# 			if(isInDroppableArea):
# 				#you are dropped. sooo
# 				isInDroppableArea = false
# 				isPlayedSignal.emit(self)


signal isDraggedStart(cards)
signal isDraggingSelecting(cards)
signal isDraggedEnd(cards)

signal triggerMouseEnterTopOfCard(cards)
signal triggerMouseExitTopOfCard(cards)

func _on_control_gui_input(event):
	# print(event)

	#what is being clicked here does not necessarily mean its the cards being clicked due to 
	#due to godot sucking 
	if( event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and !event.pressed ): #this is mouse on release
		isDraggedEnd.emit(self)
	if(event.is_action_pressed("leftClick")): #thi sis mouse on mouse down
		isDraggedStart.emit(self)
	if(event is InputEventMouseMotion): #on hover
		isDraggingSelecting.emit(self)

		pass
#when you drag the cards a bit above the card it will be lerped to mouse to be readied to be played
func _on_area_trigger_to_play_mouse_entered():
	pass # Replace with function body.


func _on_area_trigger_to_play_mouse_exited():
	pass # Replace with function body.

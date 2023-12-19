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

#card movement related things

var isSelected = false

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


signal isPlayedSignal(vars)
signal isSelectedSignal(card) #this is a click signal

signal isDraggedStart(cards)
signal isDraggingSelecting(cards)
signal isDraggedEnd(cards)


var isDragging = false
func _on_control_gui_input(event):
	# print(event)
	if( event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and !event.pressed ): #this is mouse on release
		# print("mouse on release")
		# print(getShortRankAndSuitString())
		isDragging = false
		isDraggedEnd.emit(self)
		pass
	if(event.is_action_pressed("leftClick")): #thi sis mouse on mouse down
		# print("mouse on mouse down")
		# print(getShortRankAndSuitString())
		isDragging = true
		isDraggedStart.emit(self)
	if(event is InputEventMouseMotion): #on hover
		# print("mouse on hover")
		# print(getShortRankAndSuitString())
		if(isDragging):
			isDraggingSelecting.emit(self)



# func _input(event):
# 	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
# 		if cardFront.get_rect().has_point(to_local(event.position)):
# 			print(event.position)
# 			print("A click!")

# var click_all = false
# var ignore_unclickable = true
# func _on_input_event(viewport, event, shape_idx):
# 	print("mouse input from area 2d ")
# 	print(getShortRankAndSuitString())

# 	if event.is_action_pressed("leftClick"):
# 		#get the intersection of the current mouse
# 		# var shapes = get_world_2d().direct_space_state.intersect_point() # The last 'true' enables Area2D intersections, previous four values are all defaults
# 		pass
	#PRINT JUST GIVE UP LMAO	
# func _on_is_dragged_select(cards):
# 	print("what is this?")
# 	pass # Replace with function body.
# 2046808109


# func _on_input_event(viewport, event, shape_idx):
# 	#on click
# 	if event is InputEventMouseButton:
# 		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
# 			print("shorttext is " + getShortRankAndSuitString())
# 			viewport.set_input_as_handled()
# 	pass # Replace with function body.


# func _on_texture_button_pressed():
# 	print("sss is " + getShortRankAndSuitString())
# 	pass # Replace with function body.

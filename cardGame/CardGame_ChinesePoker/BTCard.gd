extends Area2D
class_name BTCard
#these models should be shared
enum DirectionOrientation {
	SOUTH,WEST,NORTH,EAST
}

enum ScreenOrientation {
	BOT,LEFT,TOP,RIGHT
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
var flippedUp = true; #anything at card front z-index 6 is up, 4 is down
var restSnapPos:Vector2 = Vector2.ZERO;
var isInDroppableArea = false
@onready var animation = $FlipCardAnimation


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
	var cardNum =  "0"+rank if 	rank.is_valid_int() && rank.length() < 2 else rank
	var cardImgPathStr = ("res://asset/Cards (large)/" +"card_" + self.suit + "_" + cardNum + ".png")
	# print(cardImgPathStr)
	var cardImgTexture = load(cardImgPathStr)
	$CardFront.texture = cardImgTexture

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
	position = lerp(position,restSnapPos,lerpSpeed * delta)
func _ready():
	pass 

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$Label.text = str(ownerPlayerId) + getDirectionOriEnumStr(directionOrientation) + getScreenOriEnumStr(screenOrientation) + str(id)
	pass



func _to_string():
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

func _input(event):
	if(!isOwnedByCurrentPlayer):
		return # not allowed to do anything with this card
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			selected = false
			if(isInDroppableArea):
				#you are dropped. sooo
				isInDroppableArea = false
				isPlayedSignal.emit(self)
func _on_input_event(viewport, event, shape_idx):
	if(!isOwnedByCurrentPlayer):
		return # not allowed to do anything with this card
	if event.is_action_pressed("leftClick"):
		isSelectedSignal.emit(self)
	if event.is_action_pressed("rightClick"):
		flipCard()

signal isPlayedSignal(vars)
signal isSelectedSignal(card)

extends Area2D

# Called when the node enters the scene tree for the first time.
# structure for the card class...
#i just call it BT (big two, because chinese poker (cp) sounds bad i dont want to keep retyping it)
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
func construct(cardData):
	# self.position = cardData.cardPos
	# self.restSnapPos = position
	# self.cardType = cardData.cardType
	# self.isOwner = cardData.isOwner
	# self.cardId = cardData.cardId

	self.cardData = cardData
	
	# # print("am i the owner? of this card",self.isOwner, self.cardId)
	# if(self.cardType=="ROCK"):
	# elif (self.cardType=="SCISSOR"):
	# 	$CardFront/Type.text = "✂️"
	# else:
	# 	$CardFront/Type.text = "📃"
	# if(self.isOwner):
	# 	flippedUp = true
	# 	$CardFront.z_index = 6
	# 	$CardBack.z_index = 5
	# else:
	# 	flippedUp = false
	# 	$CardBack.scale.x = 1		
	# 	$CardFront.z_index = 4
	# 	$CardBack.z_index = 5
	
	# $MultiplayerSynchronizer.set_multiplayer_authority(cardData.ownerId)

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
	isOwnedByCurrentPlayer = true
	if selected and isOwnedByCurrentPlayer:
		position = lerp(position,get_global_mouse_position(),25 * delta)
		restSnapPos = position
	else:
		position = lerp(position,restSnapPos,25 * delta)
func _ready():
	pass 

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$Label.text = str(ownerPlayerId) + getDirectionOriEnumStr(directionOrientation) + getScreenOriEnumStr(screenOrientation)
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
				isPlayed.emit(self)
func _on_input_event(viewport, event, shape_idx):
	if(!isOwnedByCurrentPlayer):
		return # not allowed to do anything with this card
	if event.is_action_pressed("leftClick"):
		selected = true
	if event.is_action_pressed("rightClick"):
		flipCard()

signal isPlayed(vars)

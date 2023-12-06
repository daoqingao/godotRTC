extends Area2D

# Called when the node enters the scene tree for the first time.
# structure for the card class...
class_name Card
var cardType=""
var cardNum
var cardImg


var selected = false
var newSnapPos = null;
var ownerId = 1;
var cardId = -1;

var flippedUp = true; #anything at card front z-index 6 is up, 4 is down
var restSnapPos:Vector2 = Vector2.ZERO;
var isOwner = false


var isInDroppableArea = false




func construct(cardData):
	self.position = cardData.cardPos
	self.restSnapPos = position
	self.cardType = cardData.cardType
	self.isOwner = cardData.isOwner
	self.cardId = cardData.cardId
	
	print("am i the owner? of this card",self.isOwner, self.cardId)
	if(self.isOwner):
		flippedUp = true
		$CardFront.z_index = 6
		$CardBack.z_index = 5
	else:
		flippedUp = false
		$CardBack.scale.x = 1		
		$CardFront.z_index = 4
		$CardBack.z_index = 5
	# $MultiplayerSynchronizer.set_multiplayer_authority(cardData.ownerId)


func _physics_process(delta):
	# isOwner = $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()

	if selected and isOwner:
		position = lerp(position,get_global_mouse_position(),25 * delta)
	else:
		position = lerp(position,restSnapPos,25 * delta)
func _ready():
	# self.isOwner = true
	# flippedUp = false
	# $CardBack.scale.x = 1
	# $CardFront.z_index = 4
	# $CardBack.z_index = 5
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$Label.text = (cardType  + str(cardId) + str(isOwner))
	pass



func flipCard():
	var animation = $FlipCardAnimation
	if(animation.is_playing()):
		return
	if(flippedUp):
		print("flipping down with")
		animation.play("card_flip_down")	
		flippedUp = false
	else:
		animation.play("card_flip_up")	
		flippedUp = true

func _input(event):
	if(!isOwner):
		return # not allowed to do anything with this card
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			selected = false
			# if(newSnapPos!=null):
			# 	restSnapPos = Vector2(newSnapPos.x,newSnapPos.y)
			# 	newSnapPos = null
			if(isInDroppableArea):
				isPlayed.emit(self)
func _on_input_event(viewport, event, shape_idx):
	if(!isOwner):
		return # not allowed to do anything with this card
	if event.is_action_pressed("leftClick"):
		selected = true
	if event.is_action_pressed("rightClick"):
		flipCard()


signal isPlayed(vars)

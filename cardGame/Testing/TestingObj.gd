extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


var id = -1

# func _on_area_2d_input_event(viewport, event, shape_idx):
# 	#check if it is a click event:
# 	if(event is InputEventMouseButton):
# 		if(event.pressed):
# 			print(event)
# 			print(viewport)
# 			print(shape_idx)
# 			viewport.set_input_as_handled()
# 			print("i got clicked. by area...", id)
			
	
	#get_overlapping

#func _on_control_gui_input(event):
	##check if it s a click event:
	#if(event is InputEventMouseButton):
		#if(event.pressed):
			#print(event)
			#print("i got clicked. by control...", id)
		#else:
			#print("not a click handle by control", id)


func _on_button_pressed():
	print("i got clicked. by button...", id)
	pass # Replace with function body.

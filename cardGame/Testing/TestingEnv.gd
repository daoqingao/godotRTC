extends Node2D

@onready var testingObj = preload("res://cardGame/Testing/TestingObj.tscn")
# Called when the node enters the scene tree for the first time.
func _ready():
	var onTop = testingObj.instantiate()
	var onBot = testingObj.instantiate()
	
	onTop.id = "top"
	onBot.id = "bot"
	
	#onTop.z_index = 1
	#onBot.z_index = 100
	#set the area2d collision mask to 0 so that it does not collide with anything
	onTop.get_node("cl").layer = 100
	onBot.get_node("cl").layer = 1000
	
	#onTop.get_node("Area2D").collision_mask = 100
	#onBot.get_node("Area2D").collision_mask = 0
#
	#onTop.get_node("Area2D").get_node("Button").z_index = 100
	#onBot.get_node("Area2D").get_node("Button").z_index = 0
	
	#the z index does not affect who is the first to get the item

	onTop.get_node("cl").get_node("Area2D").position = Vector2.ONE*100
	onBot.get_node("cl").get_node("Area2D").position = Vector2.ONE*200
	
	
	
	add_child(onTop)
	add_child(onBot) #if top is above, bot gets clicked first no matter what	 #right now !VERY IMPORTANT, THE NODE ADDED LAST BOTTOM GETS PRIORITY... WHEN IT SHOULDNT
	#
	#
	#
	#
	#var unsorted := get_children()
	#var sorted_nodes := []
#
#
#
	##sort these nodes based on their z index
	#for node in unsorted:
		#for i in range(sorted_nodes.size()):
			#if node.z_index < sorted_nodes[i].z_index:
				#break
			#sorted_nodes.insert(i, node)
#
#
	#for node in self.get_children():
		#remove_child(node)
#
	#for node in sorted_nodes:
		#add_child(node)
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

extends Control

func _enter_tree():
	for c in $VBoxContainer/Clients.get_children():
		# So each child gets its own separate MultiplayerAPI.
		get_tree().set_multiplayer(
			MultiplayerAPI.create_default_interface(),
			NodePath("%s/VBoxContainer/Clients/%s" % [get_path(), c.name])
		)

func _ready():
	if OS.get_name() == "HTML5":
		$VBoxContainer/Signaling.hide()
	if  "--server" in OS.get_cmdline_args():
		$Server.listen(7000)

func _on_listen_toggled(button_pressed):
	if button_pressed:
		$Server.listen(int($VBoxContainer/Signaling/Port.value))
	else:
		$Server.stop()


func _on_LinkButton_pressed():
	OS.shell_open("https://github.com/godotengine/webrtc-native/releases")

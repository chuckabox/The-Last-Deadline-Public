extends Control

func _ready():
	print("Blackout Ending")
	get_tree().paused = false # Ensure game isn't stuck paused from a minigame/dialogue
	
	# Clear any leftover fade to black from RoomTransitionManager
	var fade_layer = get_tree().get_root().get_node_or_null("FadeLayer")
	if fade_layer:
		fade_layer.queue_free()
	
	var text_label = get_node_or_null("TextLabel")
	var buttons_container = get_node_or_null("Buttons")
	var music = get_node_or_null("/root/MusicManager")

	if music:
		music.stop_music()

	# Narrative was already shown in the cutscene; this scene is just the
	# "back to main menu" capstone.
	if text_label:
		text_label.hide()
	if buttons_container:
		buttons_container.show()

	var menu_btn = get_node_or_null("Buttons/MainMenuButton")
	if menu_btn:
		if not menu_btn.pressed.is_connected(_on_menu_pressed):
			menu_btn.pressed.connect(_on_menu_pressed)

func _on_menu_pressed():
	var menu_path = "res://scenes/ui/MainMenu.tscn"
	if ResourceLoader.exists(menu_path):
		get_tree().change_scene_to_file(menu_path)
	else:
		get_tree().change_scene_to_file("res://Main.tscn")

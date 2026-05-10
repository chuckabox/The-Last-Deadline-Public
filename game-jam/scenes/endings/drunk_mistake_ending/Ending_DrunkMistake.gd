extends Control

func _ready():
	print("Drunk Mistake Ending")
	
	var text_label = get_node_or_null("TextLabel")
	var music = get_node_or_null("/root/MusicManager")
	
	# Stop the music for the fuzzy fade out
	if music:
		music.stop_music()
	
	if text_label:
		text_label.text = "Everything went fuzzy.\n\n..."
		text_label.show()
	
	await get_tree().create_timer(3.0).timeout
	
	if text_label:
		text_label.text = "You woke up at 3:00 AM on the office sofa.\nThe deadline had passed.\n\nYou failed."
	
	await get_tree().create_timer(5.0).timeout
	print("Game Over - Drunk Mistake Ending reached.")
	_show_main_menu_button()

func _show_main_menu_button():
	var btn = Button.new()
	btn.text = "Main Menu"
	btn.add_theme_font_size_override("font_size", 22)
	btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	btn.offset_left = -120
	btn.offset_right = 120
	btn.offset_top = -90
	btn.offset_bottom = -40
	add_child(btn)
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
	btn.grab_focus()

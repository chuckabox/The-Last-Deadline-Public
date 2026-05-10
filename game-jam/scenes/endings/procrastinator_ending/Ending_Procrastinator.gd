extends Control

func _ready():
	print("Procrastinator Ending")
	
	var text_label = get_node_or_null("TextLabel")
	var phone_label = get_node_or_null("PhoneLabel")
	
	# Reference managers
	var music = get_node_or_null("/root/MusicManager")
	var sfx = get_node_or_null("/root/SFXManager")
	
	# Stop all music for dramatic effect
	if music:
		music.stop_music()
	
	# Animate sequence
	await get_tree().create_timer(1.0).timeout
	if text_label:
		text_label.show()
		text_label.text = "The clock struck midnight."
	
	await get_tree().create_timer(2.0).timeout
	if text_label:
		text_label.text = "You never made it out."
	
	await get_tree().create_timer(2.0).timeout
	
	# Play vibration sound if available
	if sfx:
		sfx.play_sfx("phone_vibrate")
		
	if phone_label:
		phone_label.show()
		phone_label.text = "Grade: 0% - Late submission not accepted."
	
	await get_tree().create_timer(4.0).timeout
	print("Game Over - Procrastinator Ending reached.")
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

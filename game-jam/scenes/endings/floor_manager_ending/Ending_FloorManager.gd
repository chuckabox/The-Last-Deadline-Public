extends Control

func _ready():
	print("Floor Manager Ending")
	
	var text_label = get_node_or_null("TextLabel")
	var music = get_node_or_null("/root/MusicManager")
	
	# Dim the music for a more somber mood
	if music:
		music.volume_db = -25.0
	
	if text_label:
		text_label.text = "You became the new Floor Manager.\n\nYou have money, but your degree is abandoned.\n\nA year later, you're still pouring drinks\nand wondering what could have been."
		text_label.show()
	
	await get_tree().create_timer(7.0).timeout
	print("Ending - Floor Manager reached.")
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

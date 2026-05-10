extends Control

func _ready():
	print("Drunk Mistake Ending")

	var text_label = get_node_or_null("TextLabel")
	if text_label:
		text_label.hide()

	var music = get_node_or_null("/root/MusicManager")
	if music:
		music.stop_music()

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

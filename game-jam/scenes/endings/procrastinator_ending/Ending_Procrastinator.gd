extends Control

func _ready():
	print("Procrastinator Ending loaded")

	var music = get_node_or_null("/root/MusicManager")
	if music:
		music.stop_music()

	# Start fully black, then fade in
	modulate = Color(0, 0, 0, 1)
	var fade_in = create_tween()
	fade_in.tween_property(self, "modulate", Color(1, 1, 1, 1), 1.5)
	fade_in.tween_callback(_reveal_text)

func _reveal_text():
	var text_label = get_node_or_null("TextLabel")
	var phone_label = get_node_or_null("PhoneLabel")
	var flavor_label = get_node_or_null("FlavorLabel")

	if text_label:
		text_label.show()
		text_label.modulate.a = 0.0
		var t = create_tween()
		t.tween_property(text_label, "modulate:a", 1.0, 1.2)

	if phone_label:
		var t2 = create_tween()
		t2.tween_interval(1.4)
		t2.tween_callback(func():
			phone_label.show()
			phone_label.modulate.a = 0.0
			var t3 = create_tween()
			t3.tween_property(phone_label, "modulate:a", 1.0, 1.0)
		)

	if flavor_label:
		var t4 = create_tween()
		t4.tween_interval(2.8)
		t4.tween_callback(func():
			flavor_label.show()
			flavor_label.modulate.a = 0.0
			var t5 = create_tween()
			t5.tween_property(flavor_label, "modulate:a", 1.0, 1.0)
			t5.tween_callback(_show_main_menu_button)
		)
	else:
		var t6 = create_tween()
		t6.tween_interval(2.8)
		t6.tween_callback(_show_main_menu_button)

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
	btn.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(btn, "modulate:a", 1.0, 0.6)
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
	btn.grab_focus()

extends Control

func _ready():
	get_tree().paused = false
	var music = get_node_or_null("/root/MusicManager")
	if music:
		music.stop_music()
	
	for child in get_children():
		child.hide()

	_build_ui(
		"res://assets/endings/bad.png",
		"DRUNK MISTAKE",
		"Everything went fuzzy.\n\nYou woke up at 3:00 AM on the office sofa.\nThe deadline had passed.\n\nYou failed."
	)

func _build_ui(image_path: String, title: String, body: String) -> void:
	# Black background
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Image — full screen
	var img = TextureRect.new()
	img.texture = load(image_path)
	img.layout_mode = 1
	img.anchor_left = 0.0
	img.anchor_top = 0.0
	img.anchor_right = 1.0
	img.anchor_bottom = 1.0
	img.offset_left = 0; img.offset_top = 0; img.offset_right = 0; img.offset_bottom = 0
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(img)

	# Text background overlay for readability
	var overlay = ColorRect.new()
	overlay.layout_mode = 1
	overlay.anchor_left = 0.5
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# Right panel
	var panel = VBoxContainer.new()
	panel.layout_mode = 1
	panel.anchor_left = 0.55
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0; panel.offset_top = 0; panel.offset_right = -40; panel.offset_bottom = 0
	panel.add_theme_constant_override("separation", 24)
	add_child(panel)

	# Spacer top
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 80)
	spacer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_child(spacer)

	# Title
	var t = Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 36)
	t.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(t)

	# Body
	var b = Label.new()
	b.text = body
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(b)

	# Main Menu button — bottom right
	var btn = Button.new()
	btn.text = "Main Menu"
	btn.add_theme_font_size_override("font_size", 22)
	btn.custom_minimum_size = Vector2(200, 50)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.add_child(btn)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 40)
	panel.add_child(spacer2)

	btn.grab_focus()
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))

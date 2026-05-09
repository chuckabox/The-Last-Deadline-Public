extends CanvasLayer

var is_paused = false

func _ready():
	add_child(create_pause_ui())
	hide()

func _input(event):
	if event.is_action_pressed("ui_cancel") and not get_tree().paused:
		get_tree().root.set_input_as_handled()
		pause()
	elif event.is_action_pressed("ui_cancel") and get_tree().paused:
		get_tree().root.set_input_as_handled()
		resume()

func pause():
	is_paused = true
	show()
	get_tree().paused = true

func resume():
	is_paused = false
	hide()
	get_tree().paused = false

func create_pause_ui() -> Control:
	var container = Control.new()
	container.anchors_left = 0.0
	container.anchors_top = 0.0
	container.anchors_right = 1.0
	container.anchors_bottom = 1.0

	var overlay = ColorRect.new()
	overlay.anchors_left = 0.0
	overlay.anchors_top = 0.0
	overlay.anchors_right = 1.0
	overlay.anchors_bottom = 1.0
	overlay.color = Color(0, 0, 0, 0.6)
	container.add_child(overlay)

	var panel = PanelContainer.new()
	panel.anchors_left = 0.5
	panel.anchors_top = 0.5
	panel.anchors_right = 0.5
	panel.anchors_bottom = 0.5
	panel.offset_left = -200
	panel.offset_top = -120
	panel.offset_right = 200
	panel.offset_bottom = 120
	container.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer1)

	var resume_btn = Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(200, 50)
	resume_btn.pressed.connect(_on_resume)
	vbox.add_child(resume_btn)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)

	var menu_btn = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(200, 50)
	menu_btn.pressed.connect(_on_main_menu)
	vbox.add_child(menu_btn)

	return container

func _on_resume():
	resume()

func _on_main_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

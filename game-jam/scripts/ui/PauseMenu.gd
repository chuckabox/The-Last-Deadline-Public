extends Control

var is_paused = false

@onready var resume_button = $PausePanel/VBoxContainer/ResumeButton
@onready var main_menu_button = $PausePanel/VBoxContainer/MainMenuButton
@onready var pause_panel = $PausePanel

func _ready():
	hide()
	resume_button.pressed.connect(_on_resume_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().root.set_input_as_handled()
		if is_paused:
			resume()
		else:
			pause()

func pause():
	is_paused = true
	show()
	get_tree().paused = true
	resume_button.grab_focus()

func resume():
	is_paused = false
	hide()
	get_tree().paused = false

func _on_resume_pressed():
	resume()

func _on_main_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

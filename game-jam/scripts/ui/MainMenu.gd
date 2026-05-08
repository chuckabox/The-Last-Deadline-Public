extends Control

# References
var music_manager: Node
var sfx_manager: Node

# UI Nodes
@onready var start_button = $MenuContainer/StartButton
@onready var quit_button = $MenuContainer/QuitButton
@onready var title_label = $Title

func _ready():
	# Get system references safely
	music_manager = get_node_or_null("/root/MusicManager")
	sfx_manager = get_node_or_null("/root/SFXManager")
	
	# Play chill music (Stage 0)
	if music_manager:
		music_manager.play_music_for_stage(0)
	
	# Focus the first button for keyboard/gamepad navigation
	if start_button:
		start_button.grab_focus()
	
	# Connect signals to existing functions
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
		start_button.focus_entered.connect(_on_button_hover)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
		quit_button.focus_entered.connect(_on_button_hover)

func _process(delta):
	# Add a slight neon flicker effect to the title
	if title_label:
		var flicker = 0.8 + randf() * 0.2
		title_label.modulate.a = flicker

func _on_start_pressed():
	if sfx_manager:
		sfx_manager.play_sfx("menu_select")
	
	# Transition to the main game room
	var transition_manager = get_node_or_null("/root/RoomTransitionManager")
	if transition_manager:
		transition_manager.change_room("bar")
	else:
		get_tree().change_scene_to_file("res://scenes/rooms/room_1_bar.tscn")

func _on_quit_pressed():
	if sfx_manager:
		sfx_manager.play_sfx("menu_select")
	
	# Small delay for the sound to play
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func _on_button_hover():
	if sfx_manager:
		sfx_manager.play_sfx("menu_scroll")

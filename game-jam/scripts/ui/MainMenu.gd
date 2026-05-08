extends Control

# References
var music_manager: Node
var sfx_manager: Node

# UI Nodes
@onready var start_button = $MenuContainer/StartButton
@onready var quit_button = $MenuContainer/QuitButton
@onready var title_label = $Title
@onready var subtitle_label = $Title/Subtitle
@onready var menu_container = $MenuContainer

func _ready():
	# Get system references safely
	music_manager = get_node_or_null("/root/MusicManager")
	sfx_manager = get_node_or_null("/root/SFXManager")
	
	# Play chill music (Stage 0)
	if music_manager:
		music_manager.play_music_for_stage(0)
	
	# Focus the first button
	if start_button:
		start_button.grab_focus()
	
	# Connect signals
	start_button.pressed.connect(_on_start_pressed)
	start_button.focus_entered.connect(_on_button_hover)
	start_button.mouse_entered.connect(_on_button_hover)
	
	quit_button.pressed.connect(_on_quit_pressed)
	quit_button.focus_entered.connect(_on_button_hover)
	quit_button.mouse_entered.connect(_on_button_hover)
	
	# Entry Animation (Safe version: starts from visible and tweens properties)
	# We don't set modulate to 0 here just in case, we do it in the tween setup
	_run_entry_animation()

func _run_entry_animation():
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Fade in from 0
	title_label.modulate.a = 0
	subtitle_label.modulate.a = 0
	menu_container.modulate.a = 0
	var original_menu_y = menu_container.position.y
	menu_container.position.y += 30
	
	tween.tween_property(title_label, "modulate:a", 1.0, 1.0)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 1.0).set_delay(0.3)
	tween.tween_property(menu_container, "modulate:a", 1.0, 0.8).set_delay(0.6)
	tween.tween_property(menu_container, "position:y", original_menu_y, 0.8).set_delay(0.6)

func _process(_delta):
	# Subtle neon flicker
	if title_label and randf() > 0.98:
		title_label.modulate.a = 0.7 + randf() * 0.3
	elif title_label:
		title_label.modulate.a = lerp(title_label.modulate.a, 1.0, 0.1)

func _on_start_pressed():
	_play_select_sfx()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	get_tree().change_scene_to_file("res://bar.tscn")

func _on_quit_pressed():
	_play_select_sfx()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	get_tree().quit()

func _on_button_hover():
	if sfx_manager:
		sfx_manager.play_sfx("menu_scroll")
	
	var focused = get_viewport().gui_get_focus_owner()
	if focused is Button and focused.get_parent() == menu_container:
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(focused, "scale", Vector2(1.1, 1.1), 0.2)
		
		for btn in menu_container.get_children():
			if btn != focused:
				create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)

func _play_select_sfx():
	if sfx_manager:
		sfx_manager.play_sfx("menu_select")

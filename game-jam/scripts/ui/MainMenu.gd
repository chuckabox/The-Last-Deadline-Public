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
@onready var menu_camera = $MenuCamera
@onready var fade_overlay = $FadeOverlay

func _ready():
	# Ensure the dedicated menu camera is active
	if menu_camera:
		menu_camera.make_current()
	
	# Get system references safely
	music_manager = get_node_or_null("/root/MusicManager")
	sfx_manager = get_node_or_null("/root/SFXManager")
	
	# Play chill music (Stage 0)
	if music_manager:
		music_manager.play_music_for_stage(0)
	
	# Focus the first button
	if start_button:
		start_button.grab_focus()
		start_button.pivot_offset = start_button.size / 2.0
		start_button.resized.connect(func(): start_button.pivot_offset = start_button.size / 2.0)
	
	if quit_button:
		quit_button.pivot_offset = quit_button.size / 2.0
		quit_button.resized.connect(func(): quit_button.pivot_offset = quit_button.size / 2.0)
	
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
	
	# Initial states: transparent and slightly offset
	title_label.modulate.a = 0
	subtitle_label.modulate.a = 0
	menu_container.modulate.a = 0
	
	var original_title_y = title_label.position.y
	var original_menu_y = menu_container.position.y
	
	title_label.position.y -= 20
	menu_container.position.y += 20
	
	# Staggered entry
	tween.tween_property(title_label, "modulate:a", 1.0, 1.2)
	tween.tween_property(title_label, "position:y", original_title_y, 1.2)
	
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 1.0).set_delay(0.5)
	
	tween.tween_property(menu_container, "modulate:a", 1.0, 0.8).set_delay(1.0)
	tween.tween_property(menu_container, "position:y", original_menu_y, 0.8).set_delay(1.0)

func _process(_delta):
	# Subtle neon flicker
	if title_label and randf() > 0.98:
		title_label.modulate.a = 0.7 + randf() * 0.3
	elif title_label:
		title_label.modulate.a = lerp(title_label.modulate.a, 1.0, 0.1)

func _on_start_pressed():
	_play_select_sfx()
	_launch_game()

func _launch_game() -> void:
	# 1. Fade to black first
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.modulate.a = 0.0
		var fade_in = create_tween()
		fade_in.tween_property(fade_overlay, "modulate:a", 1.0, 0.5)
		await fade_in.finished
	
	# 2. Hold the full black screen for 1 second while we load the world in the background
	# This ensures any stuttering or camera snaps happen while it's completely black.
	await get_tree().create_timer(1.0).timeout
	
	# Swap MainMenu out of Main/CurrentScene for the bar room + intro cutscene
	var current_scene_node := get_tree().root.get_node_or_null("Main/CurrentScene")
	if current_scene_node == null:
		push_error("MainMenu: /root/Main/CurrentScene not found.")
		get_tree().change_scene_to_file("res://scenes/rooms/room_1_bar.tscn")
		return

	var hud := get_tree().root.get_node_or_null("Main/HUD")
	if hud and hud.has_method("fade_in"):
		hud.fade_in(1.5)
	elif hud:
		hud.visible = true

	# Instantiate bar
	var bar_scene: PackedScene = load("res://scenes/rooms/room_1_bar.tscn")
	if bar_scene:
		var bar_instance = bar_scene.instantiate()
		current_scene_node.add_child(bar_instance)
		current_scene_node.move_child(bar_instance, 0)

	# Instantiate intro cutscene (it starts black and fades in automatically)
	var intro_scene: PackedScene = load("res://scenes/ui/IntroCutscene.tscn")
	if intro_scene:
		var intro_instance = intro_scene.instantiate()
		current_scene_node.add_child(intro_instance)
		current_scene_node.move_child(intro_instance, 1)

	# 3. Clean up the menu; the intro cutscene's own fade logic will now take over
	queue_free()

func _on_quit_pressed():
	if sfx_manager:
		sfx_manager.play_sfx("menu_cancel")
	# Just quit immediately to avoid revealing the grey background during a fade
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

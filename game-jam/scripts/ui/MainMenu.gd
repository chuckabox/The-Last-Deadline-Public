extends Control

# References
var music_manager: Node
var sfx_manager: Node

# UI Nodes
@onready var start_button = $UILayer/MenuContainer/StartButton
@onready var endings_button = $UILayer/MenuContainer/EndingsButton
@onready var quit_button = $UILayer/MenuContainer/QuitButton
@onready var title_label = $UILayer/Title
@onready var subtitle_label = $UILayer/Title/Subtitle
@onready var menu_container = $UILayer/MenuContainer
@onready var menu_camera = $World/MenuCamera
@onready var fade_overlay = $UILayer/FadeOverlay
@onready var gallery_panel = $UILayer/GalleryPanel
@onready var grid_container = $UILayer/GalleryPanel/ScrollContainer/GridContainer
@onready var back_button = $UILayer/GalleryPanel/BackButton

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
	
	endings_button.pressed.connect(_on_endings_pressed)
	endings_button.focus_entered.connect(_on_button_hover)
	endings_button.mouse_entered.connect(_on_button_hover)
	
	quit_button.pressed.connect(_on_quit_pressed)
	quit_button.focus_entered.connect(_on_button_hover)
	quit_button.mouse_entered.connect(_on_button_hover)
	
	back_button.pressed.connect(_on_back_pressed)
	
	# Credits setup
	var credits_btn = get_node_or_null("UILayer/CreditsButton")
	if credits_btn:
		credits_btn.pressed.connect(_on_credits_pressed)
		credits_btn.mouse_entered.connect(_on_btn_hover.bind(credits_btn))
		credits_btn.mouse_exited.connect(_on_btn_exit.bind(credits_btn))

	var credits_back = get_node_or_null("UILayer/CreditsPanel/CreditsBackButton")
	if credits_back:
		credits_back.pressed.connect(_on_credits_back_pressed)
		credits_back.mouse_entered.connect(_on_btn_hover.bind(credits_back))
		credits_back.mouse_exited.connect(_on_btn_exit.bind(credits_back))
		
	var credits_content = get_node_or_null("UILayer/CreditsPanel/CreditsContent")
	if credits_content:
		credits_content.meta_clicked.connect(_on_credits_link_clicked)
	
	# Developers setup
	var dev_btn = get_node_or_null("UILayer/DevelopersButton")
	if dev_btn:
		dev_btn.pressed.connect(_on_developers_pressed)
		dev_btn.mouse_entered.connect(_on_btn_hover.bind(dev_btn))
		dev_btn.mouse_exited.connect(_on_btn_exit.bind(dev_btn))

	var dev_back = get_node_or_null("UILayer/DevelopersPanel/DevBackButton")
	if dev_back:
		dev_back.pressed.connect(_on_developers_back_pressed)
		dev_back.mouse_entered.connect(_on_btn_hover.bind(dev_back))
		dev_back.mouse_exited.connect(_on_btn_exit.bind(dev_back))
		
	var dev_content = get_node_or_null("UILayer/DevelopersPanel/DevContent")
	if dev_content:
		dev_content.meta_clicked.connect(_on_credits_link_clicked) # Reuse the same link handler
	
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

func _on_endings_pressed():
	_play_select_sfx()
	_populate_gallery()
	gallery_panel.show()
	back_button.grab_focus()

func _on_back_pressed():
	if sfx_manager:
		sfx_manager.play_sfx("menu_cancel")
	gallery_panel.hide()
	endings_button.grab_focus()

func _populate_gallery():
	# Clear previous entries
	for child in grid_container.get_children():
		child.queue_free()
	
	var endings = [
		{"name": "Academic Weapon", "path": "res://assets/endings/academic_weapon.png"},
		{"name": "The Blackout", "path": "res://assets/endings/blackout.png"},
		{"name": "The Procrastinator", "path": "res://assets/endings/the_procastinator.jpg"},
		{"name": "The Job Offer", "path": "res://assets/endings/job.png"},
		{"name": "Drunk Mistake", "path": "res://assets/endings/bad.png"}
	]
	
	for ending in endings:
		var item = VBoxContainer.new()
		item.custom_minimum_size = Vector2(300, 190)
		
		var tex_rect = TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(280, 140)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		
		if FileAccess.file_exists(ending["path"]):
			tex_rect.texture = load(ending["path"])
		
		var label = Label.new()
		label.text = ending["name"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", load("res://assets/fonts/monogram.ttf"))
		label.add_theme_font_size_override("font_size", 24)
		
		item.add_child(tex_rect)
		item.add_child(label)
		grid_container.add_child(item)

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
	# Only play sound and animate if the menu is actually visible
	if menu_container.modulate.a < 0.5:
		return
		
	if sfx_manager:
		sfx_manager.play_sfx("menu_scroll")

	var focused = get_viewport().gui_get_focus_owner()
	if focused is Button and focused.get_parent() == menu_container:
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(focused, "scale", Vector2(1.1, 1.1), 0.2)

		# Scale the text label inside the button
		var label = focused.get_node_or_null("Label")
		if label:
			tween.tween_property(label, "scale", Vector2(1.1, 1.1), 0.2)

		for btn in menu_container.get_children():
			if btn != focused:
				var btn_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				btn_tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)
				var btn_label = btn.get_node_or_null("Label")
				if btn_label:
					btn_tween.tween_property(btn_label, "scale", Vector2(1.0, 1.0), 0.2)

func _play_select_sfx():
	if sfx_manager:
		sfx_manager.play_sfx("menu_select")

func _on_credits_pressed():
	_play_select_sfx()
	var credits_panel = get_node_or_null("UILayer/CreditsPanel")
	if credits_panel:
		credits_panel.show()
		credits_panel.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(credits_panel, "modulate:a", 1.0, 0.3)

func _on_credits_back_pressed():
	_play_select_sfx()
	var credits_panel = get_node_or_null("UILayer/CreditsPanel")
	if credits_panel:
		var tween = create_tween()
		tween.tween_property(credits_panel, "modulate:a", 0.0, 0.2)
		tween.tween_callback(credits_panel.hide)

func _on_credits_link_clicked(meta):
	OS.shell_open(str(meta))

func _on_developers_pressed():
	_play_select_sfx()
	var dev_panel = get_node_or_null("UILayer/DevelopersPanel")
	if dev_panel:
		dev_panel.show()
		dev_panel.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(dev_panel, "modulate:a", 1.0, 0.3)

func _on_developers_back_pressed():
	_play_select_sfx()
	var dev_panel = get_node_or_null("UILayer/DevelopersPanel")
	if dev_panel:
		var tween = create_tween()
		tween.tween_property(dev_panel, "modulate:a", 0.0, 0.2)
		tween.tween_callback(dev_panel.hide)

func _on_btn_hover(btn: Button):
	if sfx_manager: sfx_manager.play_sfx("menu_scroll")
	btn.pivot_offset = btn.size / 2.0
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.2)

func _on_btn_exit(btn: Button):
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)

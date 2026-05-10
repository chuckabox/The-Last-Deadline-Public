extends CanvasLayer

## Pause Menu
## Toggled by pressing Escape. Pauses the game timer and freezes the player.
## Styled to match the MainMenu aesthetic (monogram font, golden title, blur overlay).

var is_paused: bool = false

# References
var time_manager: Node
var sfx_manager: Node

# UI nodes (built in code to avoid .tscn merge conflicts)
var blur_overlay: ColorRect
var title_label: Label
var menu_container: VBoxContainer
var resume_button: Button
var quit_button: Button

func _ready() -> void:
	layer = 100  # Render above everything
	time_manager = get_node_or_null("/root/TimeManager")
	sfx_manager = get_node_or_null("/root/SFXManager")
	_build_ui()
	hide()

func _build_ui() -> void:
	# --- Blur/Dim overlay ---
	blur_overlay = ColorRect.new()
	blur_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur_overlay.color = Color(0, 0, 0.05, 0.75)
	blur_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks through
	# Apply blur shader matching MainMenu style
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
	uniform float blur_amount : hint_range(0.0, 5.0) = 3.0;
	uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.05, 0.6);

	void fragment() {
		vec4 color = textureLod(screen_texture, SCREEN_UV, blur_amount);
		COLOR = mix(color, tint, tint.a);
	}"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("blur_amount", 3.0)
	mat.set_shader_parameter("tint", Color(0, 0, 0.05, 0.6))
	blur_overlay.material = mat
	add_child(blur_overlay)

	# --- Title ---
	title_label = Label.new()
	title_label.text = "PAUSED"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_label.offset_left = -300
	title_label.offset_right = 300
	title_label.offset_top = 150
	title_label.offset_bottom = 250
	# Style: golden text matching MainMenu
	title_label.add_theme_color_override("font_color", Color(1, 0.84, 0, 1))
	title_label.add_theme_color_override("font_shadow_color", Color(0.2, 0.1, 0, 0.5))
	title_label.add_theme_constant_override("shadow_offset_x", 4)
	title_label.add_theme_constant_override("shadow_offset_y", 4)
	title_label.add_theme_constant_override("shadow_outline_size", 10)
	var font = load("res://assets/fonts/monogram.ttf")
	if font:
		title_label.add_theme_font_override("font", font)
	title_label.add_theme_font_size_override("font_size", 80)
	add_child(title_label)

	# --- Button container ---
	menu_container = VBoxContainer.new()
	menu_container.set_anchors_preset(Control.PRESET_CENTER)
	menu_container.offset_left = -150
	menu_container.offset_right = 150
	menu_container.offset_top = 0
	menu_container.offset_bottom = 150
	menu_container.add_theme_constant_override("separation", 25)
	menu_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(menu_container)

	# Load button textures from MainMenu assets
	var btn_normal_tex = load("res://assets/ui/Complete_UI_Essential_Pack_Free/01_Flat_Theme/Sprites/UI_Flat_Button01a_3.png")
	var btn_hover_tex = load("res://assets/ui/Complete_UI_Essential_Pack_Free/01_Flat_Theme/Sprites/UI_Flat_Button01a_4.png")

	# --- Resume Button ---
	resume_button = _create_button("RESUME", btn_normal_tex, btn_hover_tex, font)
	resume_button.pressed.connect(_on_resume_pressed)
	menu_container.add_child(resume_button)

	# --- Quit Button ---
	quit_button = _create_button("QUIT TO DESKTOP", btn_normal_tex, btn_hover_tex, font)
	quit_button.pressed.connect(_on_quit_pressed)
	menu_container.add_child(quit_button)

func _create_button(text: String, normal_tex: Texture2D, hover_tex: Texture2D, btn_font: Font) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 60)

	# Text style
	btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
	btn.add_theme_color_override("font_focus_color", Color(0, 0, 0, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 1))
	btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 1))
	if btn_font:
		btn.add_theme_font_override("font", btn_font)
	btn.add_theme_font_size_override("font_size", 32)

	# StyleBox from textures (matching MainMenu)
	if normal_tex:
		var style_normal = StyleBoxTexture.new()
		style_normal.texture = normal_tex
		style_normal.texture_margin_left = 6
		style_normal.texture_margin_top = 6
		style_normal.texture_margin_right = 6
		style_normal.texture_margin_bottom = 6
		style_normal.expand_margin_left = 10
		style_normal.expand_margin_right = 10
		btn.add_theme_stylebox_override("normal", style_normal)

	if hover_tex:
		var style_hover = StyleBoxTexture.new()
		style_hover.texture = hover_tex
		style_hover.texture_margin_left = 6
		style_hover.texture_margin_top = 6
		style_hover.texture_margin_right = 6
		style_hover.texture_margin_bottom = 6
		style_hover.expand_margin_left = 15
		style_hover.expand_margin_right = 15
		btn.add_theme_stylebox_override("pressed", style_hover)
		btn.add_theme_stylebox_override("hover", style_hover)

	# Remove default focus rectangle
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	# Hover animation
	btn.pivot_offset = btn.custom_minimum_size / 2.0
	btn.focus_entered.connect(_on_button_hover)
	btn.mouse_entered.connect(_on_button_hover)

	return btn

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if is_paused:
		_resume()
	else:
		_pause()

func _pause() -> void:
	is_paused = true
	show()

	# Pause the game timer
	if time_manager and time_manager.has_method("pause_time"):
		time_manager.pause_time()

	# Freeze player movement
	var player = get_tree().get_first_node_in_group("player")
	if player and "can_move" in player:
		player.can_move = false

	# Pause the scene tree (physics, animations, etc.)
	get_tree().paused = true
	# But keep THIS layer processing so buttons work
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Focus the resume button
	resume_button.grab_focus()

	# Entry animation
	blur_overlay.modulate.a = 0.0
	title_label.modulate.a = 0.0
	menu_container.modulate.a = 0.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(blur_overlay, "modulate:a", 1.0, 0.2)
	tween.tween_property(title_label, "modulate:a", 1.0, 0.3).set_delay(0.1)
	tween.tween_property(menu_container, "modulate:a", 1.0, 0.3).set_delay(0.15)

	if sfx_manager and sfx_manager.has_method("play_sfx"):
		sfx_manager.play_sfx("ui_popup_open")

func _resume() -> void:
	is_paused = false

	# Unpause the scene tree
	get_tree().paused = false

	# Resume the game timer
	if time_manager and time_manager.has_method("resume_time"):
		time_manager.resume_time()

	# Unfreeze player movement
	var player = get_tree().get_first_node_in_group("player")
	if player and "can_move" in player:
		player.can_move = true

	hide()

	if sfx_manager and sfx_manager.has_method("play_sfx"):
		sfx_manager.play_sfx("ui_popup_close")

func _on_resume_pressed() -> void:
	if sfx_manager and sfx_manager.has_method("play_sfx"):
		sfx_manager.play_sfx("menu_select")
	_resume()

func _on_quit_pressed() -> void:
	if sfx_manager and sfx_manager.has_method("play_sfx"):
		sfx_manager.play_sfx("menu_cancel")
	get_tree().paused = false
	get_tree().quit()

func _on_button_hover() -> void:
	if sfx_manager and sfx_manager.has_method("play_sfx"):
		sfx_manager.play_sfx("menu_scroll")

	var focused = get_viewport().gui_get_focus_owner()
	if focused is Button and focused.get_parent() == menu_container:
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(focused, "scale", Vector2(1.1, 1.1), 0.2)

		for btn in menu_container.get_children():
			if btn != focused:
				create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)

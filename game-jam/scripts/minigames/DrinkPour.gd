extends Control

# Tutorial State
var tutorial_active = true
var tutorial_overlay: ColorRect

# Round / Lives State
var current_round = 1
var total_rounds = 3
var lives = 3
var is_pouring = false
var has_poured = false
var round_active = false

# Pour State
var liquid_level = 0.0
var target_line_position = 0.5

# Parameters
var target_line_speed = 1.0
var target_line_direction = 1.0
var tolerance = 0.15
var difficulty_stage = 0

# Difficulty effect state
var wobble_timer = 0.0
var direction_change_cooldown = 0.0
var camera_osc_timer = 0.0
var glass_base_pos: Vector2
var invisible_timer = 0.0
var is_invisible_pulse = false
var vignette_layer: CanvasLayer

# Glass configs per round: width, height, color, label
const ROUND_GLASS_CONFIGS = [
	{"w": 160.0, "h": 320.0, "color": Color(0.8, 0.9, 1.0, 0.15),  "label": "PINT"},
	{"w": 220.0, "h": 240.0, "color": Color(0.9, 0.85, 1.0, 0.15), "label": "TUMBLER"},
	{"w": 100.0, "h": 360.0, "color": Color(0.8, 1.0, 0.85, 0.15), "label": "FLUTE"},
]

const ROUND_LIQUID_COLORS = [
	Color(0.9, 0.6, 0.1, 0.85),
	Color(0.3, 0.15, 0.6, 0.85),
	Color(0.9, 0.9, 0.95, 0.85),
]

const ROUND_DRINK_NAMES = ["PINT", "COCKTAIL", "CHAMPAGNE"]

# References
var glass: ColorRect
var liquid: ColorRect
var target_line: Line2D
var bubbles: CPUParticles2D
var glass_label: Label
var pour_stream: ColorRect
var instruction_label: Label
var feedback_label: Label
var victory_label: Label
var pour_indicator: Label
var round_label: Label
var drink_type_label: Label
var lives_label: Label
var confetti: CPUParticles2D
var alcohol_system: Node
var sfx_manager: Node
var game_manager: Node

signal minigame_won(cash_reward)
signal minigame_lost()

func _ready():
	glass = get_node_or_null("Glass")
	if glass:
		liquid = glass.get_node_or_null("Liquid")
		target_line = glass.get_node_or_null("TargetLine")
		bubbles = glass.get_node_or_null("Bubbles")
		glass_label = glass.get_node_or_null("GlassLabel")

	pour_stream = get_node_or_null("PourStream")
	instruction_label = get_node_or_null("InstructionLabel")
	feedback_label = get_node_or_null("FeedbackLabel")
	victory_label = get_node_or_null("VictoryLabel")
	pour_indicator = get_node_or_null("PourIndicator")
	round_label = get_node_or_null("RoundLabel")
	drink_type_label = get_node_or_null("DrinkTypeLabel")
	lives_label = get_node_or_null("LivesLabel")
	confetti = get_node_or_null("Confetti")
	tutorial_overlay = get_node_or_null("TutorialOverlay")

	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	sfx_manager = get_node_or_null("/root/SFXManager")
	game_manager = get_node_or_null("/root/GameManager")

	if alcohol_system and "current_stage" in alcohol_system:
		difficulty_stage = alcohol_system.current_stage

	if difficulty_stage >= 2:
		_add_vignette()

	# Show tutorial first, don't start round yet
	tutorial_active = true
	if tutorial_overlay:
		tutorial_overlay.show()

	# Pulse the start prompt
	var start_prompt = get_node_or_null("TutorialOverlay/TutorialPanel/StartPrompt")
	if start_prompt:
		var tween = create_tween().set_loops()
		tween.tween_property(start_prompt, "modulate:a", 0.2, 0.6)
		tween.tween_property(start_prompt, "modulate:a", 1.0, 0.6)

	print("Drink Pour started — Stage: %d" % difficulty_stage)

func _input(event):
	# Dismiss tutorial on any key press
	if tutorial_active:
		if event is InputEventKey and event.pressed and not event.echo:
			_dismiss_tutorial()
		return

	if not round_active:
		return

	if event.is_action_pressed("ui_select"):
		is_pouring = true
		_show_pour_indicator(true)
		if pour_stream:
			pour_stream.show()
		if bubbles and liquid_level > 0.05:
			bubbles.emitting = true
		if sfx_manager:
			sfx_manager.play_sfx("liquid_pour_loop")

	elif event.is_action_released("ui_select"):
		if is_pouring:
			is_pouring = false
			_show_pour_indicator(false)
			if pour_stream:
				pour_stream.hide()
			if bubbles:
				bubbles.emitting = false
			check_accuracy()

func _dismiss_tutorial():
	tutorial_active = false
	if tutorial_overlay:
		var tween = create_tween()
		tween.tween_property(tutorial_overlay, "modulate:a", 0.0, 0.3)
		tween.tween_callback(tutorial_overlay.hide)
	start_round()

func start_round():
	liquid_level = 0.0
	is_pouring = false
	has_poured = false
	round_active = true
	wobble_timer = 0.0
	camera_osc_timer = 0.0
	invisible_timer = 0.0
	is_invisible_pulse = false
	rotation_degrees = 0.0

	if target_line:
		target_line.modulate.a = 1.0
	if liquid:
		liquid.modulate.a = 1.0
	if pour_stream:
		pour_stream.hide()

	# Apply glass config for this round
	var config = ROUND_GLASS_CONFIGS[current_round - 1]
	var w = config["w"]
	var h = config["h"]

	if glass:
		glass.size = Vector2(w, h)
		glass.position = Vector2(576 - w / 2.0, 324 - h / 2.0)
		glass.color = config["color"]
		glass_base_pos = glass.position

	if liquid:
		liquid.color = ROUND_LIQUID_COLORS[current_round - 1]
		liquid.size = Vector2(w, 0)
		liquid.position = Vector2(0, h)

	if target_line:
		target_line.set_point_position(0, Vector2(0, h / 2.0))
		target_line.set_point_position(1, Vector2(w, h / 2.0))

	if pour_stream:
		pour_stream.color = ROUND_LIQUID_COLORS[current_round - 1]
		pour_stream.size.x = 12

	if glass_label:
		glass_label.text = config["label"]
		glass_label.size.x = w

	if bubbles:
		bubbles.position = Vector2(w / 2.0, h)
		bubbles.emitting = false

	# Speed and tolerance increase per round
	var round_speed_bonus = (current_round - 1) * 0.3
	target_line_speed = _base_speed() + round_speed_bonus
	tolerance = max(0.05, _base_tolerance() - (current_round - 1) * 0.02)

	update_ui()
	update_liquid_visual()

	if feedback_label:
		feedback_label.hide()
	if victory_label:
		victory_label.hide()

func _base_speed() -> float:
	match difficulty_stage:
		0: return 1.0
		1: return 1.5
		2: return 2.0
		3: return 2.5
		4: return 3.5
	return 1.0

func _base_tolerance() -> float:
	match difficulty_stage:
		0: return 0.15
		1: return 0.12
		2: return 0.10
		3: return 0.08
		4: return 0.05
	return 0.15

func _physics_process(delta):
	if tutorial_active or not round_active:
		return

	# Oscillate target line
	target_line_position = 0.5 + sin(Time.get_ticks_msec() * 0.001 * target_line_speed * 2.0) * 0.35

	# Stage 2+: Sudden direction changes
	if difficulty_stage >= 2:
		direction_change_cooldown -= delta
		if direction_change_cooldown <= 0 and randf() < 0.02:
			target_line_direction *= -1.0
			direction_change_cooldown = 0.8
		target_line_position = 0.5 + sin(Time.get_ticks_msec() * 0.001 * target_line_speed * 2.0 * target_line_direction) * 0.35

	update_target_line()

	# Stage 3: Camera oscillation + glass drift
	if difficulty_stage >= 3:
		camera_osc_timer += delta
		rotation_degrees = sin(camera_osc_timer * 2.5) * 4.0
		if glass:
			var shift = sin(camera_osc_timer * 1.8) * 15.0
			glass.position.x = glass_base_pos.x + shift

	# Stage 4: Invisible pulses
	if difficulty_stage >= 4:
		invisible_timer -= delta
		if invisible_timer <= 0:
			is_invisible_pulse = not is_invisible_pulse
			invisible_timer = randf_range(0.5, 1.0)
			if target_line:
				target_line.modulate.a = 0.0 if is_invisible_pulse else 1.0
			if liquid:
				liquid.modulate.a = 0.0 if is_invisible_pulse else 1.0

	# Pouring
	if is_pouring:
		var pour_speed = 0.35
		if difficulty_stage >= 1:
			wobble_timer += delta
			pour_speed += sin(wobble_timer * 8.0) * 0.08
		liquid_level = min(1.0, liquid_level + pour_speed * delta)
		update_liquid_visual()
		_update_pour_stream()

		# Overflow — auto fail
		if liquid_level >= 1.0:
			is_pouring = false
			_show_pour_indicator(false)
			if pour_stream:
				pour_stream.hide()
			if bubbles:
				bubbles.emitting = false
			check_accuracy()

func update_target_line():
	if not glass or not target_line:
		return
	var config = ROUND_GLASS_CONFIGS[current_round - 1]
	var line_y = config["h"] * (1.0 - target_line_position)
	target_line.set_point_position(0, Vector2(0, line_y))
	target_line.set_point_position(1, Vector2(config["w"], line_y))

func update_liquid_visual():
	if not glass or not liquid:
		return
	var config = ROUND_GLASS_CONFIGS[current_round - 1]
	liquid.size.y = config["h"] * liquid_level
	liquid.position.y = config["h"] * (1.0 - liquid_level)
	if bubbles:
		bubbles.position.y = config["h"] * (1.0 - liquid_level)

func _update_pour_stream():
	if not pour_stream or not glass:
		return
	var config = ROUND_GLASS_CONFIGS[current_round - 1]
	var glass_top_y = glass.position.y
	var liquid_surface_y = glass.position.y + config["h"] * (1.0 - liquid_level)
	var stream_x = glass.position.x + config["w"] / 2.0 - 6.0
	var stream_start_y = glass_top_y - 120.0
	pour_stream.position = Vector2(stream_x, stream_start_y)
	pour_stream.size.y = max(0, liquid_surface_y - stream_start_y)

func _show_pour_indicator(pouring: bool):
	if not pour_indicator:
		return
	var tween = create_tween()
	tween.tween_property(pour_indicator, "modulate:a", 1.0 if pouring else 0.0, 0.1)

func check_accuracy():
	round_active = false
	has_poured = true

	var difference = abs(liquid_level - target_line_position)
	var success = difference < tolerance
	var accuracy_percent = max(0, (1.0 - (difference / (tolerance * 2.0))) * 100)

	if success:
		if sfx_manager:
			sfx_manager.play_sfx("sequence_correct")

		# Flash liquid gold briefly
		if liquid:
			var tween = create_tween()
			tween.tween_property(liquid, "color", Color(1.0, 0.9, 0.2, 1.0), 0.15)
			tween.tween_property(liquid, "color", ROUND_LIQUID_COLORS[current_round - 1], 0.3)

		if feedback_label:
			feedback_label.show()
			feedback_label.text = "✓ Nice Pour!  %.0f%%" % accuracy_percent
			feedback_label.add_theme_color_override("font_color", Color.GREEN)

		await get_tree().create_timer(0.8).timeout
		next_round()
	else:
		lives -= 1
		if sfx_manager:
			sfx_manager.play_sfx("spill_splash")
		if alcohol_system and alcohol_system.has_method("drink_alcohol"):
			alcohol_system.drink_alcohol(0.2)

		if feedback_label:
			feedback_label.show()
			feedback_label.text = "✗ Too far off!  %.0f%%" % accuracy_percent
			feedback_label.add_theme_color_override("font_color", Color.RED)

		update_ui()

		if lives <= 0:
			await get_tree().create_timer(1.0).timeout
			lose_minigame()
		else:
			await get_tree().create_timer(1.2).timeout
			start_round()

func next_round():
	if current_round >= total_rounds:
		play_win_celebration()
	else:
		current_round += 1
		start_round()

func play_win_celebration():
	round_active = false

	# Fire confetti
	if confetti:
		confetti.emitting = true

	# Flash screen white
	var flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0.6)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.4)
	flash_tween.tween_callback(flash.queue_free)

	# Shake glass
	if glass:
		var shake_tween = create_tween()
		shake_tween.tween_property(glass, "position:x", glass_base_pos.x + 10, 0.05)
		shake_tween.tween_property(glass, "position:x", glass_base_pos.x - 10, 0.05)
		shake_tween.tween_property(glass, "position:x", glass_base_pos.x + 6, 0.05)
		shake_tween.tween_property(glass, "position:x", glass_base_pos.x - 6, 0.05)
		shake_tween.tween_property(glass, "position:x", glass_base_pos.x, 0.05)

	# Show PERFECT POUR! — scale up with bounce then fade
	if victory_label:
		victory_label.show()
		victory_label.scale = Vector2(0.3, 0.3)
		victory_label.modulate.a = 1.0
		var vt = create_tween()
		vt.tween_property(victory_label, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		vt.tween_interval(1.2)
		vt.tween_property(victory_label, "modulate:a", 0.0, 0.4)

	await get_tree().create_timer(2.2).timeout
	win_minigame()

func update_ui():
	if round_label:
		round_label.text = "Round %d / %d" % [current_round, total_rounds]
	if drink_type_label:
		drink_type_label.text = ROUND_DRINK_NAMES[current_round - 1]
	if lives_label:
		var hearts = ""
		for i in range(lives):
			hearts += "❤ "
		for i in range(3 - lives):
			hearts += "♡ "
		lives_label.text = hearts.strip_edges()

func _add_vignette():
	vignette_layer = CanvasLayer.new()
	vignette_layer.name = "PourVignette"
	vignette_layer.layer = 90

	var vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv) * 1.4;
	float vig = smoothstep(0.4, 1.0, dist);
	COLOR = vec4(0.0, 0.0, 0.0, vig * 0.6);
}
"""
	mat.shader = shader
	vignette.material = mat
	vignette_layer.add_child(vignette)
	get_tree().get_root().add_child(vignette_layer)

func _remove_vignette():
	if vignette_layer:
		vignette_layer.queue_free()
		vignette_layer = null

func win_minigame():
	print("Drink Pour WON!")
	emit_signal("minigame_won", 0)

func lose_minigame():
	print("Drink Pour LOST!")
	emit_signal("minigame_lost")
	if game_manager:
		game_manager.minigame_lost.emit()

func _exit_tree():
	_remove_vignette()
	if target_line:
		target_line.modulate.a = 1.0
	if liquid:
		liquid.modulate.a = 1.0

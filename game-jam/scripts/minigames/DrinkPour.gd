extends Control

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

# Parameters (set per round + difficulty)
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

# Glass shapes per round: [width, height, color]
const ROUND_GLASS_CONFIGS = [
	{"w": 160, "h": 320, "color": Color(0.8, 0.9, 1.0, 0.15)},   # Round 1: tall pint
	{"w": 220, "h": 240, "color": Color(0.9, 0.85, 1.0, 0.15)},  # Round 2: wide tumbler
	{"w": 100, "h": 360, "color": Color(0.8, 1.0, 0.85, 0.15)},  # Round 3: narrow flute
]

# Liquid colors per round
const ROUND_LIQUID_COLORS = [
	Color(0.9, 0.6, 0.1, 0.85),   # Round 1: amber/beer
	Color(0.3, 0.15, 0.6, 0.85),  # Round 2: purple/cocktail
	Color(0.9, 0.9, 0.95, 0.85),  # Round 3: clear/champagne
]

# References
var glass: ColorRect
var liquid: ColorRect
var target_line: Line2D
var instruction_label: Label
var feedback_label: Label
var pour_indicator: Label
var round_label: Label
var lives_label: Label
var alcohol_system: Node
var sfx_manager: Node
var game_manager: Node

# Signals
signal minigame_won(cash_reward)
signal minigame_lost()

func _ready():
	glass = get_node_or_null("Glass")
	if glass:
		liquid = glass.get_node_or_null("Liquid")
		target_line = glass.get_node_or_null("TargetLine")

	instruction_label = get_node_or_null("InstructionLabel")
	feedback_label = get_node_or_null("FeedbackLabel")
	pour_indicator = get_node_or_null("PourIndicator")
	round_label = get_node_or_null("RoundLabel")
	lives_label = get_node_or_null("LivesLabel")

	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	sfx_manager = get_node_or_null("/root/SFXManager")
	game_manager = get_node_or_null("/root/GameManager")

	if alcohol_system and "current_stage" in alcohol_system:
		difficulty_stage = alcohol_system.current_stage

	adjust_difficulty()

	if difficulty_stage >= 2:
		_add_vignette()

	start_round()
	print("Drink Pour started — Stage: %d" % difficulty_stage)

func start_round():
	# Reset pour state
	liquid_level = 0.0
	is_pouring = false
	has_poured = false
	round_active = true
	wobble_timer = 0.0
	camera_osc_timer = 0.0
	invisible_timer = 0.0
	is_invisible_pulse = false
	rotation_degrees = 0.0

	# Reset visibility in case of stage 4 pulse
	if target_line:
		target_line.modulate.a = 1.0
	if liquid:
		liquid.modulate.a = 1.0

	# Apply glass config for this round
	var config = ROUND_GLASS_CONFIGS[current_round - 1]
	if glass:
		glass.custom_minimum_size = Vector2(config["w"], config["h"])
		glass.size = Vector2(config["w"], config["h"])
		glass.offset_left = -config["w"] / 2.0
		glass.offset_top = -config["h"] / 2.0
		glass.offset_right = config["w"] / 2.0
		glass.offset_bottom = config["h"] / 2.0
		glass.color = config["color"]
		glass_base_pos = glass.position

	# Apply liquid colour for this round
	if liquid:
		liquid.color = ROUND_LIQUID_COLORS[current_round - 1]
		liquid.size = Vector2(config["w"], 0)
		liquid.position = Vector2(0, config["h"])

	# Update target line width to match glass
	if target_line:
		target_line.set_point_position(0, Vector2(0, 0))
		target_line.set_point_position(1, Vector2(config["w"], 0))

	# Round speed increases each round
	var round_speed_bonus = (current_round - 1) * 0.3
	target_line_speed = _base_speed() + round_speed_bonus
	tolerance = max(0.05, _base_tolerance() - (current_round - 1) * 0.02)

	update_ui()
	update_liquid_visual()

	if feedback_label:
		feedback_label.hide()

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
	if not round_active:
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

	# Stage 3: Camera oscillation + glass shifts
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

	# Pour
	if is_pouring:
		var pour_speed = 0.35
		if difficulty_stage >= 1:
			wobble_timer += delta
			pour_speed += sin(wobble_timer * 8.0) * 0.08
		liquid_level = min(1.0, liquid_level + pour_speed * delta)
		update_liquid_visual()

		# Overflow — auto fail
		if liquid_level >= 1.0:
			is_pouring = false
			_show_pour_indicator(false)
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

func _input(event):
	if not round_active:
		return

	if event.is_action_pressed("ui_select"):
		is_pouring = true
		_show_pour_indicator(true)
		if sfx_manager:
			sfx_manager.play_sfx("liquid_pour_loop")

	elif event.is_action_released("ui_select"):
		if is_pouring:
			is_pouring = false
			_show_pour_indicator(false)
			check_accuracy()

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

	if feedback_label:
		feedback_label.show()
		if success:
			feedback_label.text = "✓ Nice Pour! %.0f%%" % accuracy_percent
			feedback_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			feedback_label.text = "✗ Too far off! %.0f%%" % accuracy_percent
			feedback_label.add_theme_color_override("font_color", Color.RED)

	if success:
		if sfx_manager:
			sfx_manager.play_sfx("sequence_correct")
		# Wait then go to next round
		await get_tree().create_timer(1.2).timeout
		next_round()
	else:
		lives -= 1
		if sfx_manager:
			sfx_manager.play_sfx("spill_splash")
		if alcohol_system and alcohol_system.has_method("drink_alcohol"):
			alcohol_system.drink_alcohol(0.2)
		update_ui()

		if lives <= 0:
			await get_tree().create_timer(1.0).timeout
			lose_minigame()
		else:
			# Retry same round
			await get_tree().create_timer(1.2).timeout
			start_round()

func next_round():
	if current_round >= total_rounds:
		win_minigame()
	else:
		current_round += 1
		start_round()

func update_ui():
	if round_label:
		round_label.text = "Round %d / %d" % [current_round, total_rounds]
	if lives_label:
		var hearts = ""
		for i in range(lives):
			hearts += "❤ "
		for i in range(3 - lives):
			hearts += "♡ "
		lives_label.text = hearts.strip_edges()

func adjust_difficulty():
	# Base values set in _base_speed() and _base_tolerance()
	# Called once on ready to apply vignette if needed
	pass

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

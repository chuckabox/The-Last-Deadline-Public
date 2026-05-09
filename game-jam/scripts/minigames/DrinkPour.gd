extends Control

# Pour State
var liquid_level = 0.0  # 0.0 (empty) to 1.0 (full)
var target_line_position = 0.5  # 0.0 to 1.0
var is_pouring = false
var has_poured = false

# Parameters
var target_line_speed = 1.0
var target_line_direction = 1.0
var tolerance = 0.1  # ±10%
var difficulty_stage = 0

# Difficulty effect state
var wobble_timer = 0.0
var direction_change_cooldown = 0.0
var camera_osc_timer = 0.0
var glass_base_pos: Vector2
var invisible_timer = 0.0
var invisible_interval = 0.0
var is_invisible_pulse = false
var vignette_layer: CanvasLayer

# References
var glass: ColorRect
var liquid: ColorRect
var target_line: Line2D
var instruction_label: Label
var accuracy_label: Label
var alcohol_system: Node

# Signals
signal minigame_won(cash_reward)
signal minigame_lost()

func _ready():
	# Get references
	glass = get_node_or_null("Glass")
	if glass:
		liquid = glass.get_node_or_null("Liquid")
		target_line = glass.get_node_or_null("TargetLine")
	instruction_label = get_node_or_null("InstructionLabel")
	accuracy_label = get_node_or_null("AccuracyLabel")
	
	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	if alcohol_system and "current_stage" in alcohol_system:
		difficulty_stage = alcohol_system.current_stage
	
	# Store glass base position before any effects
	if glass:
		glass_base_pos = glass.position
	
	# Adjust difficulty
	adjust_difficulty()
	
	if instruction_label:
		instruction_label.text = "Hold SPACEBAR to pour, release when liquid matches the line!"
	print("Drink Pour mini-game started")

func _physics_process(delta):
	if has_poured:
		return
	
	# Update target line position (oscillate based on speed)
	target_line_position = 0.5 + sin(Time.get_ticks_msec() * 0.001 * target_line_speed * 2.0) * 0.35
	
	# Stage 2+: Sudden direction changes
	if difficulty_stage >= 2:
		direction_change_cooldown -= delta
		if direction_change_cooldown <= 0 and randf() < 0.02:
			target_line_direction *= -1.0
			direction_change_cooldown = 0.8  # Don't flip again too soon
		target_line_position = 0.5 + sin(Time.get_ticks_msec() * 0.001 * target_line_speed * 2.0 * target_line_direction) * 0.35
	
	update_target_line()
	
	# Stage 3: Camera oscillation + glass shifts
	if difficulty_stage >= 3:
		camera_osc_timer += delta
		rotation_degrees = sin(camera_osc_timer * 2.5) * 4.0
		if glass:
			var shift = sin(camera_osc_timer * 1.8) * 15.0
			glass.position.x = glass_base_pos.x + shift
	
	# Stage 4: Line/liquid invisible pulses (0.5–1s)
	if difficulty_stage >= 4:
		invisible_timer -= delta
		if invisible_timer <= 0:
			is_invisible_pulse = not is_invisible_pulse
			invisible_timer = randf_range(0.5, 1.0)
			if target_line:
				target_line.modulate.a = 0.0 if is_invisible_pulse else 1.0
			if liquid:
				liquid.modulate.a = 0.0 if is_invisible_pulse else 1.0
	
	# Pour if holding spacebar
	if is_pouring:
		var pour_speed = 0.5
		# Stage 1+: Stream wobbles (pour rate oscillates)
		if difficulty_stage >= 1:
			wobble_timer += delta
			pour_speed += sin(wobble_timer * 8.0) * 0.2
		liquid_level = min(1.0, liquid_level + pour_speed * delta)
		update_liquid_visual()

func update_target_line():
	if not glass or not target_line: return
	var line_y = glass.size.y * (1.0 - target_line_position)
	# Set points for the Line2D
	target_line.set_point_position(0, Vector2(0, line_y))
	target_line.set_point_position(1, Vector2(glass.size.x, line_y))

func update_liquid_visual():
	if not glass or not liquid: return
	# Liquid fills from the bottom
	liquid.size.y = glass.size.y * liquid_level
	liquid.position.y = glass.size.y * (1.0 - liquid_level)

func _input(event):
	if has_poured: return
	
	if event.is_action_pressed("ui_select"):
		is_pouring = true
	elif event.is_action_released("ui_select"):
		if is_pouring:
			is_pouring = false
			check_accuracy()

func check_accuracy():
	has_poured = true
	
	var difference = abs(liquid_level - target_line_position)
	var accuracy_percent = max(0, (1.0 - (difference / (tolerance * 2.0))) * 100)
	
	if accuracy_label:
		accuracy_label.show()
		accuracy_label.text = "Accuracy: %.0f%%" % accuracy_percent
	
	if difference < tolerance:
		# Accurate
		if accuracy_label:
			accuracy_label.add_theme_color_override("font_color", Color.GREEN)
		print("Drink Pour WON! Accuracy: %.0f%%" % accuracy_percent)
		emit_signal("minigame_won", 100 + int(accuracy_percent))
	else:
		# Inaccurate
		if accuracy_label:
			accuracy_label.add_theme_color_override("font_color", Color.RED)
		print("Drink Pour LOST! Accuracy: %.0f%%" % accuracy_percent)
		emit_signal("minigame_lost")
		
		# Notify GameManager for global ending checks
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager:
			game_manager.minigame_lost.emit()

func adjust_difficulty():
	# Adjust parameters by alcohol stage
	match difficulty_stage:
		0:
			target_line_speed = 1.0
			tolerance = 0.15
		1:
			target_line_speed = 1.5
			tolerance = 0.12
		2:
			target_line_speed = 2.0
			tolerance = 0.10
		3:
			target_line_speed = 2.5
			tolerance = 0.08
		4:
			target_line_speed = 3.5
			tolerance = 0.05
	
	# Stage 2+: Add vignette overlay
	if difficulty_stage >= 2:
		_add_vignette()

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

func _exit_tree():
	_remove_vignette()
	# Reset any invisible pulses
	if target_line:
		target_line.modulate.a = 1.0
	if liquid:
		liquid.modulate.a = 1.0

func play_sound(sound_name: String):
	# TODO: Play SFX
	pass

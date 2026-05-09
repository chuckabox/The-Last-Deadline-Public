extends CanvasLayer

const METER_FILL_DURATION := 0.6
const STAGE_EFFECT_DELAY := 0.7

const STAGE_COLORS := {
	0: Color.WHITE,
	1: Color.GREEN,
	2: Color.ORANGE,
	3: Color.RED,
	4: Color.BLACK
}

# Tick mark positions (fraction of bar width) — match AlcoholSystem stage entry
# thresholds: Buzz 0.25, Tunnel 0.50, Spin 0.75, Blackout 0.90.
const STAGE_TICK_THRESHOLDS: Array[float] = [0.25, 0.50, 0.75, 0.90]

# References
var alcohol_meter: TextureProgressBar
var alcohol_stage_label: Label
var bac_label: Label
var score_label: Label
var clock_label: Label
var warning_label: Label
var warning_control: Control
var screen_effects: ColorRect

# References to systems
var alcohol_system: Node
var time_manager: Node
var game_manager: Node

# Debounce: rapid stage changes only run the latest scheduled effect.
var _stage_token: int = 0

# Tween tracking for the meter fill animation
var _meter_tween: Tween
var _effects_tween: Tween

func _ready():
	# Get references
	alcohol_meter = get_node("Container/AlcoholMeterPanel/AlcoholMeter")
	alcohol_stage_label = get_node("Container/AlcoholMeterPanel/AlcoholStageLabel")
	bac_label = get_node("Container/AlcoholMeterPanel/BACLabel")
	score_label = get_node("Container/TopRight/ScoreLabel")
	clock_label = get_node("Container/TopRight/ClockLabel")
	warning_label = get_node("Container/WarningText/WarningLabel")
	warning_control = get_node("Container/WarningText")
	screen_effects = get_node("Container/ScreenEffects")

	# Get system references
	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	time_manager = get_node_or_null("/root/TimeManager")
	game_manager = get_node_or_null("/root/GameManager")

	# Connect signals
	if alcohol_system:
		alcohol_system.alcohol_changed.connect(_on_alcohol_changed)
		alcohol_system.stage_changed.connect(_on_stage_changed)

	if time_manager:
		time_manager.time_updated.connect(_on_time_updated)
		time_manager.warning_yellow.connect(_on_warning_yellow)
		time_manager.warning_red.connect(_on_warning_red)

	if game_manager:
		game_manager.cash_changed.connect(_on_cash_changed)
		_on_cash_changed(game_manager.total_cash)

	# Setup Screen Effects Shader
	_setup_screen_shader()

	# Initial fill is instant
	_set_meter_value(_current_alcohol_value(), false)
	_update_bac_text(_current_alcohol_value())

	# Explicitly set clock baseline
	if clock_label:
		clock_label.add_theme_color_override("font_color", Color.WHITE)
		clock_label.scale = Vector2(1.0, 1.0)
		clock_label.pivot_offset = clock_label.size / 2.0

	print("HUD initialized")

func _setup_screen_shader():
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.0;
	uniform float blur_amount : hint_range(0.0, 5.0) = 0.0;
	uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.0;
	uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

	void fragment() {
		vec4 color = texture(screen_texture, SCREEN_UV);
		
		// Vignette
		vec2 uv = SCREEN_UV - vec2(0.5);
		float dist = length(uv) * 1.5;
		float vig = smoothstep(0.4, 1.0, dist) * vignette_intensity;
		color.rgb = mix(color.rgb, vec3(0.0), vig);
		
		// Simple Blur (Simulated via lod if supported, or just darken/distort)
		if (blur_amount > 0.1) {
			vec4 blurred = textureLod(screen_texture, SCREEN_UV, blur_amount);
			color.rgb = mix(color.rgb, blurred.rgb, 0.5);
		}
		
		// Blackout Pulse
		color.rgb = mix(color.rgb, vec3(0.0), pulse_intensity);
		
		COLOR = color;
	}
	"""
	mat.shader = shader
	screen_effects.material = mat
	screen_effects.show()

func _on_alcohol_changed(value: float, _stage: int) -> void:
	_set_meter_value(value, true)
	_update_bac_text(value)

func _update_bac_text(value: float):
	# Max BAC is 0.40% (blackout territory)
	var bac = value * 0.40
	if bac_label:
		bac_label.text = "BAC: %.2f%%" % bac

func _on_cash_changed(new_total: int):
	if score_label:
		score_label.text = "Cash: $%d" % new_total
		# Quick punch animation
		var t = create_tween()
		t.tween_property(score_label, "scale", Vector2(1.2, 1.2), 0.1)
		t.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.2)

func _on_stage_changed(new_stage: int) -> void:
	_stage_token += 1
	var token := _stage_token
	await get_tree().create_timer(METER_FILL_DURATION + STAGE_EFFECT_DELAY).timeout
	if token != _stage_token:
		return
	_apply_stage_effects(new_stage)

func _apply_stage_effects(new_stage: int) -> void:
	# Update bar tint
	if STAGE_COLORS.has(new_stage):
		alcohol_meter.tint_progress = STAGE_COLORS[new_stage]

	if alcohol_system and alcohol_system.has_method("get_stage_name"):
		alcohol_stage_label.text = alcohol_system.get_stage_name()
		alcohol_stage_label.add_theme_color_override("font_color", STAGE_COLORS[new_stage])

	if new_stage == 4:
		warning_control.show()
	else:
		warning_control.hide()

	# Apply Screen Shaders via Tween for smoothness
	if _effects_tween: _effects_tween.kill()
	_effects_tween = create_tween()
	
	var mat = screen_effects.material as ShaderMaterial
	
	# Vignette (Stage 2+)
	var vig = 0.6 if new_stage >= 2 else 0.0
	_effects_tween.parallel().tween_method(func(v): mat.set_shader_parameter("vignette_intensity", v), 
		mat.get_shader_parameter("vignette_intensity"), vig, 1.0)
		
	# Blur (Stage 3+)
	var blur = 2.0 if new_stage >= 3 else 0.0
	_effects_tween.parallel().tween_method(func(v): mat.set_shader_parameter("blur_amount", v), 
		mat.get_shader_parameter("blur_amount"), blur, 1.0)
		
	# Blackout Pulse (Stage 4)
	if new_stage == 4:
		_effects_tween.parallel().tween_method(func(v): mat.set_shader_parameter("pulse_intensity", v), 
			0.0, 0.4, 0.5).set_loops()
		_effects_tween.parallel().tween_method(func(v): mat.set_shader_parameter("pulse_intensity", v), 
			0.4, 0.0, 0.5)
	else:
		_effects_tween.parallel().tween_method(func(v): mat.set_shader_parameter("pulse_intensity", v), 
			mat.get_shader_parameter("pulse_intensity"), 0.0, 1.0)

var _clock_tween: Tween
var _clock_base_pos: Vector2

func _on_time_updated(time_string: String):
	clock_label.text = time_string
	if _clock_base_pos == Vector2.ZERO:
		_clock_base_pos = clock_label.position

func _on_warning_yellow():
	clock_label.add_theme_color_override("font_color", Color.YELLOW)
	if _clock_tween: _clock_tween.kill()
	_clock_tween = create_tween().set_loops()
	_clock_tween.tween_property(clock_label, "scale", Vector2(1.1, 1.1), 0.5).set_trans(Tween.TRANS_SINE)
	_clock_tween.tween_property(clock_label, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)

func _on_warning_red():
	clock_label.add_theme_color_override("font_color", Color.RED)
	if _clock_tween: _clock_tween.kill()
	clock_label.scale = Vector2(1.0, 1.0)
	
	_clock_tween = create_tween().set_loops()
	var base_pos = _clock_base_pos if _clock_base_pos != Vector2.ZERO else clock_label.position
	_clock_tween.tween_property(clock_label, "position", base_pos + Vector2(3, 3), 0.05)
	_clock_tween.tween_property(clock_label, "position", base_pos + Vector2(-3, -2), 0.05)
	_clock_tween.tween_property(clock_label, "position", base_pos + Vector2(2, -3), 0.05)
	_clock_tween.tween_property(clock_label, "position", base_pos + Vector2(-2, 3), 0.05)
	_clock_tween.tween_property(clock_label, "position", base_pos, 0.05)
	_clock_tween.tween_interval(0.1)

func _current_alcohol_value() -> float:
	if alcohol_system and "alcohol" in alcohol_system:
		return alcohol_system.alcohol
	return 0.0

func _set_meter_value(value: float, animated: bool) -> void:
	alcohol_meter.max_value = 1.0
	alcohol_meter.step = 0.001
	if _meter_tween and _meter_tween.is_valid():
		_meter_tween.kill()
	if animated:
		_meter_tween = get_tree().create_tween()
		_meter_tween.tween_property(alcohol_meter, "value", value, METER_FILL_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var flash_tween = get_tree().create_tween()
		flash_tween.tween_property(alcohol_meter, "modulate", Color(2, 2, 2, 1), 0.1)
		flash_tween.tween_property(alcohol_meter, "modulate", Color.WHITE, 0.4)
	else:
		alcohol_meter.value = value

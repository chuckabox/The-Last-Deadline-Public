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
var bar_points: Array[Node] = []
var alcohol_stage_label: Label
var bac_label: Label
var clock_label: Label
var warning_label: Label
var warning_control: Control
var screen_effects: ColorRect
var hud_container: Control
var interaction_prompt: Control
var interaction_icon: TextureRect

# References to systems
var alcohol_system: Node
var time_manager: Node

# Debounce: rapid stage changes only run the latest scheduled effect.
var _stage_token: int = 0

# Tween tracking for the effects
var _effects_tween: Tween
var _pulse_tween: Tween

func _ready():
	# Get HUD container
	hud_container = $HUDContainer
	if hud_container:
		hud_container.modulate.a = 0.0

	# Get bar point references (1st to 8th)
	var point_names = ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th"]
	for p_name in point_names:
		var node = get_node_or_null("HUDContainer/" + p_name)
		if node:
			bar_points.append(node)
			node.hide()

	# Get other references
	alcohol_stage_label = get_node_or_null("HUDContainer/AlcoholMeterPanel/AlcoholStageLabel")
	bac_label = get_node_or_null("HUDContainer/AlcoholMeterPanel/BACLabel")
	clock_label = get_node_or_null("HUDContainer/ClockLabel")
	warning_label = get_node_or_null("HUDContainer/WarningText/WarningLabel")
	warning_control = get_node_or_null("HUDContainer/WarningText")
	screen_effects = get_node_or_null("HUDContainer/ScreenEffects")
	interaction_prompt = get_node_or_null("HUDContainer/InteractionPrompt")
	interaction_icon = get_node_or_null("HUDContainer/InteractionPrompt/KeyIcon")

	# Get system references
	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	time_manager = get_node_or_null("/root/TimeManager")

	# Connect signals
	if alcohol_system:
		alcohol_system.alcohol_changed.connect(_on_alcohol_changed)
		alcohol_system.stage_changed.connect(_on_stage_changed)

	if time_manager:
		time_manager.time_updated.connect(_on_time_updated)
		time_manager.warning_yellow.connect(_on_warning_yellow)
		time_manager.warning_red.connect(_on_warning_red)

	# Setup Screen Effects Shader
	_setup_screen_shader()

	# Initial state
	_update_bar_points(_current_stage())
	_update_bac_text(_current_alcohol_value())

	# Explicitly set clock baseline
	if clock_label:
		clock_label.add_theme_color_override("font_color", Color.WHITE)
		clock_label.scale = Vector2(1.0, 1.0)
		clock_label.pivot_offset = clock_label.size / 2.0

	print("HUD initialized with discrete bar points")

func fade_in(duration: float = 1.0) -> void:
	visible = true
	if hud_container:
		var t = create_tween()
		t.tween_property(hud_container, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _setup_screen_shader():
	if not screen_effects: return
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
	
	# Explicitly initialize parameters to avoid Nil return values from get_shader_parameter
	mat.set_shader_parameter("vignette_intensity", 0.0)
	mat.set_shader_parameter("blur_amount", 0.0)
	mat.set_shader_parameter("pulse_intensity", 0.0)
	
	screen_effects.show()

func _on_alcohol_changed(value: float, stage: int) -> void:
	_update_bar_points(stage)
	_update_bac_text(value)

func _update_bar_points(stage: int):
	# Spec: each alcohol stage is 2 bar points.
	# Stage 0: 0 points
	# Stage 1: 2 points
	# Stage 2: 4 points
	# Stage 3: 6 points
	# Stage 4: 8 points
	var points_to_show = stage * 2
	for i in range(bar_points.size()):
		if i < points_to_show:
			bar_points[i].show()
		else:
			bar_points[i].hide()

func _update_bac_text(value: float):
	# Max BAC is 0.40% (blackout territory)
	var bac = value * 0.40
	if bac_label:
		bac_label.text = "BAC: %.2f%%" % bac

func _on_stage_changed(new_stage: int) -> void:
	_stage_token += 1
	var token := _stage_token
	# Delay for visual impact
	await get_tree().create_timer(STAGE_EFFECT_DELAY).timeout
	if token != _stage_token:
		return
	_apply_stage_effects(new_stage)

func _apply_stage_effects(new_stage: int) -> void:
	if alcohol_system and alcohol_system.has_method("get_stage_name"):
		if alcohol_stage_label:
			alcohol_stage_label.text = alcohol_system.get_stage_name()
			if STAGE_COLORS.has(new_stage):
				alcohol_stage_label.add_theme_color_override("font_color", STAGE_COLORS[new_stage])

	if new_stage == 4:
		if warning_control: 
			warning_control.show()
			# Disappear after 5 seconds (Safety check for tree)
			if is_inside_tree():
				get_tree().create_timer(5.0).timeout.connect(func(): 
					if is_inside_tree() and is_instance_valid(warning_control) and _current_stage() == 4: 
						warning_control.hide()
				)
	else:
		if warning_control: warning_control.hide()

	# Apply Screen Shaders via Tween for smoothness
	if not screen_effects or not screen_effects.material: return
	
	if _effects_tween: _effects_tween.kill()
	if _pulse_tween: _pulse_tween.kill()
	
	_effects_tween = create_tween()
	
	var mat = screen_effects.material as ShaderMaterial
	
	# Vignette (Stage 2+)
	var vig = 0.35 if new_stage >= 2 else 0.0
	var cur_vig = mat.get_shader_parameter("vignette_intensity")
	if cur_vig == null: cur_vig = 0.0
	_effects_tween.parallel().tween_method(func(v): mat.set_shader_parameter("vignette_intensity", v), 
		cur_vig, vig, 1.0)
		
	# Blur (Stage 3+)
	var blur = 1.5 if new_stage >= 3 else 0.0
	var cur_blur = mat.get_shader_parameter("blur_amount")
	if cur_blur == null: cur_blur = 0.0
	_effects_tween.parallel().tween_method(func(v): mat.set_shader_parameter("blur_amount", v), 
		cur_blur, blur, 1.0)
		
	# Blackout Blink (Stage 4)
	var cur_pulse = mat.get_shader_parameter("pulse_intensity")
	if cur_pulse == null: cur_pulse = 0.0
	
	if new_stage == 4:
		# Start a blinking loop with a long delay
		# 0.3s close, 0.3s open, 15s wait
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_method(func(v): mat.set_shader_parameter("pulse_intensity", v), 
			0.0, 0.95, 0.3).set_trans(Tween.TRANS_SINE)
		_pulse_tween.tween_method(func(v): mat.set_shader_parameter("pulse_intensity", v), 
			0.95, 0.0, 0.3).set_trans(Tween.TRANS_SINE)
		_pulse_tween.tween_interval(15.0)
	else:
		_effects_tween.parallel().tween_method(func(v): mat.set_shader_parameter("pulse_intensity", v), 
			cur_pulse, 0.0, 1.0)

var _clock_tween: Tween
var _clock_base_pos: Vector2

func _on_time_updated(time_string: String):
	if not clock_label: return
	clock_label.text = time_string
	if _clock_base_pos == Vector2.ZERO:
		_clock_base_pos = clock_label.position

func _on_warning_yellow():
	if not clock_label: return
	clock_label.add_theme_color_override("font_color", Color.YELLOW)
	if _clock_tween: _clock_tween.kill()
	_clock_tween = create_tween().set_loops()
	_clock_tween.tween_property(clock_label, "modulate", Color.YELLOW, 0.5)
	_clock_tween.tween_property(clock_label, "modulate", Color.WHITE, 0.5)

func _on_warning_red():
	if not clock_label: return
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

func _current_stage() -> int:
	if alcohol_system and "current_stage" in alcohol_system:
		return alcohol_system.current_stage
	return 0

func show_interaction_prompt(action_name: String = "ui_interact"):
	if not interaction_prompt or not interaction_icon: return
	
	# Configure the icon based on the action
	var atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/ui/Keyboard Letters and Symbols.png")
	
	# Default to 'E' key (64, 32, 16, 16)
	var region = Rect2(64, 32, 16, 16)
	
	# Try to detect if the bound key is different
	var events = InputMap.action_get_events(action_name)
	if events.size() > 0:
		var event_text = events[0].as_text().to_upper()
		if "SPACE" in event_text:
			region = Rect2(64, 128, 48, 16) # Space bar region (approximate)
		elif "F" in event_text:
			region = Rect2(80, 32, 16, 16)
			
	atlas.region = region
	interaction_icon.texture = atlas
	interaction_prompt.show()

func hide_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.hide()

func show_warning(text: String, duration: float = 2.0):
	if not warning_control or not warning_label: return
	
	warning_label.text = text
	warning_control.show()
	
	# Use a tween to handle the timeout and fade if desired, 
	# or just a simple timer.
	var t = create_tween()
	t.tween_interval(duration)
	t.tween_callback(warning_control.hide)

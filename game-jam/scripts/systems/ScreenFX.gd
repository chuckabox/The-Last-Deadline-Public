extends Node

## Screen-effects manager
## Owns full-screen overlays driven by alcohol stage:
##   Stage 2 — orange vignette closes over ~6s
##   Stage 3 — red vignette + cycling 9-tap Gaussian blur (1.5s up / 1.5s down)
##   Stage 4 — near-black vignette + repeating black pulse + master-bus audio
##             duck that leads the visual pulse by ~0.15s

var alcohol_system: Node

# Visual layers (built in code so no .tscn / .gdshader needed)
var canvas_layer: CanvasLayer
var vignette_rect: ColorRect
var vignette_material: ShaderMaterial

var blur_canvas: CanvasLayer
var blur_rect: ColorRect
var blur_material: ShaderMaterial
var _blur_phase: float = 0.0

var pulse_canvas: CanvasLayer
var pulse_rect: ColorRect
var _pulse_phase: float = 0.0

# Master-bus volume tracking for the audio-duck portion of the stage 4 pulse.
var _master_bus_idx: int = -1
var _master_base_db: float = 0.0

# Active animation; killed if a new stage change comes in mid-tween
var _vignette_tween: Tween

# Stage 3 blur: 1.5s build + 1.5s decay = 3s period; peak strength at 0.6.
const BLUR_CYCLE_PERIOD := 3.0
const BLUR_PEAK := 0.6

# Stage 4 pulse: alpha ramps up over 0.3s, decays over 1.0s, repeats.
const PULSE_RAMP_UP := 0.3
const PULSE_RAMP_DOWN := 1.0
const PULSE_PERIOD := PULSE_RAMP_UP + PULSE_RAMP_DOWN
const PULSE_PEAK_ALPHA := 1.0
# Audio duck on the master bus: -18 dB at peak (still audible, clearly muffled).
const AUDIO_DUCK_DB := -18.0
# Audio leads the visual pulse so dampening hits before the screen blacks out.
const AUDIO_LEAD_TIME := 0.15

# Per-stage vignette parameters: strength (0..1), tint color, fade-in seconds.
# Strength controls how far in from the edges the dark band reaches.
const STAGE_VIGNETTE := {
	0: {"strength": 0.0,  "color": Color(0.0, 0.0, 0.0, 0.0), "duration": 0.6},
	1: {"strength": 0.0,  "color": Color(0.0, 0.0, 0.0, 0.0), "duration": 0.6},
	2: {"strength": 0.55, "color": Color(1.0, 0.45, 0.0, 1.0), "duration": 6.0},
	3: {"strength": 0.75, "color": Color(1.0, 0.1, 0.1, 1.0), "duration": 1.5},
	4: {"strength": 0.95, "color": Color(0.0, 0.0, 0.0, 1.0), "duration": 0.6},
}

# Inline canvas_item shader: radial falloff from clear center to tinted edges.
const VIGNETTE_SHADER_CODE := """
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vcolor : source_color = vec4(0.0, 0.0, 0.0, 0.0);

void fragment() {
	vec2 uv = SCREEN_UV - vec2(0.5);
	float d = length(uv) * 1.4142;
	float inner = 1.0 - strength;
	float a = smoothstep(inner, 1.0, d) * vcolor.a;
	COLOR = vec4(vcolor.rgb, a);
}
"""

# 9-tap Gaussian blur sampling the screen below this layer.
const BLUR_SHADER_CODE := """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform float blur_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	if (blur_amount <= 0.001) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		vec2 px = SCREEN_PIXEL_SIZE * blur_amount * 8.0;
		vec4 sum = vec4(0.0);
		sum += texture(screen_texture, SCREEN_UV + vec2(-px.x, -px.y)) * 0.0625;
		sum += texture(screen_texture, SCREEN_UV + vec2( 0.0,  -px.y)) * 0.125;
		sum += texture(screen_texture, SCREEN_UV + vec2( px.x, -px.y)) * 0.0625;
		sum += texture(screen_texture, SCREEN_UV + vec2(-px.x,  0.0 )) * 0.125;
		sum += texture(screen_texture, SCREEN_UV)                       * 0.25;
		sum += texture(screen_texture, SCREEN_UV + vec2( px.x,  0.0 )) * 0.125;
		sum += texture(screen_texture, SCREEN_UV + vec2(-px.x,  px.y)) * 0.0625;
		sum += texture(screen_texture, SCREEN_UV + vec2( 0.0,   px.y)) * 0.125;
		sum += texture(screen_texture, SCREEN_UV + vec2( px.x,  px.y)) * 0.0625;
		COLOR = sum;
	}
}
"""

func _ready() -> void:
	add_to_group("managers")
	_build_visuals()

	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	if alcohol_system and alcohol_system.has_signal("stage_changed"):
		alcohol_system.stage_changed.connect(_on_stage_changed)

	print("ScreenFX initialized")

func _build_visuals() -> void:
	# Blur layer sits BELOW the vignette so the vignette tints whatever the
	# blur produced. Both are above gameplay (layer 0) and HUD (layer 1).
	blur_canvas = CanvasLayer.new()
	blur_canvas.layer = 49
	add_child(blur_canvas)

	blur_rect = ColorRect.new()
	blur_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var blur_shader := Shader.new()
	blur_shader.code = BLUR_SHADER_CODE
	blur_material = ShaderMaterial.new()
	blur_material.shader = blur_shader
	blur_material.set_shader_parameter("blur_amount", 0.0)
	blur_rect.material = blur_material
	blur_canvas.add_child(blur_rect)

	canvas_layer = CanvasLayer.new()
	# High layer so the vignette sits over gameplay AND the HUD — periphery
	# darkening is part of the "tunnel vision" effect by design.
	canvas_layer.layer = 50
	add_child(canvas_layer)

	vignette_rect = ColorRect.new()
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_rect.color = Color.WHITE  # the shader handles the actual color/alpha

	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER_CODE
	vignette_material = ShaderMaterial.new()
	vignette_material.shader = shader
	vignette_material.set_shader_parameter("strength", 0.0)
	vignette_material.set_shader_parameter("vcolor", Color(0, 0, 0, 0))
	vignette_rect.material = vignette_material

	canvas_layer.add_child(vignette_rect)

	# Pulse layer sits ABOVE the vignette so the black flash covers everything.
	pulse_canvas = CanvasLayer.new()
	pulse_canvas.layer = 51
	add_child(pulse_canvas)

	pulse_rect = ColorRect.new()
	pulse_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	pulse_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse_rect.color = Color(0, 0, 0, 0)
	pulse_canvas.add_child(pulse_rect)

func _on_stage_changed(new_stage: int) -> void:
	var cfg: Dictionary = STAGE_VIGNETTE.get(new_stage, STAGE_VIGNETTE[0])
	_animate_vignette(cfg["strength"], cfg["color"], cfg["duration"])

func _animate_vignette(target_strength: float, target_color: Color, duration: float) -> void:
	if _vignette_tween and _vignette_tween.is_valid():
		_vignette_tween.kill()

	_vignette_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	_vignette_tween.tween_method(_set_strength, _get_strength(), target_strength, duration)
	_vignette_tween.tween_method(_set_color, _get_color(), target_color, duration)

func _set_strength(v: float) -> void:
	vignette_material.set_shader_parameter("strength", v)

func _get_strength() -> float:
	var v = vignette_material.get_shader_parameter("strength")
	return v if v != null else 0.0

func _set_color(c: Color) -> void:
	vignette_material.set_shader_parameter("vcolor", c)

func _get_color() -> Color:
	var c = vignette_material.get_shader_parameter("vcolor")
	return c if c is Color else Color(0, 0, 0, 0)

func _process(delta: float) -> void:
	_update_blur(delta)
	_update_pulse(delta)

func _update_blur(delta: float) -> void:
	# Stage 3 blur cycle: gated by stage 3 intensity, oscillates 1.5s up / 1.5s down.
	if not blur_material:
		return

	var base := 0.0
	if alcohol_system and alcohol_system.has_method("get_stage_intensity"):
		base = alcohol_system.get_stage_intensity(3)

	if base <= 0.0:
		var current = blur_material.get_shader_parameter("blur_amount")
		if current != null and current > 0.0:
			blur_material.set_shader_parameter("blur_amount", 0.0)
		_blur_phase = 0.0
		return

	_blur_phase += delta
	# Cosine remapped to [0, 1] over BLUR_CYCLE_PERIOD: 0 -> 1 -> 0.
	var cycle := 0.5 - 0.5 * cos((_blur_phase / BLUR_CYCLE_PERIOD) * TAU)
	blur_material.set_shader_parameter("blur_amount", base * cycle * BLUR_PEAK)

func _update_pulse(delta: float) -> void:
	# Stage 4 black pulse + master-bus audio duck. Audio leads visuals.
	if not pulse_rect:
		return

	var base := 0.0
	if alcohol_system and alcohol_system.has_method("get_stage_intensity"):
		base = alcohol_system.get_stage_intensity(4)

	if base <= 0.0:
		if pulse_rect.color.a > 0.0:
			pulse_rect.color = Color(0, 0, 0, 0)
		_restore_audio()
		_pulse_phase = 0.0
		return

	_pulse_phase = fposmod(_pulse_phase + delta, PULSE_PERIOD)

	var visual_t := _pulse_alpha_at(_pulse_phase)
	pulse_rect.color = Color(0, 0, 0, visual_t * base * PULSE_PEAK_ALPHA)

	# Audio curve runs ahead of the visual curve so dampening lands first.
	var audio_phase := fposmod(_pulse_phase + AUDIO_LEAD_TIME, PULSE_PERIOD)
	var audio_t := _pulse_alpha_at(audio_phase) * base
	_apply_audio_duck(audio_t)

func _pulse_alpha_at(t: float) -> float:
	if t < PULSE_RAMP_UP:
		return t / PULSE_RAMP_UP
	return clampf(1.0 - (t - PULSE_RAMP_UP) / PULSE_RAMP_DOWN, 0.0, 1.0)

func _ensure_master_bus() -> void:
	if _master_bus_idx >= 0:
		return
	_master_bus_idx = AudioServer.get_bus_index("Master")
	if _master_bus_idx >= 0:
		_master_base_db = AudioServer.get_bus_volume_db(_master_bus_idx)

func _apply_audio_duck(t: float) -> void:
	_ensure_master_bus()
	if _master_bus_idx < 0:
		return
	var db: float = lerpf(_master_base_db, _master_base_db + AUDIO_DUCK_DB, clampf(t, 0.0, 1.0))
	AudioServer.set_bus_volume_db(_master_bus_idx, db)

func _restore_audio() -> void:
	if _master_bus_idx < 0:
		return
	AudioServer.set_bus_volume_db(_master_bus_idx, _master_base_db)

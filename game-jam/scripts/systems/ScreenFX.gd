extends Node

## Screen-effects manager
## Owns full-screen overlays driven by alcohol stage. Currently:
##   Stage 2 — orange vignette closes over ~6s
## Designed to grow:
##   Stage 3 — red vignette tightens further (blur layer added later)
##   Stage 4 — black vignette near-solid (pulse overlay added later)

var alcohol_system: Node

# Visual layer (built in code so no .tscn / .gdshader needed)
var canvas_layer: CanvasLayer
var vignette_rect: ColorRect
var vignette_material: ShaderMaterial

# Active animation; killed if a new stage change comes in mid-tween
var _vignette_tween: Tween

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

func _ready() -> void:
	add_to_group("managers")
	_build_visuals()

	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	if alcohol_system and alcohol_system.has_signal("stage_changed"):
		alcohol_system.stage_changed.connect(_on_stage_changed)

	print("ScreenFX initialized")

func _build_visuals() -> void:
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

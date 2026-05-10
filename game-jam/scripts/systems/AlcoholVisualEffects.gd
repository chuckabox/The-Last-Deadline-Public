extends CanvasLayer

class_name AlcoholVisualEffects

# References
var camera: Camera2D
var alcohol_system: Node
var player: CharacterBody2D

# Effect nodes
var vignette: Panel
var blur_rect: ColorRect
var blackout_rect: ColorRect
var warning_label: Label

# State
var current_stage = 0
var sway_offset = 0.0
var vignette_radius = 200.0
var blur_amount = 0.0
var blackout_intensity = 0.0

func _ready():
	add_to_group("effects")
	
	# Get references safely
	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	camera = get_viewport().get_camera_2d()
	
	# Create effect layers
	create_effect_layers()
	
	# Connect signals
	if alcohol_system and alcohol_system.has_signal("stage_changed"):
		alcohol_system.stage_changed.connect(_on_stage_changed)
	
	print("AlcoholVisualEffects initialized")

func create_effect_layers():
	# Vignette (Stage 2+)
	vignette = Panel.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Note: For a true vignette, we would apply a shader material here
	vignette.modulate.a = 0.0
	add_child(vignette)
	
	# Blur (Stage 3+)
	blur_rect = ColorRect.new()
	blur_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur_rect.color = Color(1, 1, 1, 0)
	add_child(blur_rect)
	
	# Blackout (Stage 4+)
	blackout_rect = ColorRect.new()
	blackout_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blackout_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackout_rect.color = Color.BLACK
	blackout_rect.modulate.a = 0.0
	add_child(blackout_rect)
	
	# Warning text
	warning_label = Label.new()
	warning_label.text = "One more drink and I'll black out!"
	warning_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warning_label.add_theme_font_size_override("font_size", 32)
	warning_label.add_theme_color_override("font_color", Color.RED)
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.hide()
	add_child(warning_label)

func _process(delta):
	if not alcohol_system:
		return
		
	var stage = alcohol_system.current_stage
	
	# Periodically refresh camera reference if it changes during room transitions
	if Engine.get_frames_drawn() % 60 == 0:
		camera = get_viewport().get_camera_2d()
	
	match stage:
		0:
			apply_normal_effects()
		1:
			apply_buzz_effects(delta)
		2:
			apply_tunnel_vision_effects(delta)
		3:
			apply_spin_effects(delta)
		4:
			apply_blackout_effects(delta)

func apply_normal_effects():
	# Gradually return camera to normal
	if camera:
		camera.offset = camera.offset.lerp(Vector2.ZERO, 0.1)
	
	# Fade out UI effects
	vignette.modulate.a = lerp(vignette.modulate.a, 0.0, 0.1)
	blur_rect.modulate.a = lerp(blur_rect.modulate.a, 0.0, 0.1)
	blackout_rect.modulate.a = lerp(blackout_rect.modulate.a, 0.0, 0.1)

func apply_buzz_effects(delta):
	# Stage 1: Camera sway (sine wave)
	sway_offset = sin(Time.get_ticks_msec() / 500.0) * 12.0
	
	if camera:
		camera.offset.x = lerp(camera.offset.x, sway_offset, 0.1)

func apply_tunnel_vision_effects(delta):
	# Stage 2: Vignette pulse
	var target_alpha = 0.3 + sin(Time.get_ticks_msec() / 1000.0) * 0.1
	vignette.modulate.a = lerp(vignette.modulate.a, target_alpha, delta * 2.0)
	
	# Also apply buzz effects
	apply_buzz_effects(delta)

func apply_spin_effects(delta):
	# Stage 3: Simulated "blur" via alpha cycling
	var cycle_time = fmod(Time.get_ticks_msec() / 1500.0, 1.0)
	
	if cycle_time < 0.5:
		blur_amount = lerp(0.0, 0.25, cycle_time * 2.0)
	else:
		blur_amount = lerp(0.25, 0.0, (cycle_time - 0.5) * 2.0)
	
	blur_rect.modulate.a = blur_amount
	
	# Also apply buzz and tunnel effects
	apply_buzz_effects(delta)
	apply_tunnel_vision_effects(delta)

func apply_blackout_effects(delta):
	# Stage 4: blackout pulse is owned by ScreenFX. Keep this rect clear.
	blackout_intensity = 0.0
	blackout_rect.modulate.a = 0.0
	
	# Show warning
	if warning_label:
		warning_label.show()
		# Pulse warning label scale
		var pulse = 1.0 + sin(Time.get_ticks_msec() / 200.0) * 0.1
		warning_label.scale = Vector2(pulse, pulse)
		warning_label.pivot_offset = warning_label.size / 2.0

func _on_stage_changed(new_stage: int):
	current_stage = new_stage
	
	# Reset effects if dropping below their trigger stage
	if new_stage < 2:
		vignette.modulate.a = 0.0
	
	if new_stage < 3:
		blur_rect.modulate.a = 0.0
	
	if new_stage < 4:
		if warning_label:
			warning_label.hide()

extends CanvasLayer

const METER_FILL_DURATION := 0.4
const STAGE_EFFECT_DELAY := 0.7

const STAGE_COLORS := {
	0: Color.WHITE,
	1: Color.GREEN,
	2: Color.ORANGE,
	3: Color.RED,
	4: Color.BLACK
}

# References
var alcohol_meter: ProgressBar
var alcohol_stage_label: Label
var clock_label: Label
var warning_label: Label
var warning_control: Control

# References to systems
var alcohol_system: Node
var time_manager: Node

# Debounce: rapid stage changes only run the latest scheduled effect.
var _stage_token: int = 0

# Stylebox driving the ProgressBar's actual fill color (not modulate).
var _fill_style: StyleBoxFlat

func _ready():
	# Get references
	alcohol_meter = get_node("Container/AlcoholMeterPanel/AlcoholMeter")
	alcohol_stage_label = get_node("Container/AlcoholMeterPanel/AlcoholStageLabel")
	clock_label = get_node("Container/TopRight/ClockLabel")
	warning_label = get_node("Container/WarningText/WarningLabel")
	warning_control = get_node("Container/WarningText")

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

	# Drive the bar's actual fill color via a stylebox override so we don't
	# tint the entire control (which `modulate` would do).
	_fill_style = StyleBoxFlat.new()
	_fill_style.bg_color = STAGE_COLORS[0]
	alcohol_meter.add_theme_stylebox_override("fill", _fill_style)

	# Initial fill is instant — no animation on game start.
	_set_meter_value(_current_alcohol_value(), false)

	print("HUD initialized")

func _on_alcohol_changed(value: float, _stage: int) -> void:
	# Meter fills first (animated). Stage effects come later in _on_stage_changed.
	_set_meter_value(value, true)

func _on_stage_changed(new_stage: int) -> void:
	# Spec: effects follow 0.5-1s AFTER the meter finishes filling.
	# Wait for the fill, then the post-fill buffer, then apply effects.
	# A token guards against rapid re-entry: only the latest schedule wins.
	_stage_token += 1
	var token := _stage_token
	await get_tree().create_timer(METER_FILL_DURATION + STAGE_EFFECT_DELAY).timeout
	if token != _stage_token:
		return
	_apply_stage_effects(new_stage)

func _apply_stage_effects(new_stage: int) -> void:
	if STAGE_COLORS.has(new_stage) and _fill_style:
		_fill_style.bg_color = STAGE_COLORS[new_stage]

	if alcohol_system and alcohol_system.has_method("get_stage_name"):
		alcohol_stage_label.text = alcohol_system.get_stage_name()

	if new_stage == 4:
		warning_control.show()

func _on_time_updated(time_string: String):
	clock_label.text = time_string

func _on_warning_yellow():
	clock_label.add_theme_color_override("font_color", Color.YELLOW)

func _on_warning_red():
	clock_label.add_theme_color_override("font_color", Color.RED)
	# Add pulse animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(clock_label, "scale", Vector2(1.2, 1.2), 0.3)
	tween.tween_property(clock_label, "scale", Vector2(1.0, 1.0), 0.3)

func _current_alcohol_value() -> float:
	if alcohol_system and "alcohol" in alcohol_system:
		return alcohol_system.alcohol
	return 0.0

func _set_meter_value(value: float, animated: bool) -> void:
	alcohol_meter.max_value = 1.0
	if animated:
		var tween := create_tween()
		tween.tween_property(alcohol_meter, "value", value, METER_FILL_DURATION)
	else:
		alcohol_meter.value = value

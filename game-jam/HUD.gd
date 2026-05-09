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

# Tween tracking for the meter fill animation
var _meter_tween: Tween

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

	_build_stage_ticks()

	# Initial fill is instant — no animation on game start.
	_set_meter_value(_current_alcohol_value(), false)

	# Explicitly set clock baseline to white and steady
	if clock_label:
		clock_label.add_theme_color_override("font_color", Color.WHITE)
		clock_label.scale = Vector2(1.0, 1.0)
		clock_label.pivot_offset = clock_label.size / 2.0

	print("HUD initialized")

## Replaces the legacy evenly-spaced VSeparator row (which landed at the wrong
## fractions) with thin vertical tick marks at the actual stage entry thresholds.
func _build_stage_ticks() -> void:
	if not alcohol_meter:
		return

	var legacy := get_node_or_null("Container/AlcoholMeterPanel/HBoxContainer")
	if legacy:
		legacy.visible = false

	for t: float in STAGE_TICK_THRESHOLDS:
		var tick := ColorRect.new()
		tick.color = Color(1, 1, 1, 0.5)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.anchor_left = t
		tick.anchor_right = t
		tick.anchor_top = 0.0
		tick.anchor_bottom = 1.0
		tick.offset_left = -1.0
		tick.offset_right = 1.0
		tick.offset_top = 0.0
		tick.offset_bottom = 0.0
		alcohol_meter.add_child(tick)

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

var _clock_tween: Tween
var _clock_base_pos: Vector2

func _on_time_updated(time_string: String):
	clock_label.text = time_string
	if _clock_base_pos == Vector2.ZERO:
		_clock_base_pos = clock_label.position

func _on_warning_yellow():
	clock_label.add_theme_color_override("font_color", Color.YELLOW)
	if _clock_tween:
		_clock_tween.kill()
	_clock_tween = create_tween()
	_clock_tween.set_loops()
	_clock_tween.tween_property(clock_label, "scale", Vector2(1.1, 1.1), 0.5).set_trans(Tween.TRANS_SINE)
	_clock_tween.tween_property(clock_label, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)

func _on_warning_red():
	clock_label.add_theme_color_override("font_color", Color.RED)
	if _clock_tween:
		_clock_tween.kill()
	clock_label.scale = Vector2(1.0, 1.0)
	
	_clock_tween = create_tween()
	_clock_tween.set_loops()
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
	if _meter_tween and _meter_tween.is_valid():
		_meter_tween.kill()
	if animated:
		_meter_tween = create_tween()
		_meter_tween.tween_property(alcohol_meter, "value", value, METER_FILL_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		# Flash the meter bar on fill
		var flash_tween = create_tween()
		flash_tween.tween_property(alcohol_meter, "modulate", Color(2, 2, 2, 1), 0.1)
		flash_tween.tween_property(alcohol_meter, "modulate", Color.WHITE, 0.4)
	else:
		alcohol_meter.value = value

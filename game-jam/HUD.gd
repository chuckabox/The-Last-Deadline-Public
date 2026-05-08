extends CanvasLayer

# References
var alcohol_meter: ProgressBar
var alcohol_stage_label: Label
var cash_label: Label
var clock_label: Label
var warning_label: Label
var warning_control: Control

# References to systems
var alcohol_system: Node
var time_manager: Node
var game_manager: Node

func _ready():
	# Get references
	alcohol_meter = get_node("Container/AlcoholMeterPanel/AlcoholMeter")
	alcohol_stage_label = get_node("Container/AlcoholMeterPanel/AlcoholStageLabel")
	cash_label = get_node("Container/TopRight/CashLabel")
	clock_label = get_node("Container/TopRight/ClockLabel")
	warning_label = get_node("Container/WarningText/WarningLabel")
	warning_control = get_node("Container/WarningText")
	
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
	
	# Initialize visuals
	update_alcohol_display()
	update_cash_display()
	
	print("HUD initialized")

func _on_alcohol_changed(value: float, stage: int):
	update_alcohol_display()

func _on_stage_changed(new_stage: int):
	# Update meter color based on stage
	var colors = {
		0: Color.WHITE,
		1: Color.GREEN,
		2: Color.ORANGE,
		3: Color.RED,
		4: Color.BLACK
	}
	
	if colors.has(new_stage):
		alcohol_meter.modulate = colors[new_stage]
		
	if alcohol_system and alcohol_system.has_method("get_stage_name"):
		alcohol_stage_label.text = alcohol_system.get_stage_name()
	
	# Show warning at Stage 4
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

func update_alcohol_display():
	var value = 0.0
	if alcohol_system and "alcohol" in alcohol_system:
		value = alcohol_system.alcohol
	alcohol_meter.max_value = 1.0
	alcohol_meter.value = value

func update_cash_display():
	# TODO: Get cash from GameManager
	var cash = 0
	if game_manager and "cash" in game_manager:
		cash = game_manager.cash
	cash_label.text = "Cash: $%d" % cash

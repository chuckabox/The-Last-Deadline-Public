extends Control

# Pour State
var liquid_level = 0.0  # 0.0 (empty) to 1.0 (full)
var target_line_position = 0.5  # 0.0 to 1.0
var is_pouring = false
var has_poured = false

# Parameters
var target_line_speed = 1.0
var tolerance = 0.1  # ±10%
var difficulty_stage = 0

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
	update_target_line()
	
	# Pour if holding spacebar
	if is_pouring:
		liquid_level = min(1.0, liquid_level + 0.5 * delta)
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

func play_sound(sound_name: String):
	# TODO: Play SFX
	pass

extends Control

# Slider properties
var slider_position = 0.0
var slider_speed = 1.0  # Normalized (0.0 to 1.0) per second
var slider_direction = 1.0
var slider_width = 300.0
var target_zone_start = 0.4
var target_zone_end = 0.6
var target_zone_width = 0.2

# Game State
var cups_sunk = 0
var max_cups = 3
var is_active = true
var difficulty_stage = 0

# Difficulty Effects
var stutter_timer = 0.0
var sway_timer = 0.0

# References
var slider_bar: ColorRect
var target_zone: ColorRect
var slider_indicator: ColorRect
var cups_label: Label
var instruction_label: Label
var alcohol_system: Node

# Signals
signal minigame_won(cash_reward)
signal minigame_lost()

func _ready():
	# Get references
	slider_bar = get_node_or_null("SliderPanel/SliderBar")
	target_zone = get_node_or_null("SliderPanel/TargetZone")
	slider_indicator = get_node_or_null("SliderPanel/SliderIndicator")
	cups_label = get_node_or_null("CupsLabel")
	instruction_label = get_node_or_null("InstructionLabel")
	
	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	if alcohol_system and "current_stage" in alcohol_system:
		difficulty_stage = alcohol_system.current_stage
	
	# Adjust difficulty
	adjust_difficulty()
	
	instruction_label.text = "Press SPACEBAR when slider is in the green zone!"
	print("Beer Pong mini-game started")

func _physics_process(delta):
	if not is_active:
		return
	
	# Handle Stage 3 Hiccup (Random stutter)
	if difficulty_stage >= 3:
		stutter_timer -= delta
		if stutter_timer > 0:
			return # Pause movement
		
		if randf() < 0.01: # 1% chance per frame to stutter
			stutter_timer = 0.15
			return
	
	# Handle Stage 4 Sway (Variable speed)
	var speed_multiplier = 1.0
	if difficulty_stage >= 4:
		sway_timer += delta
		speed_multiplier = 1.0 + sin(sway_timer * 6.0) * 0.6
	
	# Move slider
	slider_position += (slider_speed * speed_multiplier * slider_direction * delta)
	
	# Bounce at edges
	if slider_position > 1.0:
		slider_position = 1.0
		slider_direction = -1.0
	elif slider_position < 0.0:
		slider_position = 0.0
		slider_direction = 1.0
	
	# Update visuals
	if slider_indicator:
		slider_indicator.position.x = slider_position * slider_width
	
	if target_zone:
		# Keep target zone updated based on difficulty variables
		target_zone.position.x = target_zone_start * slider_width
		target_zone.size.x = (target_zone_end - target_zone_start) * slider_width

func _input(event):
	if not is_active:
		return
	
	if event.is_action_pressed("ui_select"): # Spacebar
		check_throw()

func check_throw():
	# Check if slider is in target zone
	if slider_position >= target_zone_start and slider_position <= target_zone_end:
		# Hit!
		cups_sunk += 1
		if cups_label:
			cups_label.text = "%d/%d" % [cups_sunk, max_cups]
		play_sound("cup_sink")
		
		# Visual feedback
		if target_zone:
			target_zone.modulate = Color.GREEN
			var tween = create_tween()
			tween.tween_property(target_zone, "modulate", Color.WHITE, 0.3)
		
		if cups_sunk >= max_cups:
			win_minigame()
	else:
		# Miss
		play_sound("rim_bounce")
		is_active = false
		
		if slider_indicator:
			slider_indicator.modulate = Color.RED
			
		await get_tree().create_timer(1.0).timeout
		lose_minigame()

func adjust_difficulty():
	# Scale by alcohol stage
	match difficulty_stage:
		0:
			slider_speed = 1.0
			target_zone_start = 0.4
			target_zone_end = 0.6
		1:
			slider_speed = 1.3
			target_zone_start = 0.4
			target_zone_end = 0.6
		2:
			slider_speed = 1.5
			target_zone_start = 0.35
			target_zone_end = 0.55
		3:
			slider_speed = 1.7
			target_zone_start = 0.35
			target_zone_end = 0.55
		4:
			slider_speed = 2.0
			target_zone_start = 0.3
			target_zone_end = 0.45
	
	target_zone_width = target_zone_end - target_zone_start

func win_minigame():
	is_active = false
	var cash_reward = 100 + (difficulty_stage * 50)
	print("Beer Pong WON! Cash: $%d" % cash_reward)
	emit_signal("minigame_won", cash_reward)

func lose_minigame():
	is_active = false
	print("Beer Pong LOST! Alcohol +1")
	emit_signal("minigame_lost")
	
	# Notify GameManager for global ending checks
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.minigame_lost.emit()

func play_sound(sound_name: String):
	# TODO: Play SFX via AudioManager
	pass

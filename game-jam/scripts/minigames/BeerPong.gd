extends Control

# Slider properties
var slider_position = 0.0
var slider_speed = 1.0  # Normalized (0.0 to 1.0) per second
var base_slider_speed = 1.0  # Speed before per-cup scaling
var slider_direction = 1.0
var slider_width = 300.0
var target_zone_start = 0.4
var target_zone_end = 0.6
var target_zone_width = 0.2
var base_zone_center = 0.5  # Center of target zone before drift

# Game State
var cups_sunk = 0
var max_cups = 3
var is_active = true
var difficulty_stage = 0

# Difficulty Effects
var stutter_timer = 0.0
var sway_timer = 0.0
var drift_timer = 0.0
var sway_tween: Tween

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
	
	# Handle Stage 4: Cups drift L/R (target zone oscillates)
	if difficulty_stage >= 4:
		drift_timer += delta
		var drift_offset = sin(drift_timer * 2.0) * 0.15
		var half_width = target_zone_width / 2.0
		target_zone_start = clampf(base_zone_center + drift_offset - half_width, 0.0, 1.0 - target_zone_width)
		target_zone_end = target_zone_start + target_zone_width
	
	# Move slider
	slider_position += (slider_speed * slider_direction * delta)
	
	# Bounce at edges
	if slider_position > 1.0:
		slider_position = 1.0
		slider_direction = -1.0
	elif slider_position < 0.0:
		slider_position = 0.0
		slider_direction = 1.0
	
	# Stage 1+: Camera sway
	if difficulty_stage >= 1:
		sway_timer += delta
		var sway_amount = sin(sway_timer * 3.0) * 3.0
		rotation_degrees = sway_amount
	
	# Update visuals
	if slider_indicator:
		slider_indicator.position.x = slider_position * slider_width
	
	if target_zone:
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
		
		# Bar gets faster after each cup
		slider_speed = base_slider_speed * (1.0 + cups_sunk * 0.15)
		
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
	# Base zone: 0.2 wide centered at 0.5
	target_zone_width = 0.20
	base_zone_center = 0.5
	base_slider_speed = 1.0
	
	# Stage 1: 15% faster
	if difficulty_stage >= 1:
		base_slider_speed = 1.15
	
	# Stage 2: Zone shrinks 30%
	if difficulty_stage >= 2:
		target_zone_width *= 0.70  # 0.20 → 0.14
		base_slider_speed = 1.3
	
	if difficulty_stage >= 3:
		base_slider_speed = 1.5
	
	if difficulty_stage >= 4:
		base_slider_speed = 1.7
		target_zone_width *= 0.85  # Shrink a bit more
	
	slider_speed = base_slider_speed
	target_zone_start = base_zone_center - target_zone_width / 2.0
	target_zone_end = base_zone_center + target_zone_width / 2.0

func win_minigame():
	is_active = false
	var cash_reward = 100 + (difficulty_stage * 50)
	print("Beer Pong WON! Cash: $%d" % cash_reward)
	$Path2D.play_arc_animation()
	emit_signal("minigame_won", cash_reward)

func lose_minigame():
	is_active = false
	$Path2D2.play_arc_animation()
	await get_tree().create_timer(2.0).timeout
	$Path2D3.play_arc_animation()
	print("Beer Pong LOST! Alcohol +1")
	emit_signal("minigame_lost")
	
	# Notify GameManager for global ending checks
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.minigame_lost.emit()

func play_sound(sound_name: String):
	# TODO: Play SFX via AudioManager
	pass

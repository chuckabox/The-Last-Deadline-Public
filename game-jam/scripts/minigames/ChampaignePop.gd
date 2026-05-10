extends Control

# Game State
var pressure = 0.0  # 0.0 to 1.0
var perfect_zone_position = 0.7
var perfect_zone_width = 0.15
var is_released = false
var difficulty_stage = 0

# Difficulty effect state
var zone_target = 0.7  # For random zone movement (stage 2)
var zone_move_cooldown = 0.0
var shake_intensity = 0.0
var transparent_timer = 0.0
var is_transparent_pulse = false
var base_position: Vector2

# References
var bottle_sprite: Sprite2D
var pressure_fill: ColorRect
var perfect_zone: ColorRect
var meter_panel: Panel
var instruction_label: Label
var status_label: Label
var alcohol_system: Node

# Signals
signal minigame_won(cash_reward)
signal minigame_lost()

func _ready():
	# Get references
	bottle_sprite = get_node_or_null("BottleSprite")
	meter_panel = get_node_or_null("MeterPanel")
	if meter_panel:
		pressure_fill = meter_panel.get_node_or_null("PressureFill")
		perfect_zone = meter_panel.get_node_or_null("PerfectZone")
	instruction_label = get_node_or_null("InstructionLabel")
	status_label = get_node_or_null("StatusLabel")
	
	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	if alcohol_system and "current_stage" in alcohol_system:
		difficulty_stage = alcohol_system.current_stage
	
	if instruction_label:
		instruction_label.text = "SPAM SPACEBAR to build pressure, release in the green zone!"
	
	# Store base position for shake effects
	if meter_panel:
		base_position = meter_panel.position
	
	print("Champagne Pop mini-game started")

func _physics_process(delta):
	if is_released:
		return
		
	# Update perfect zone position based on difficulty stage
	if difficulty_stage == 0:
		# Stage 0: Steady, wide, centered zone
		perfect_zone_position = 0.7
	elif difficulty_stage == 1:
		# Stage 1: Slow sinusoidal movement
		var zone_speed = 0.005
		perfect_zone_position = 0.65 + sin(Time.get_ticks_msec() * zone_speed) * 0.15
	elif difficulty_stage >= 2:
		# Stage 2+: Zone moves randomly (lerp toward random targets)
		zone_move_cooldown -= delta
		if zone_move_cooldown <= 0:
			zone_target = randf_range(0.45, 0.85)
			zone_move_cooldown = randf_range(0.6, 1.5)
		var lerp_speed = 2.0 + difficulty_stage * 0.5
		perfect_zone_position = lerpf(perfect_zone_position, zone_target, lerp_speed * delta)
	
	# Stage 1+: UI shake
	if difficulty_stage >= 1 and meter_panel:
		shake_intensity = 2.0 + difficulty_stage * 1.0
		# Stage 4: Violent shake
		if difficulty_stage >= 4:
			shake_intensity = 8.0
		meter_panel.position = base_position + Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
	
	# Stage 4: UI pulses transparent
	if difficulty_stage >= 4:
		transparent_timer -= delta
		if transparent_timer <= 0:
			is_transparent_pulse = not is_transparent_pulse
			transparent_timer = randf_range(0.3, 0.7)
		modulate.a = 0.3 if is_transparent_pulse else 1.0
	
	# Update meter visuals
	update_meter()
	
	# Pressure decay if not mashing (faster at higher stages)
	var decay_rate = 0.08 + (difficulty_stage * 0.03)
	if pressure > 0.0:
		pressure = max(0.0, pressure - decay_rate * delta)

func _input(event):
	if is_released:
		return
	
	if event.is_action_pressed("ui_select"): # Spacebar
		# Mash adds pressure
		# Stage 1+: 10% more mashes needed (reduce gain by ~10% per stage)
		var pressure_gain = max(0.02, 0.09 - (difficulty_stage * 0.009))
		pressure = min(1.0, pressure + pressure_gain)
		if status_label:
			status_label.text = "Pressure: %.0f%%" % (pressure * 100)
		
		# Visual feedback on bottle (shake)
		if bottle_sprite:
			bottle_sprite.position = Vector2(320 + randf_range(-3, 3), 240 + randf_range(-3, 3))
		
		# Check for overpressure
		if pressure >= 1.0:
			is_released = true
			lose_minigame("EXPLODED!")
			
	elif event.is_action_released("ui_select"):
		if pressure > 0.15: # Threshold to prevent accidental immediate release
			is_released = true
			check_pop_accuracy()

func update_meter():
	if not meter_panel or not pressure_fill or not perfect_zone: return
	
	# Update pressure fill
	var fill_width = meter_panel.size.x * pressure
	pressure_fill.size.x = fill_width
	
	# Update perfect zone position
	var zone_x = meter_panel.size.x * (perfect_zone_position - perfect_zone_width / 2)
	var zone_width = meter_panel.size.x * perfect_zone_width
	perfect_zone.position.x = zone_x
	perfect_zone.size.x = zone_width

func check_pop_accuracy():
	var half_width = perfect_zone_width / 2.0
	var diff = abs(pressure - perfect_zone_position)
	
	if diff <= half_width:
		# Success!
		var accuracy = 1.0 - (diff / half_width)
		var cash_reward = int(150 + (accuracy * 100) + (difficulty_stage * 50))
		if status_label:
			status_label.text = "POPPED! Accuracy: %.0f%%" % (accuracy * 100)
			status_label.add_theme_color_override("font_color", Color.GREEN)
		print("Champagne Pop WON! Accuracy: %.0f%%, Cash: $%d" % [accuracy * 100, cash_reward])
		emit_signal("minigame_won", cash_reward)
	else:
		# Failure
		var msg = "TOO WEAK!" if pressure < perfect_zone_position else "MISSED ZONE!"
		lose_minigame(msg)

func lose_minigame(reason: String):
	if status_label:
		status_label.text = reason
		status_label.add_theme_color_override("font_color", Color.RED)
	print("Champagne Pop LOST! %s" % reason)
	
	# Check if this node is still in the tree before emitting signals.
	# The EndingManager may trigger a scene change (e.g. blackout) which
	# frees nodes mid-signal-chain and causes a crash.
	if not is_inside_tree():
		return
	
	emit_signal("minigame_lost")
	
	# Notify GameManager for global ending checks
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.minigame_lost.emit()

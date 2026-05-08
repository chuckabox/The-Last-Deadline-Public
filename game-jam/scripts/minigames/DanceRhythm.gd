extends Control

# Game State
var combo = 0
var crowd_energy = 0.5  # Start at middle
var is_active = true
var difficulty_stage = 0
var bpm = 110
var beat_interval = 60.0 / 110.0
var time_since_last_beat = 0.0

# Arrow Spawn
var falling_arrows = []
var spawn_rate = 0.6  # seconds between arrows
var last_spawn_time = 0.0

# References
var arrow_container: Node2D
var crowd_energy_bar: ProgressBar
var combo_label: Label
var instruction_label: Label
var hit_zone: ColorRect
var pulse_overlay: ColorRect
var alcohol_system: Node
var game_manager: Node
var sfx_manager: Node

# Signals
signal minigame_won(cash_reward)
signal minigame_lost()

func _ready():
	# Get references
	arrow_container = get_node_or_null("ArrowContainer")
	crowd_energy_bar = get_node_or_null("CrowdEnergyBar")
	combo_label = get_node_or_null("ComboLabel")
	instruction_label = get_node_or_null("InstructionLabel")
	hit_zone = get_node_or_null("HitZone")
	pulse_overlay = get_node_or_null("PulseOverlay")
	
	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	game_manager = get_node_or_null("/root/GameManager")
	sfx_manager = get_node_or_null("/root/SFXManager")
	
	if alcohol_system and "current_stage" in alcohol_system:
		difficulty_stage = alcohol_system.current_stage
	
	# Adjust difficulty
	adjust_difficulty()
	beat_interval = 60.0 / bpm
	
	if instruction_label:
		instruction_label.text = "Keep the rhythm! Match the arrows!"
		if difficulty_stage >= 3:
			instruction_label.text += "\nAVOID THE RED GHOST ARROWS!"
	
	if crowd_energy_bar:
		crowd_energy_bar.max_value = 1.0
		crowd_energy_bar.value = crowd_energy
		
	print("Dance Rhythm mini-game started - Stage: %d" % difficulty_stage)

func _physics_process(delta):
	if not is_active:
		return
	
	# Handle beats for Stage 4 pulse
	time_since_last_beat += delta
	if time_since_last_beat >= beat_interval:
		time_since_last_beat -= beat_interval
		trigger_beat_pulse()
	
	# Smoothly fade out pulse overlay
	if pulse_overlay:
		pulse_overlay.modulate.a = lerp(pulse_overlay.modulate.a, 0.0, delta * 10.0)
	
	# Spawn arrows
	last_spawn_time += delta
	if last_spawn_time >= spawn_rate:
		spawn_arrow()
		last_spawn_time = 0.0
	
	# Update falling arrows
	var arrows_to_remove = []
	var fall_speed = 250.0 + (difficulty_stage * 40.0)
	
	for arrow in falling_arrows:
		arrow.position.y += fall_speed * delta
		
		# Stage 2: Rotating arrows
		if difficulty_stage >= 2:
			var rotation_speed = 2.0 + (difficulty_stage * 0.5)
			arrow.rotation += rotation_speed * delta
		
		# Remove if past hit zone
		var limit = (hit_zone.position.y + 80) if hit_zone else 600.0
		if arrow.position.y > limit:
			arrows_to_remove.append(arrow)
			# Only penalize if not a ghost arrow
			if not arrow.get_meta("is_ghost"):
				miss_arrow()

	for arrow in arrows_to_remove:
		falling_arrows.erase(arrow)
		arrow.queue_free()

func trigger_beat_pulse():
	# Stage 4: Screen pulses black on bass beats
	if difficulty_stage >= 4 and pulse_overlay:
		pulse_overlay.modulate.a = 0.95
	
	# Visual feedback on hit zone
	if hit_zone:
		var tween = create_tween()
		tween.tween_property(hit_zone, "scale", Vector2(1.1, 1.1), 0.05)
		tween.tween_property(hit_zone, "scale", Vector2(1.0, 1.0), 0.05)

func spawn_arrow():
	if not arrow_container: return
	
	var directions = [0, 1, 2, 3]  # Up, Down, Left, Right
	var direction = directions[randi() % directions.size()]
	
	var is_ghost = false
	# Stage 3: Ghost arrows (15% chance)
	if difficulty_stage >= 3:
		if randf() < 0.15:
			is_ghost = true
	
	var arrow = Control.new() # Using Control for rotation pivot center
	arrow.custom_minimum_size = Vector2(50, 50)
	arrow.pivot_offset = Vector2(25, 25)
	
	var rect = ColorRect.new()
	rect.size = Vector2(50, 50)
	rect.color = Color.RED if is_ghost else Color.CYAN
	arrow.add_child(rect)
	
	# Column positioning
	arrow.position.x = 80 + direction * 100
	arrow.position.y = -100
	
	# Add direction indicator
	var label = Label.new()
	var dir_names = ["^", "v", "<", ">"]
	label.text = dir_names[direction]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", Color.BLACK)
	arrow.add_child(label)
	
	# Store metadata
	arrow.set_meta("direction", direction)
	arrow.set_meta("is_ghost", is_ghost)
	
	arrow_container.add_child(arrow)
	falling_arrows.append(arrow)

func _input(event):
	if not is_active:
		return
	
	var direction = -1
	
	if event.is_action_pressed("ui_up"): direction = 0
	elif event.is_action_pressed("ui_down"): direction = 1
	elif event.is_action_pressed("ui_left"): direction = 2
	elif event.is_action_pressed("ui_right"): direction = 3
	
	if direction != -1:
		check_hit(direction)

func check_hit(direction: int):
	# Find closest arrow in its respective column
	var closest_arrow = null
	var closest_distance = 120.0
	
	if not hit_zone: return
	
	for arrow in falling_arrows:
		if arrow.get_meta("direction") == direction:
			var distance = abs(arrow.position.y - hit_zone.position.y)
			if distance < closest_distance:
				closest_distance = distance
				closest_arrow = arrow
	
	# Hit detection
	if closest_arrow and closest_distance < 60:
		if closest_arrow.get_meta("is_ghost"):
			# HIT A GHOST ARROW! (BAD)
			if sfx_manager: sfx_manager.play_sfx("error")
			miss_arrow()
			falling_arrows.erase(closest_arrow)
			closest_arrow.queue_free()
		else:
			# Successful hit
			combo += 1
			crowd_energy = min(1.0, crowd_energy + 0.06 + (combo * 0.002))
			if sfx_manager: sfx_manager.play_sfx("menu_scroll", 0.0, 1.2)
			
			falling_arrows.erase(closest_arrow)
			closest_arrow.queue_free()
			
			if crowd_energy >= 1.0:
				win_minigame()
	else:
		# Pressed button but no matching arrow nearby
		miss_arrow()
	
	update_visuals()

func miss_arrow():
	combo = 0
	crowd_energy = max(0.0, crowd_energy - 0.12)
	if sfx_manager: sfx_manager.play_sfx("menu_scroll", 0.0, 0.8)
	
	if crowd_energy <= 0.0:
		lose_minigame()
	update_visuals()

func update_visuals():
	if crowd_energy_bar:
		crowd_energy_bar.value = crowd_energy
	if combo_label:
		combo_label.text = "COMBO: %d" % combo

func adjust_difficulty():
	match difficulty_stage:
		0: bpm = 110; spawn_rate = 0.7
		1: bpm = 125; spawn_rate = 0.6
		2: bpm = 130; spawn_rate = 0.55
		3: bpm = 140; spawn_rate = 0.5
		4: bpm = 155; spawn_rate = 0.45

func win_minigame():
	is_active = false
	if sfx_manager: sfx_manager.play_sfx("sequence_correct")
	
	# Reward VIP Pass logic
	if game_manager:
		game_manager.mark_npc_completed("dj")
	
	var cash_reward = 200 + (difficulty_stage * 50)
	print("Dance Rhythm WON! VIP Pass acquired. Cash: $%d" % cash_reward)
	emit_signal("minigame_won", cash_reward)

func lose_minigame():
	if not is_active: return
	is_active = false
	
	if sfx_manager: sfx_manager.play_sfx("error")
	
	# Increase alcohol penalty
	if alcohol_system and alcohol_system.has_method("drink_alcohol"):
		alcohol_system.drink_alcohol(20) # Forced shot
	
	print("Dance Rhythm LOST! Alcohol +1 stage potential")
	emit_signal("minigame_lost")
	
	# Notify GameManager for global ending checks
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.minigame_lost.emit()

func get_bpm_multiplier() -> float:
	return bpm / 110.0

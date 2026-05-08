extends Control

# Game State
var combo = 0
var crowd_energy = 0.0  # 0.0 to 1.0
var is_active = true
var difficulty_stage = 0
var bpm = 110

# Arrow Spawn
var falling_arrows = []
var spawn_rate = 0.5  # seconds between arrows
var last_spawn_time = 0.0

# References
var arrow_container: Node2D
var crowd_energy_bar: ProgressBar
var combo_label: Label
var instruction_label: Label
var hit_zone: ColorRect
var alcohol_system: Node

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
	
	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	if alcohol_system and "current_stage" in alcohol_system:
		difficulty_stage = alcohol_system.current_stage
	
	# Adjust difficulty
	adjust_difficulty()
	
	if instruction_label:
		instruction_label.text = "Press arrow keys to match the falling arrows!"
	
	if crowd_energy_bar:
		crowd_energy_bar.max_value = 1.0
		crowd_energy_bar.value = 0.0
		
	print("Dance Rhythm mini-game started")

func _physics_process(delta):
	if not is_active:
		return
	
	# Spawn arrows
	last_spawn_time += delta
	if last_spawn_time >= spawn_rate:
		spawn_arrow()
		last_spawn_time = 0.0
	
	# Update falling arrows
	var arrows_to_remove = []
	var fall_speed = 200.0 + (difficulty_stage * 30.0)
	
	for arrow in falling_arrows:
		arrow.position.y += fall_speed * delta
		
		# Remove if past hit zone
		var limit = (hit_zone.position.y + 60) if hit_zone else 600.0
		if arrow.position.y > limit:
			arrows_to_remove.append(arrow)
			# Miss penalty
			combo = 0
			crowd_energy = max(0.0, crowd_energy - 0.08)
			update_visuals()

	for arrow in arrows_to_remove:
		falling_arrows.erase(arrow)
		arrow.queue_free()

func spawn_arrow():
	if not arrow_container: return
	
	var directions = [0, 1, 2, 3]  # Up, Down, Left, Right
	var direction = directions[randi() % directions.size()]
	
	var arrow = ColorRect.new()
	arrow.size = Vector2(40, 40)
	arrow.color = Color.CYAN
	
	# Column positioning
	arrow.position.x = 120 + direction * 130
	arrow.position.y = -50
	
	# Add direction indicator
	var label = Label.new()
	var dir_names = ["^", "v", "<", ">"]
	label.text = dir_names[direction]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.modulate = Color.BLACK
	arrow.add_child(label)
	
	# Store metadata
	arrow.set_meta("direction", direction)
	
	arrow_container.add_child(arrow)
	falling_arrows.append(arrow)

func _input(event):
	if not is_active:
		return
	
	var direction = -1
	
	if event.is_action_pressed("ui_up"):
		direction = 0
	elif event.is_action_pressed("ui_down"):
		direction = 1
	elif event.is_action_pressed("ui_left"):
		direction = 2
	elif event.is_action_pressed("ui_right"):
		direction = 3
	
	if direction != -1:
		check_hit(direction)

func check_hit(direction: int):
	# Find closest arrow with matching direction
	var closest_arrow = null
	var closest_distance = 150.0 # Search range
	
	if not hit_zone: return
	
	for arrow in falling_arrows:
		if arrow.get_meta("direction") == direction:
			var distance = abs(arrow.position.y - hit_zone.position.y)
			if distance < closest_distance:
				closest_distance = distance
				closest_arrow = arrow
	
	# Hit detection window
	if closest_arrow and closest_distance < 50:
		# Hit!
		combo += 1
		crowd_energy = min(1.0, crowd_energy + 0.05 + (combo * 0.001))
		falling_arrows.erase(closest_arrow)
		closest_arrow.queue_free()
		
		# Check win condition
		if crowd_energy >= 1.0:
			win_minigame()
	else:
		# Miss
		combo = 0
		crowd_energy = max(0.0, crowd_energy - 0.1)
	
	update_visuals()

func update_visuals():
	if crowd_energy_bar:
		crowd_energy_bar.value = crowd_energy
	if combo_label:
		combo_label.text = "Combo: %d" % combo

func adjust_difficulty():
	match difficulty_stage:
		0: bpm = 110; spawn_rate = 0.6
		1: bpm = 125; spawn_rate = 0.5
		2: bpm = 135; spawn_rate = 0.45
		3: bpm = 145; spawn_rate = 0.4
		4: bpm = 165; spawn_rate = 0.3

func win_minigame():
	is_active = false
	var cash_reward = 150 + (difficulty_stage * 50)
	print("Dance Rhythm WON! Cash: $%d" % cash_reward)
	emit_signal("minigame_won", cash_reward)

func lose_minigame():
	is_active = false
	print("Dance Rhythm LOST! Alcohol +1")
	emit_signal("minigame_lost")

func play_sound(sound_name: String):
	# TODO: Play SFX via AudioManager
	pass

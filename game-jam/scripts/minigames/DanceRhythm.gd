extends Control

# Game State
var combo = 0
var crowd_energy = 0.5
var is_active = true
var difficulty_stage = 0
var bpm = 110
var beat_interval = 60.0 / 110.0
var time_since_last_beat = 0.0

# Spawn timing
var spawn_rate = 0.7
var last_spawn_time = 0.0

# Rail distances from player centre
const RAIL_DISTANCE = 280.0
const HIT_DISTANCE = 55.0

# Directions: 0=Up, 1=Down, 2=Left, 3=Right
const DIRECTION_VECTORS = {
	0: Vector2(0, -1),
	1: Vector2(0, 1),
	2: Vector2(-1, 0),
	3: Vector2(1, 0)
}
const DIRECTION_ACTIONS = {
	0: "ui_up",
	1: "ui_down",
	2: "ui_left",
	3: "ui_right"
}
# Maps direction to frame index: 1=left, 2=right, 3=up, 4=down
const DIRECTION_FRAMES = {
	0: 3,
	1: 4,
	2: 1,
	3: 2
}

# Active silhouettes: { node, direction, distance, is_ghost }
var active_silhouettes = []

# References
var rails: Node2D
var player_sprite: AnimatedSprite2D
var crowd_energy_bar: ProgressBar
var combo_label: Label
var instruction_label: Label
var hit_zone_visual: ColorRect
var pulse_overlay: ColorRect
var alcohol_system: Node
var game_manager: Node
var sfx_manager: Node

# Signals
signal minigame_won(cash_reward)
signal minigame_lost()

func _ready():
	rails = get_node_or_null("Rails")
	player_sprite = get_node_or_null("PlayerSprite")
	hit_zone_visual = get_node_or_null("HitZoneVisual")
	crowd_energy_bar = get_node_or_null("UI/CrowdEnergyBar")
	combo_label = get_node_or_null("UI/ComboLabel")
	instruction_label = get_node_or_null("UI/InstructionLabel")
	pulse_overlay = get_node_or_null("UI/PulseOverlay")

	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	game_manager = get_node_or_null("/root/GameManager")
	sfx_manager = get_node_or_null("/root/SFXManager")

	if alcohol_system and "current_stage" in alcohol_system:
		difficulty_stage = alcohol_system.current_stage

	adjust_difficulty()
	beat_interval = 60.0 / bpm

	if crowd_energy_bar:
		crowd_energy_bar.max_value = 1.0
		crowd_energy_bar.value = crowd_energy

	if player_sprite:
		player_sprite.frame = 0

	print("Dance Rhythm started — Stage: %d, BPM: %d" % [difficulty_stage, bpm])

func _physics_process(delta):
	if not is_active:
		return

	# Beat pulse timer
	time_since_last_beat += delta
	if time_since_last_beat >= beat_interval:
		time_since_last_beat -= beat_interval
		trigger_beat_pulse()

	# Fade pulse overlay
	if pulse_overlay:
		pulse_overlay.modulate.a = lerp(pulse_overlay.modulate.a, 0.0, delta * 10.0)

	# Spawn silhouettes
	last_spawn_time += delta
	if last_spawn_time >= spawn_rate:
		spawn_silhouette()
		last_spawn_time = 0.0

	# Move silhouettes inward
	var fall_speed = 200.0 + (difficulty_stage * 40.0)
	var to_remove = []

	for s in active_silhouettes:
		s["distance"] -= fall_speed * delta
		var dir_vec = DIRECTION_VECTORS[s["direction"]]
		s["node"].position = dir_vec * s["distance"]

		# Stage 2: slight rotation as it approaches
		if difficulty_stage >= 2:
			s["node"].rotation += 0.5 * delta

		# Missed — passed through player
		if s["distance"] <= 0:
			to_remove.append(s)
			if not s.get("is_ghost", false):
				miss_silhouette()

	for s in to_remove:
		active_silhouettes.erase(s)
		s["node"].queue_free()

func _input(event):
	if not is_active:
		return

	for direction in DIRECTION_ACTIONS.keys():
		if event.is_action_pressed(DIRECTION_ACTIONS[direction]):
			check_hit(direction)
			break

func check_hit(direction: int):
	var closest = null
	var closest_dist = HIT_DISTANCE + 20.0

	for s in active_silhouettes:
		if s["direction"] == direction:
			var dist_from_player = abs(s["distance"])
			if dist_from_player < closest_dist:
				closest_dist = dist_from_player
				closest = s

	if closest and closest_dist <= HIT_DISTANCE:
		if closest.get("is_ghost", false):
			miss_silhouette()
			active_silhouettes.erase(closest)
			closest["node"].queue_free()
		else:
			combo += 1
			crowd_energy = min(1.0, crowd_energy + 0.06 + (combo * 0.002))

			if player_sprite:
				player_sprite.frame = DIRECTION_FRAMES[direction]

			if sfx_manager:
				sfx_manager.play_sfx("pose_match")

			active_silhouettes.erase(closest)
			closest["node"].queue_free()

			# Return to idle after short delay
			var tween = create_tween()
			tween.tween_interval(0.2)
			tween.tween_callback(func(): if player_sprite: player_sprite.frame = 0)

			if crowd_energy >= 1.0:
				win_minigame()
	else:
		miss_silhouette()

	update_visuals()

func miss_silhouette():
	combo = 0
	crowd_energy = max(0.0, crowd_energy - 0.12)
	if sfx_manager:
		sfx_manager.play_sfx("pose_miss")
	if crowd_energy <= 0.0:
		lose_minigame()
	update_visuals()

func spawn_silhouette():
	if not rails:
		return

	var direction = randi() % 4

	var is_ghost = false
	if difficulty_stage >= 3 and randf() < 0.15:
		is_ghost = true

	var silhouette = Sprite2D.new()

	if player_sprite and player_sprite.sprite_frames:
		var frames = player_sprite.sprite_frames
		if frames.has_animation("default"):
			var frame_index = DIRECTION_FRAMES[direction]
			silhouette.texture = frames.get_frame_texture("default", frame_index)

	silhouette.modulate = Color(1, 0, 0, 0.7) if is_ghost else Color(0.15, 0.15, 0.15, 0.85)
	silhouette.scale = Vector2(1.5, 1.5)

	var rail_names = ["RailUp", "RailDown", "RailLeft", "RailRight"]
	var rail = rails.get_node_or_null(rail_names[direction])
	if not rail:
		silhouette.queue_free()
		return

	rail.add_child(silhouette)

	var dir_vec = DIRECTION_VECTORS[direction]
	silhouette.position = dir_vec * RAIL_DISTANCE

	active_silhouettes.append({
		"node": silhouette,
		"direction": direction,
		"distance": RAIL_DISTANCE,
		"is_ghost": is_ghost
	})

func trigger_beat_pulse():
	if difficulty_stage >= 4 and pulse_overlay:
		pulse_overlay.modulate.a = 0.9

	if hit_zone_visual:
		var tween = create_tween()
		tween.tween_property(hit_zone_visual, "modulate:a", 0.3, 0.05)
		tween.tween_property(hit_zone_visual, "modulate:a", 0.05, 0.1)

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
	if sfx_manager:
		sfx_manager.play_sfx("sequence_correct")
	if game_manager:
		game_manager.mark_npc_completed("dj")
	print("Dance Rhythm WON!")
	emit_signal("minigame_won", 0)

func lose_minigame():
	if not is_active:
		return
	is_active = false
	if sfx_manager:
		sfx_manager.play_sfx("error")
	if alcohol_system and alcohol_system.has_method("drink_alcohol"):
		alcohol_system.drink_alcohol(0.2)
	print("Dance Rhythm LOST!")
	emit_signal("minigame_lost")
	if game_manager:
		game_manager.minigame_lost.emit()

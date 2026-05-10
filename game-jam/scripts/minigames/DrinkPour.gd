extends Control

# Tutorial State
var tutorial_active = true
var tutorial_overlay: ColorRect

# Game State
var lives = 1
var round_active = false

# Line (player-controlled, 0.0 = bottom, 1.0 = top of glass)
var line_position = 0.5
var line_velocity = 0.0
const LINE_PUSH_FORCE = 5.0      # upward acceleration while holding SPACE (must exceed gravity)
const LINE_GRAVITY = 3.0         # constant downward acceleration; net up while held = +2.0, fall = -3.0
const LINE_MAX_SPEED = 1.4

# Highlighted band (target, moves on its own)
var band_center = 0.5
var band_velocity = 0.0
var band_half_height = 0.12      # band spans [center - half, center + half]
var band_drift_timer = 0.0
var band_target_velocity = 0.0
var band_burst_cooldown = 0.0

# Score %
var score_percent = 50.0
const SCORE_GAIN_PER_SEC = 22.0
const SCORE_LOSS_PER_SEC = 18.0

# Difficulty
var difficulty_stage = 0

# Glass config (single round now)
const GLASS_W = 160.0
const GLASS_H = 360.0
const GLASS_COLOR = Color(0.8, 0.9, 1.0, 0.15)
const LIQUID_COLOR = Color(0.9, 0.6, 0.1, 0.85)

# References
var glass: ColorRect
var liquid: ColorRect              # repurposed: shows fill up to line_position (visual only)
var target_band: ColorRect         # NEW: highlighted band the player chases
var player_line: ColorRect         # NEW: thin line the player controls
var glass_label: Label
var instruction_label: Label
var feedback_label: Label
var victory_label: Label
var score_bar_bg: ColorRect
var score_bar_fill: ColorRect
var score_label: Label
var lives_label: Label
var confetti: CPUParticles2D
var alcohol_system: Node
var sfx_manager: Node
var game_manager: Node

signal minigame_won(cash_reward)
signal minigame_lost()

func _ready():
	glass = get_node_or_null("Glass")
	if glass:
		liquid = glass.get_node_or_null("Liquid")
		target_band = glass.get_node_or_null("TargetBand")
		player_line = glass.get_node_or_null("PlayerLine")
		glass_label = glass.get_node_or_null("GlassLabel")

	instruction_label = get_node_or_null("InstructionLabel")
	feedback_label = get_node_or_null("FeedbackLabel")
	victory_label = get_node_or_null("VictoryLabel")
	score_bar_bg = get_node_or_null("ScoreBarBG")
	if score_bar_bg:
		score_bar_fill = score_bar_bg.get_node_or_null("ScoreBarFill")
	score_label = get_node_or_null("ScoreLabel")
	lives_label = get_node_or_null("LivesLabel")
	confetti = get_node_or_null("Confetti")
	tutorial_overlay = get_node_or_null("TutorialOverlay")

	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	sfx_manager = get_node_or_null("/root/SFXManager")
	game_manager = get_node_or_null("/root/GameManager")

	if alcohol_system and "current_stage" in alcohol_system:
		difficulty_stage = alcohol_system.current_stage

	tutorial_active = true
	if tutorial_overlay:
		tutorial_overlay.show()

	var start_prompt = get_node_or_null("TutorialOverlay/TutorialPanel/StartPrompt")
	if start_prompt:
		var tween = create_tween().set_loops()
		tween.tween_property(start_prompt, "modulate:a", 0.2, 0.6)
		tween.tween_property(start_prompt, "modulate:a", 1.0, 0.6)

	print("Drink Pour started — Stage: %d" % difficulty_stage)

func _input(event):
	if tutorial_active:
		if event is InputEventKey and event.pressed and not event.echo:
			_dismiss_tutorial()
		return

func _dismiss_tutorial():
	tutorial_active = false
	if tutorial_overlay:
		var tween = create_tween()
		tween.tween_property(tutorial_overlay, "modulate:a", 0.0, 0.3)
		tween.tween_callback(tutorial_overlay.hide)
	start_round()

func start_round():
	round_active = true
	line_position = 0.5
	line_velocity = 0.0
	band_center = 0.5
	band_velocity = 0.0
	band_drift_timer = 0.0
	band_target_velocity = randf_range(-0.15, 0.15)
	band_burst_cooldown = randf_range(1.5, 3.0)
	score_percent = 50.0

	if glass:
		glass.size = Vector2(GLASS_W, GLASS_H)
		glass.position = Vector2(576 - GLASS_W / 2.0, 360 - GLASS_H / 2.0)
		glass.color = GLASS_COLOR

	if liquid:
		liquid.color = LIQUID_COLOR
		liquid.size = Vector2(GLASS_W, 0)
		liquid.position = Vector2(0, GLASS_H)

	if target_band:
		target_band.size = Vector2(GLASS_W, GLASS_H * band_half_height * 2.0)
		target_band.color = Color(0.4, 1.0, 0.5, 0.35)

	if player_line:
		player_line.size = Vector2(GLASS_W, 4)
		player_line.color = Color(1.0, 1.0, 1.0, 1.0)

	if glass_label:
		glass_label.text = "PINT"
		glass_label.size.x = GLASS_W

	update_ui()
	_update_visuals()

	if feedback_label:
		feedback_label.hide()
	if victory_label:
		victory_label.hide()

func _physics_process(delta):
	if tutorial_active or not round_active:
		return

	# Player line physics
	var holding = Input.is_action_pressed("ui_select")
	if holding:
		line_velocity += LINE_PUSH_FORCE * delta
	line_velocity -= LINE_GRAVITY * delta
	line_velocity = clamp(line_velocity, -LINE_MAX_SPEED, LINE_MAX_SPEED)
	line_position += line_velocity * delta

	# Floor/ceiling for line
	if line_position <= 0.0:
		line_position = 0.0
		line_velocity = max(0.0, line_velocity)
	elif line_position >= 1.0:
		line_position = 1.0
		line_velocity = min(0.0, line_velocity)

	# Band motion: smooth drift, occasional faster reverse burst
	band_drift_timer += delta
	band_burst_cooldown -= delta
	if band_burst_cooldown <= 0.0:
		# Sudden faster burst opposite to current direction
		var sign_dir = -1.0 if band_target_velocity >= 0.0 else 1.0
		band_target_velocity = sign_dir * randf_range(0.45, 0.7)
		band_burst_cooldown = randf_range(1.8, 3.5)
	else:
		# Gradual drift toward a gentle target
		if band_drift_timer > randf_range(0.8, 1.6):
			band_drift_timer = 0.0
			band_target_velocity = randf_range(-0.2, 0.2)

	# Smooth velocity toward target
	band_velocity = lerp(band_velocity, band_target_velocity, delta * 2.5)
	band_center += band_velocity * delta

	# Bounce band off edges (keep band fully visible)
	var min_c = band_half_height
	var max_c = 1.0 - band_half_height
	if band_center < min_c:
		band_center = min_c
		band_velocity = abs(band_velocity)
		band_target_velocity = abs(band_target_velocity)
	elif band_center > max_c:
		band_center = max_c
		band_velocity = -abs(band_velocity)
		band_target_velocity = -abs(band_target_velocity)

	# Score: in band → up, out of band → down
	var in_band = abs(line_position - band_center) <= band_half_height
	if in_band:
		score_percent += SCORE_GAIN_PER_SEC * delta
	else:
		score_percent -= SCORE_LOSS_PER_SEC * delta
	score_percent = clamp(score_percent, 0.0, 100.0)

	_update_visuals()
	update_ui()

	# Win / lose
	if score_percent >= 100.0:
		round_active = false
		play_win_celebration()
	elif score_percent <= 0.0:
		round_active = false
		_fail_round()

func _update_visuals():
	# Liquid fills up to line_position (visual filling)
	if liquid:
		liquid.size.y = GLASS_H * line_position
		liquid.position.y = GLASS_H * (1.0 - line_position)

	# Target band position (y grows downward; top of glass = y 0)
	if target_band:
		var band_top_norm = 1.0 - (band_center + band_half_height)
		target_band.position = Vector2(0, GLASS_H * band_top_norm)

	# Player line position
	if player_line:
		var line_y = GLASS_H * (1.0 - line_position) - 2.0
		player_line.position = Vector2(0, line_y)

	# Score bar fill width
	if score_bar_fill and score_bar_bg:
		var bar_w = score_bar_bg.size.x
		score_bar_fill.size.x = bar_w * (score_percent / 100.0)
		# Color shift: red <50, yellow ~50, green >50
		if score_percent < 33.0:
			score_bar_fill.color = Color(0.9, 0.25, 0.25, 1.0)
		elif score_percent < 66.0:
			score_bar_fill.color = Color(0.95, 0.85, 0.25, 1.0)
		else:
			score_bar_fill.color = Color(0.3, 0.9, 0.4, 1.0)

func update_ui():
	if score_label:
		score_label.text = "%d%%" % int(round(score_percent))
	if lives_label:
		var hearts = ""
		for i in range(lives):
			hearts += "❤ "
		lives_label.text = hearts.strip_edges()

func _fail_round():
	if sfx_manager:
		sfx_manager.play_sfx("spill_splash")
	if feedback_label:
		feedback_label.show()
		feedback_label.text = "✗ Spilled it!"
		feedback_label.add_theme_color_override("font_color", Color.RED)
	await get_tree().create_timer(1.0).timeout
	lose_minigame()

func play_win_celebration():
	if confetti:
		confetti.emitting = true

	if sfx_manager:
		sfx_manager.play_sfx("sequence_correct")

	var flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0.6)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.4)
	flash_tween.tween_callback(flash.queue_free)

	if victory_label:
		victory_label.show()
		victory_label.scale = Vector2(0.3, 0.3)
		victory_label.modulate.a = 1.0
		var vt = create_tween()
		vt.tween_property(victory_label, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		vt.tween_interval(1.2)
		vt.tween_property(victory_label, "modulate:a", 0.0, 0.4)

	await get_tree().create_timer(2.0).timeout
	win_minigame()

func win_minigame():
	print("Drink Pour WON!")
	emit_signal("minigame_won", 0)

func lose_minigame():
	print("Drink Pour LOST!")
	if alcohol_system and is_instance_valid(alcohol_system) and alcohol_system.has_method("drink_alcohol"):
		alcohol_system.drink_alcohol(0.2)
	if not is_inside_tree():
		return
	emit_signal("minigame_lost")
	if game_manager:
		game_manager.minigame_lost.emit()

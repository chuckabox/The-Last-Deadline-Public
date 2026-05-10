extends Control

# Drinks
var drinks = ["Vodka", "Tequila", "Rum"]

# Stage config: [sequence_length, display_time]
const STAGE_CONFIG = [
	{"length": 4, "display_time": 3.0},
	{"length": 6, "display_time": 2.5},
	{"length": 8, "display_time": 2.0},
]

# Game State
var current_stage = 1
var total_stages = 3
var lives = 3
var current_sequence = []
var player_sequence = []
var difficulty_stage = 0
var is_active = false
var tutorial_active = true
var buttons_locked = true

# References
var ticket_panel: Panel
var ticket_label: Label
var drink_buttons: HBoxContainer
var feedback_label: Label
var instruction_label: Label
var stage_label: Label
var lives_label: Label
var progress_label: Label
var victory_label: Label
var tutorial_overlay: ColorRect
var alcohol_system: Node
var sfx_manager: Node
var game_manager: Node

signal minigame_won(cash_reward)
signal minigame_lost()

func _ready():
	ticket_panel = get_node_or_null("TicketPanel")
	if ticket_panel:
		ticket_label = ticket_panel.get_node_or_null("TicketLabel")

	drink_buttons = get_node_or_null("DrinkButtons")
	feedback_label = get_node_or_null("FeedbackLabel")
	instruction_label = get_node_or_null("InstructionLabel")
	stage_label = get_node_or_null("StageLabel")
	lives_label = get_node_or_null("LivesLabel")
	progress_label = get_node_or_null("ProgressLabel")
	victory_label = get_node_or_null("VictoryLabel")
	tutorial_overlay = get_node_or_null("TutorialOverlay")

	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	sfx_manager = get_node_or_null("/root/SFXManager")
	game_manager = get_node_or_null("/root/GameManager")

	if alcohol_system and "current_stage" in alcohol_system:
		difficulty_stage = alcohol_system.current_stage

	# Connect buttons — start disabled
	if drink_buttons:
		for button in drink_buttons.get_children():
			if button is Button:
				button.pressed.connect(_on_drink_clicked.bind(button.name))
				button.disabled = true

	# Show tutorial
	tutorial_active = true
	if tutorial_overlay:
		tutorial_overlay.show()

	# Pulse start prompt
	var start_prompt = get_node_or_null("TutorialOverlay/TutorialPanel/StartPrompt")
	if start_prompt:
		var tween = create_tween().set_loops()
		tween.tween_property(start_prompt, "modulate:a", 0.2, 0.6)
		tween.tween_property(start_prompt, "modulate:a", 1.0, 0.6)

	# Hide ticket and buttons until tutorial dismissed
	if ticket_panel:
		ticket_panel.hide()

	print("Bartender Memory started — Difficulty: %d" % difficulty_stage)

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
	start_stage()

func start_stage():
	is_active = false
	buttons_locked = true
	player_sequence = []
	lives = 3

	update_ui()
	generate_sequence()

func generate_sequence():
	player_sequence = []
	current_sequence = []

	var config = STAGE_CONFIG[current_stage - 1]
	var length = config["length"]
	var display_time = config["display_time"]

	# Difficulty stage also affects display time
	display_time = max(0.8, display_time - (difficulty_stage * 0.2))

	for i in range(length):
		current_sequence.append(drinks[randi() % drinks.size()])

	# Build ticket text
	var sequence_text = ""
	for drink in current_sequence:
		sequence_text += drink + "\n"

	if ticket_label:
		ticket_label.text = sequence_text
		ticket_label.rotation_degrees = 0.0
		ticket_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))

		if difficulty_stage >= 2:
			ticket_label.rotation_degrees = randf_range(-12.0, 12.0)

		if difficulty_stage >= 3:
			ticket_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
			ticket_label.add_theme_constant_override("shadow_offset_x", 4)
			ticket_label.add_theme_constant_override("shadow_offset_y", 4)

	# Shuffle button order at stage 4
	if difficulty_stage >= 4 and drink_buttons:
		var children = drink_buttons.get_children()
		for child in children:
			drink_buttons.remove_child(child)
		children.shuffle()
		for child in children:
			drink_buttons.add_child(child)

	# Lock buttons and show ticket
	_set_buttons_locked(true)
	if ticket_panel:
		ticket_panel.show()
	if instruction_label:
		instruction_label.text = "Memorise the order!"
	if progress_label:
		progress_label.text = ""

	# Wait then hide ticket and unlock buttons
	await get_tree().create_timer(display_time).timeout
	_hide_ticket_and_unlock()

func _hide_ticket_and_unlock():
	if ticket_panel:
		var tween = create_tween()
		tween.tween_property(ticket_panel, "modulate:a", 0.0, 0.3)
		tween.tween_callback(ticket_panel.hide)
		tween.tween_callback(func(): ticket_panel.modulate.a = 1.0)

	_set_buttons_locked(false)
	is_active = true
	buttons_locked = false

	if instruction_label:
		instruction_label.text = "Click the drinks in order!"

func _set_buttons_locked(locked: bool):
	if not drink_buttons:
		return
	for button in drink_buttons.get_children():
		if button is Button:
			button.disabled = locked
			button.modulate = Color(0.5, 0.5, 0.5, 1.0) if locked else Color(1, 1, 1, 1.0)

func _on_drink_clicked(button_name: String):
	if not is_active or buttons_locked:
		return

	var drink_name = button_name.replace("Button", "")
	player_sequence.append(drink_name)

	var expected_index = player_sequence.size() - 1

	if expected_index < current_sequence.size():
		if player_sequence[expected_index] == current_sequence[expected_index]:
			# Correct pick
			if sfx_manager:
				sfx_manager.play_sfx("sequence_correct")
			if feedback_label:
				feedback_label.text = "✓"
				feedback_label.add_theme_color_override("font_color", Color.GREEN)
			if progress_label:
				progress_label.text = "%d / %d correct" % [player_sequence.size(), current_sequence.size()]

			# Check stage complete
			if player_sequence.size() == current_sequence.size():
				is_active = false
				_set_buttons_locked(true)
				await get_tree().create_timer(0.5).timeout
				next_stage()
		else:
			# Wrong pick
			if sfx_manager:
				sfx_manager.play_sfx("sequence_wrong")
			if feedback_label:
				feedback_label.text = "✗ Wrong order!"
				feedback_label.add_theme_color_override("font_color", Color.RED)

			is_active = false
			_set_buttons_locked(true)
			lives -= 1
			update_ui()

			await get_tree().create_timer(1.2).timeout

			if lives <= 0:
				lose_minigame()
			else:
				# New sequence, same stage
				if feedback_label:
					feedback_label.text = ""
				generate_sequence()

	# Clear feedback tick after short delay if still active
	# Clear feedback tick after short delay if still active
	if is_inside_tree():
		await get_tree().create_timer(0.4).timeout
	if is_inside_tree() and is_active and feedback_label and feedback_label.text == "✓":
		feedback_label.text = ""

func next_stage():
	if current_stage >= total_stages:
		play_win_celebration()
	else:
		current_stage += 1
		if feedback_label:
			feedback_label.text = "Stage Clear!"
			feedback_label.add_theme_color_override("font_color", Color.GREEN)
		await get_tree().create_timer(1.0).timeout
		if feedback_label:
			feedback_label.text = ""
		start_stage()

func play_win_celebration():
	is_active = false
	_set_buttons_locked(true)

	# Flash screen
	var flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0.5)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.4)
	flash_tween.tween_callback(flash.queue_free)

	# Show victory label with bounce
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

func update_ui():
	if stage_label:
		stage_label.text = "Stage %d / %d" % [current_stage, total_stages]
	if lives_label:
		var hearts = ""
		for i in range(lives):
			hearts += "❤ "
		for i in range(3 - lives):
			hearts += "♡ "
		lives_label.text = hearts.strip_edges()

func win_minigame():
	is_active = false
	print("Bartender Memory WON!")
	emit_signal("minigame_won", 0)

func lose_minigame():
	is_active = false
	_set_buttons_locked(true)
	print("Bartender Memory LOST!")
	if alcohol_system and is_instance_valid(alcohol_system) and alcohol_system.has_method("drink_alcohol"):
		alcohol_system.drink_alcohol(0.2)
	
	# After drink_alcohol, the EndingManager may trigger a scene change (e.g. blackout).
	# Bail out if this node is no longer in the tree to avoid crash.
	if not is_inside_tree():
		return
	
	emit_signal("minigame_lost")
	if game_manager:
		game_manager.minigame_lost.emit()

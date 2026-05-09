extends Control

# Game State
var drinks = ["Vodka", "Tequila", "Rum"]
var current_sequence = []
var player_sequence = []
var difficulty_stage = 0
var ticket_display_time = 3.0
var show_ticket = true
var is_active = true

# Reference
var ticket_panel: Panel
var ticket_label: Label
var drink_buttons: HBoxContainer
var feedback_label: Label
var instruction_label: Label
var alcohol_system: Node

# Signals
signal minigame_won(cash_reward)
signal minigame_lost()

func _ready():
	# Get references
	ticket_panel = get_node_or_null("TicketPanel")
	if ticket_panel:
		ticket_label = ticket_panel.get_node_or_null("TicketLabel")
	drink_buttons = get_node_or_null("DrinkButtons")
	feedback_label = get_node_or_null("FeedbackLabel")
	instruction_label = get_node_or_null("InstructionLabel")
	
	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	if alcohol_system and "current_stage" in alcohol_system:
		difficulty_stage = alcohol_system.current_stage
	
	# Connect button signals
	if drink_buttons:
		for button in drink_buttons.get_children():
			if button is Button:
				button.pressed.connect(_on_drink_clicked.bind(button.name))
	
	# Generate sequence based on difficulty
	generate_sequence()
	
	# Start game
	show_ticket_timer()
	
	print("Bartender Memory mini-game started")

func generate_sequence():
	player_sequence = []
	current_sequence = []
	
	var sequence_length = 4 + difficulty_stage  # 4, 5, 6, 7, 8 drinks
	ticket_display_time = max(1.0, 3.0 - (difficulty_stage * 0.5)) # 3.0, 2.5, 2.0, 1.5, 1.0
	
	for i in range(sequence_length):
		current_sequence.append(drinks[randi() % drinks.size()])
	
	# Display sequence
	var sequence_text = ""
	for drink in current_sequence:
		if difficulty_stage >= 4:
			# Stage 4: labels gibberish
			var gibberish = ""
			var chars = "abcdefghijklmnopqrstuvwxyz1234567890!@#$%"
			for j in range(drink.length()):
				if randf() > 0.5:
					gibberish += chars[randi() % chars.length()]
				else:
					gibberish += drink[j]
			sequence_text += gibberish + "\n"
		else:
			sequence_text += drink + "\n"
	
	if ticket_label:
		ticket_label.text = sequence_text
		
		# Difficulty visual adjustments
		if difficulty_stage >= 2:
			# Stage 2: Visual distortion (rotation)
			ticket_label.rotation_degrees = randf_range(-15.0, 15.0)
		if difficulty_stage >= 3:
			# Stage 3: Blurred text (simulate with transparent color and shadow)
			ticket_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
			ticket_label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.2))
			ticket_label.add_theme_constant_override("shadow_offset_x", 4)
			ticket_label.add_theme_constant_override("shadow_offset_y", 4)
			
	if difficulty_stage >= 4 and drink_buttons:
		# Stage 4: Position changes for buttons
		var children = drink_buttons.get_children()
		for child in children:
			drink_buttons.remove_child(child)
		children.shuffle()
		for child in children:
			drink_buttons.add_child(child)
			
	if ticket_panel:
		ticket_panel.show()
	if instruction_label:
		instruction_label.text = "Remember this order!"

func show_ticket_timer():
	await get_tree().create_timer(ticket_display_time).timeout
	if ticket_panel:
		ticket_panel.hide()
	if instruction_label:
		instruction_label.text = "Click the drinks in order!"

func _on_drink_clicked(button_name: String):
	if not is_active:
		return
	
	# Map button to drink ("VodkaButton" -> "Vodka")
	var drink_name = button_name.replace("Button", "")
	
	# Add to player sequence
	player_sequence.append(drink_name)
	
	# Check if correct
	var expected_index = player_sequence.size() - 1
	
	if expected_index < current_sequence.size():
		if player_sequence[expected_index] == current_sequence[expected_index]:
			# Correct
			if feedback_label:
				feedback_label.text = "✓"
				feedback_label.add_theme_color_override("font_color", Color.GREEN)
			play_sound("sequence_correct")
			
			# Check if complete
			if player_sequence.size() == current_sequence.size():
				win_minigame()
		else:
			# Wrong
			if feedback_label:
				feedback_label.text = "✗"
				feedback_label.add_theme_color_override("font_color", Color.RED)
			play_sound("sequence_wrong")
			is_active = false
			await get_tree().create_timer(1.0).timeout
			lose_minigame()
	
	# Clear feedback after 0.5s
	await get_tree().create_timer(0.5).timeout
	if feedback_label and is_active: # Only clear if game is still going
		feedback_label.text = ""

func win_minigame():
	is_active = false
	var cash_reward = 100 + (difficulty_stage * 50)  # 100, 150, 200, 250, 300
	print("Bartender Memory WON! Cash: $%d" % cash_reward)
	emit_signal("minigame_won", cash_reward)

func lose_minigame():
	is_active = false
	print("Bartender Memory LOST! Alcohol +1")
	emit_signal("minigame_lost")
	
	# Notify GameManager for global ending checks
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.minigame_lost.emit()

func play_sound(sound_name: String):
	# TODO: Play SFX
	pass

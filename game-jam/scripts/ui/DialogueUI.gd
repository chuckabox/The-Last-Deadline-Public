extends Panel

# References
var speaker_label: Label
var dialogue_text: Label
var portrait_rect: TextureRect
var options_container: VBoxContainer
var option_buttons: Array[Button]

# State
var current_dialogue_data = {}
var current_node_name = ""
var game_manager: Node
var selected_option_index = 0

# Signals
signal option_selected(option_index, next_node)

func _ready():
	# Get references
	speaker_label = get_node("Content/DialogueContent/SpeakerLabel")
	dialogue_text = get_node("Content/DialogueContent/DialogueText")
	portrait_rect = get_node("Content/PortraitRect")
	options_container = get_node("Content/OptionsContainer")
	
	# Get buttons
	option_buttons = [
		get_node("Content/OptionsContainer/OptionLeft"),
		get_node("Content/OptionsContainer/OptionCenter"),
		get_node("Content/OptionsContainer/OptionRight")
	]
	
	# Connect button signals
	for i in range(option_buttons.size()):
		option_buttons[i].pressed.connect(_on_option_pressed.bind(i))
	
	game_manager = get_node_or_null("/root/GameManager")
	
	# Start hidden
	hide()
	
	print("DialogueUI initialized")

func show_dialogue(npc_name: String, start_node: String = "start"):
	# Load dialogue data
	var parser = get_node_or_null("/root/DialogueParser")
	if not parser:
		print("ERROR: DialogueParser not found!")
		return
		
	current_dialogue_data = parser.load_dialogue(npc_name)
	current_node_name = start_node
	
	# Display first node
	display_node()
	show()

func display_node():
	var parser = get_node_or_null("/root/DialogueParser")
	if not parser: return
	
	# Get node data (handle variants)
	var node_data = parser.get_variant_node(current_dialogue_data, current_node_name, game_manager)
	
	if node_data.is_empty():
		close_dialogue()
		return
	
	# Update speaker and text
	speaker_label.text = current_dialogue_data.get("name", "NPC")
	dialogue_text.text = node_data.get("text", "")
	
	# Update options
	var options = node_data.get("options", [])
	
	for i in range(3):
		if i < options.size():
			option_buttons[i].text = options[i].get("text", "")
			option_buttons[i].show()
		else:
			option_buttons[i].hide()
	
	# Highlight first option
	selected_option_index = 0
	update_option_highlight()

func update_option_highlight():
	for i in range(option_buttons.size()):
		if i == selected_option_index:
			option_buttons[i].add_theme_color_override("font_color", Color.YELLOW)
		else:
			option_buttons[i].add_theme_color_override("font_color", Color.WHITE)

func _on_option_pressed(index: int):
	selected_option_index = index
	
	var parser = get_node_or_null("/root/DialogueParser")
	if not parser: return
	
	# Get option data
	var node_data = parser.get_variant_node(current_dialogue_data, current_node_name, game_manager)
	var options = node_data.get("options", [])
	
	if index >= options.size():
		return
	
	var option = options[index]
	var next_node = option.get("next", "")
	
	# Apply flags if any
	if option.has("setFlag") and game_manager and "npc_completed" in game_manager:
		var flag_name = option["setFlag"].get("flag", "")
		var flag_value = option["setFlag"].get("value", true)
		if game_manager.npc_completed.has(flag_name):
			game_manager.npc_completed[flag_name] = flag_value
	
	# Move to next node
	if next_node == "exit" or next_node == "":
		close_dialogue()
	else:
		current_node_name = next_node
		display_node()

func close_dialogue():
	hide()
	emit_signal("option_selected", selected_option_index, "")

func _input(event):
	if not visible:
		return
	
	# Arrow key navigation
	if event.is_action_pressed("ui_left"):
		selected_option_index = max(0, selected_option_index - 1)
		update_option_highlight()
	elif event.is_action_pressed("ui_right"):
		selected_option_index = min(2, selected_option_index + 1)
		update_option_highlight()
	elif event.is_action_pressed("ui_accept"):
		_on_option_pressed(selected_option_index)

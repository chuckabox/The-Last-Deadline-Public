extends Panel

## Dialogue UI Manager
## Manages the display of text, portraits, and the 3-option button system.
## Injects random gibberish into the center option based on alcohol levels.

# References
var speaker_label: Label
var dialogue_text: Label
var portrait_rect: TextureRect
var options_container: HBoxContainer # Changed to HBox for 3-across alignment
var option_buttons: Array[Button]

# State
var current_dialogue_data = {}
var current_node_name = ""
var selected_option_index = 0

# Signals
signal dialogue_opened()
signal dialogue_closed()

func _ready():
	# Get references (assuming standard paths from the .tscn)
	speaker_label = get_node_or_null("Content/UpperLayout/DialogueContent/SpeakerLabel")
	dialogue_text = get_node_or_null("Content/UpperLayout/DialogueContent/DialogueText")
	portrait_rect = get_node_or_null("Content/UpperLayout/PortraitRect")
	options_container = get_node_or_null("Content/OptionsContainer")
	
	# Get the 3 buttons
	# Left = Option 0, Center = Gibberish, Right = Option 1
	option_buttons = [
		get_node_or_null("Content/OptionsContainer/OptionLeft"),
		get_node_or_null("Content/OptionsContainer/OptionCenter"),
		get_node_or_null("Content/OptionsContainer/OptionRight")
	]
	
	# Connect button signals
	for i in range(option_buttons.size()):
		if option_buttons[i]:
			option_buttons[i].pressed.connect(_on_option_pressed.bind(i))
	
	# Initial state
	hide()
	print("DialogueUI initialized with 3-button system")

## Main entry point to start a conversation
func show_dialogue(npc_name: String, start_node: String = "start"):
	var parser = get_node_or_null("/root/DialogueParser")
	if not parser: return
		
	current_dialogue_data = parser.load_dialogue(npc_name)
	var entry = start_node if start_node != "" else \
		current_dialogue_data.get("dialogue", {}).get("start", "talk")
	current_node_name = entry
	dialogue_opened.emit()
	display_node()
	show()

## Updates the UI with the current node's text and options
func display_node():
	var parser = get_node_or_null("/root/DialogueParser")
	if not parser: return
	
	var node_data = parser.get_variant_node(current_dialogue_data, current_node_name)
	
	if node_data.is_empty() or node_data.get("text") == null:
		close_dialogue()
		return
	
	# Update text
	speaker_label.text = current_dialogue_data.get("name", "NPC")
	dialogue_text.text = node_data.get("text", "")
	
	# Setup the 3 buttons
	var json_options = node_data.get("options", [])
	
	# 1. OPTION 1 (LEFT) - From JSON Index 0
	if json_options.size() > 0:
		option_buttons[0].text = json_options[0].get("text", "...")
		option_buttons[0].show()
	else:
		option_buttons[0].hide()
		
	# 2. OPTION 2 (CENTER) - RANDOM GIBBERISH
	_populate_gibberish_option()
	
	# 3. OPTION 3 (RIGHT) - From JSON Index 1 (if exists)
	if json_options.size() > 1:
		option_buttons[2].text = json_options[1].get("text", "Exit")
		option_buttons[2].show()
	else:
		# If no second option, use a default "Exit" or hide
		option_buttons[2].text = "..."
		option_buttons[2].show()
	
	# Default focus for keyboard navigation
	option_buttons[0].grab_focus()
	selected_option_index = 0

func _populate_gibberish_option():
	var g_db = get_node_or_null("/root/GibberishDatabase")
	var alcohol_system = get_node_or_null("/root/AlcoholSystem")
	
	if g_db and alcohol_system:
		var stage = alcohol_system.get("current_stage") if "current_stage" in alcohol_system else 0
		option_buttons[1].text = g_db.get_random_line(stage)
		option_buttons[1].show()
	else:
		option_buttons[1].hide()

func _on_option_pressed(index: int):
	# CENTER OPTION (Index 1) always exits/cancels
	if index == 1:
		close_dialogue()
		return
		
	# Get the correct JSON option index (Mapping: UI 0 -> JSON 0, UI 2 -> JSON 1)
	var json_index = 0 if index == 0 else 1
	
	var parser = get_node_or_null("/root/DialogueParser")
	var node_data = parser.get_variant_node(current_dialogue_data, current_node_name)
	var json_options = node_data.get("options", [])
	
	if json_index >= json_options.size():
		close_dialogue()
		return
		
	var option = json_options[json_index]
	
	# --- PROCESS EFFECTS ---
	
	# 1. setFlag (Dictionary iteration)
	if option.has("setFlag"):
		var global_state = get_node_or_null("/root/GlobalStateManager")
		if global_state:
			global_state.set_flags_from_dict(option["setFlag"])
			
	# 2. triggerGlobal
	if option.has("triggerGlobal"):
		var global_state = get_node_or_null("/root/GlobalStateManager")
		if global_state:
			global_state.trigger_global_event(option["triggerGlobal"])
			
	# --- NAVIGATION ---
	var next_node = option.get("next", "exit")
	if next_node == "exit" or next_node == "":
		close_dialogue()
	else:
		current_node_name = next_node
		display_node()

func close_dialogue():
	hide()
	dialogue_closed.emit()

func _input(event):
	if not visible: return
	
	# Tab/Arrow cycling support
	if event.is_action_pressed("ui_focus_next"):
		selected_option_index = (selected_option_index + 1) % 3
		option_buttons[selected_option_index].grab_focus()
	if event.is_action_pressed("ui_focus_prev"):
		selected_option_index = (selected_option_index - 1 + 3) % 3
		option_buttons[selected_option_index].grab_focus()

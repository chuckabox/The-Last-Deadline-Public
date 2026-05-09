extends Panel

## Dialogue UI Manager
## Manages the display of text, portraits, and the 3-option button system.
## Injects random gibberish into the center option based on alcohol levels.

# Bust assets — each NPC has a folder of frames at:
#   res://assets/npc/<folder>/bust/*.{png,jpg,jpeg,webp}
# All frames are cycled on a timer to make it look like the NPC is talking.
const BUST_ROOT := "res://assets/npc/"
const BUST_SUBPATH := "/bust/"
const BUST_EXTENSIONS: Array[String] = [".png", ".jpg", ".jpeg", ".webp"]
# Optional override: dialogue NPC id -> assets/npc/<folder> name when the
# folder name doesn't match the NPC id. Empty by default — folder names match.
const BUST_FOR_NPC := {}

# ----- BUST DISPLAY -----
# Layout (size / position) is edited directly on the BustRect node in
# DialogueUI.tscn — drag it in the 2D editor or tweak its anchors/offsets in
# the Inspector. Only runtime-only knobs are exported here.

## Seconds per frame while cycling the bust to fake a talking animation.
@export var bust_frame_interval: float = 0.25:
	set(v):
		bust_frame_interval = v
		if _bust_timer:
			_bust_timer.wait_time = max(0.01, v)

# References
var speaker_label: Label
var dialogue_text: Label
var portrait_rect: TextureRect
var options_container: HBoxContainer # Changed to HBox for 3-across alignment
var option_buttons: Array[Button]
var bust_rect: TextureRect
var _bust_frames: Array[Texture2D] = []
var _bust_frame_index: int = 0
var _bust_timer: Timer

# State
var current_dialogue_data = {}
var current_node_name = ""
var selected_option_index = 0

# Signals
signal dialogue_opened()
signal dialogue_closed()

func _ready():
	# Get references (assuming standard paths from the .tscn)
	speaker_label = get_node_or_null("SpeakerNameBox/SpeakerLabel")
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

	_build_bust_display()

	# Initial state
	hide()
	print("DialogueUI initialized with 3-button system")

## Looks up the BustRect / BustTimer nodes from the scene. Falls back to
## creating them programmatically if they're missing (defensive — they should
## already exist in DialogueUI.tscn).
func _build_bust_display() -> void:
	bust_rect = get_node_or_null("BustRect") as TextureRect
	if bust_rect == null:
		bust_rect = TextureRect.new()
		bust_rect.name = "BustRect"
		bust_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bust_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bust_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bust_rect.anchor_left = 0.5
		bust_rect.anchor_right = 0.5
		bust_rect.anchor_top = 0.0
		bust_rect.anchor_bottom = 0.0
		add_child(bust_rect)
	bust_rect.hide()

	_bust_timer = get_node_or_null("BustTimer") as Timer
	if _bust_timer == null:
		_bust_timer = Timer.new()
		_bust_timer.name = "BustTimer"
		_bust_timer.one_shot = false
		_bust_timer.autostart = false
		add_child(_bust_timer)
	_bust_timer.wait_time = max(0.01, bust_frame_interval)
	_bust_timer.timeout.connect(_advance_bust_frame)

## Main entry point to start a conversation
func show_dialogue(npc_name: String, start_node: String = "start"):
	var parser = get_node_or_null("/root/DialogueParser")
	if not parser: return

	current_dialogue_data = parser.load_dialogue(npc_name)
	var entry = start_node if start_node != "" else \
		current_dialogue_data.get("dialogue", {}).get("start", "talk")
	current_node_name = entry
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_method("pause_time"):
		time_manager.pause_time()

	_set_bust_for(npc_name)

	dialogue_opened.emit()
	display_node()
	show()

## Loads all bust frames for an NPC and starts cycling them to fake a talking
## animation. Hides the bust if the NPC's folder is empty or missing.
func _set_bust_for(npc_id: String) -> void:
	_stop_bust()
	if not bust_rect:
		return
	var folder_name: String = BUST_FOR_NPC.get(npc_id, npc_id)
	var folder_path := BUST_ROOT + folder_name + BUST_SUBPATH
	_bust_frames = _load_bust_frames(folder_path)
	if _bust_frames.is_empty():
		bust_rect.hide()
		return
	_bust_frame_index = 0
	bust_rect.texture = _bust_frames[0]
	bust_rect.show()
	if _bust_frames.size() > 1 and _bust_timer:
		_bust_timer.start()

func _load_bust_frames(folder_path: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if not DirAccess.dir_exists_absolute(folder_path):
		return frames
	var raw_files := DirAccess.get_files_at(folder_path)
	var image_files: Array[String] = []
	for f: String in raw_files:
		var lower := f.to_lower()
		# Skip Godot bookkeeping files.
		if lower.ends_with(".import") or lower.ends_with(".uid") or lower.ends_with(".remap"):
			continue
		for ext: String in BUST_EXTENSIONS:
			if lower.ends_with(ext):
				image_files.append(f)
				break
	image_files.sort()
	for fname: String in image_files:
		var path: String = folder_path + fname
		var tex := load(path) as Texture2D
		if tex:
			frames.append(tex)
	return frames

func _advance_bust_frame() -> void:
	if _bust_frames.is_empty() or not bust_rect:
		return
	_bust_frame_index = (_bust_frame_index + 1) % _bust_frames.size()
	bust_rect.texture = _bust_frames[_bust_frame_index]

func _stop_bust() -> void:
	if _bust_timer:
		_bust_timer.stop()
	_bust_frames.clear()
	_bust_frame_index = 0

## Updates the UI with the current node's text and options
func display_node():
	var parser = get_node_or_null("/root/DialogueParser")
	if not parser: return

	var node_data = parser.get_variant_node(current_dialogue_data, current_node_name)

	if node_data.is_empty() or node_data.get("text") == null:
		close_dialogue()
		return

	# Minigame trigger: node has "minigame" key. Launch it and let the result
	# pick option 0 ([Win]) or option 1 ([Lose]) automatically.
	if node_data.has("minigame"):
		_launch_minigame_for_node(node_data)
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
		_apply_disabled_state(option_buttons[0], json_options[0])
	else:
		option_buttons[0].hide()
		
	# 2. OPTION 2 (CENTER) - RANDOM GIBBERISH
	_populate_gibberish_option()
	var center_mapped_idx = 1 if json_options.size() > 2 else 0
	if json_options.size() > 0:
		_apply_disabled_state(option_buttons[1], json_options[center_mapped_idx])
	
	# 3. OPTION 3 (RIGHT)
	if json_options.size() > 2:
		option_buttons[2].text = json_options[2].get("text", "Exit")
		option_buttons[2].show()
		_apply_disabled_state(option_buttons[2], json_options[2])
	elif json_options.size() > 1:
		option_buttons[2].text = json_options[1].get("text", "Exit")
		option_buttons[2].show()
		_apply_disabled_state(option_buttons[2], json_options[1])
	else:
		# If no second option, use a default "Exit" or hide
		option_buttons[2].text = "..."
		option_buttons[2].show()
		option_buttons[2].disabled = false
	
	# Default focus for keyboard navigation
	option_buttons[0].grab_focus()
	selected_option_index = 0

func _apply_disabled_state(btn: Button, option: Dictionary) -> void:
	btn.disabled = false
	if option.has("disabled_if"):
		var cond = option["disabled_if"]
		var global_state = get_node_or_null("/root/GlobalStateManager")
		if global_state and cond.has("flag") and cond.has("is"):
			if global_state.check_flag(cond["flag"]) == cond["is"]:
				btn.disabled = true

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
	var parser = get_node_or_null("/root/DialogueParser")
	var node_data = parser.get_variant_node(current_dialogue_data, current_node_name)
	var json_options = node_data.get("options", [])

	var json_index = 0

	if index == 0:
		json_index = 0
	elif index == 1:
		# Center (Gibberish) maps to index 1 if there are 3 options, otherwise maps to index 0 (Progress)
		if json_options.size() > 2:
			json_index = 1
		else:
			json_index = 0
	elif index == 2:
		# Right maps to index 2 if there are 3 options, index 1 if there are 2, otherwise closes
		if json_options.size() > 2:
			json_index = 2
		elif json_options.size() > 1:
			json_index = 1
		else:
			close_dialogue()
			return

	if json_index >= json_options.size():
		close_dialogue()
		return

	_apply_option(json_options[json_index])

## Applies an option's effects (setFlag / triggerGlobal) and navigates.
func _apply_option(option: Dictionary) -> void:
	if option.has("setFlag"):
		var global_state = get_node_or_null("/root/GlobalStateManager")
		if global_state:
			global_state.set_flags_from_dict(option["setFlag"])

	if option.has("triggerGlobal"):
		var global_state = get_node_or_null("/root/GlobalStateManager")
		if global_state:
			global_state.trigger_global_event(option["triggerGlobal"])

	var next_node = option.get("next", "exit")
	if next_node == "exit" or next_node == "":
		close_dialogue()
	else:
		current_node_name = next_node
		display_node()

## Hides the dialogue, launches the minigame, and resolves the result by
## applying option[0] on win or option[1] on lose from the current node.
func _launch_minigame_for_node(node_data: Dictionary) -> void:
	var mm = get_node_or_null("/root/MinigameManager")
	if mm == null:
		push_error("DialogueUI: MinigameManager autoload missing")
		close_dialogue()
		return

	hide()
	mm.minigame_finished.connect(_on_minigame_finished.bind(node_data), CONNECT_ONE_SHOT)

	if not mm.launch(node_data["minigame"]):
		push_error("DialogueUI: failed to launch minigame '%s'" % node_data["minigame"])
		show()
		# CONNECT_ONE_SHOT leaves the connection dangling on failure; clear it.
		var cb := Callable(self, "_on_minigame_finished").bind(node_data)
		if mm.minigame_finished.is_connected(cb):
			mm.minigame_finished.disconnect(cb)
		close_dialogue()

func _on_minigame_finished(_minigame_id: String, won: bool, node_data: Dictionary) -> void:
	show()
	var json_options = node_data.get("options", [])
	var idx := 0 if won else 1
	if idx < json_options.size():
		_apply_option(json_options[idx])
	else:
		close_dialogue()

func close_dialogue():
	_stop_bust()
	if bust_rect:
		bust_rect.hide()
	hide()
	dialogue_closed.emit()

	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_method("resume_time"):
		time_manager.resume_time()

func _input(event):
	if not visible: return
	
	# Tab/Arrow cycling support
	if event.is_action_pressed("ui_focus_next"):
		selected_option_index = (selected_option_index + 1) % 3
		option_buttons[selected_option_index].grab_focus()
	if event.is_action_pressed("ui_focus_prev"):
		selected_option_index = (selected_option_index - 1 + 3) % 3
		option_buttons[selected_option_index].grab_focus()

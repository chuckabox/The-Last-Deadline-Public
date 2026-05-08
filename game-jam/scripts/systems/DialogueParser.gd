extends Node

# Dialogue cache
var dialogue_cache = {}

func _ready():
	add_to_group("parsers")
	print("DialogueParser initialized")

func load_dialogue(npc_name: String) -> Dictionary:
	# Check cache first
	if dialogue_cache.has(npc_name):
		return dialogue_cache[npc_name]
	
	# Load from JSON file
	var file_path = "res://data/dialogue_trees/%s.json" % npc_name.to_lower()
	var json_string = load_file_as_text(file_path)
	
	if json_string == "":
		print("ERROR: Could not load dialogue for %s" % npc_name)
		return {}
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		print("ERROR: Failed to parse JSON for %s: %s" % [npc_name, json.get_error_message()])
		return {}
	
	var data = json.data
	dialogue_cache[npc_name] = data
	return data

func load_file_as_text(file_path: String) -> String:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("ERROR: Could not open file %s" % file_path)
		return ""
	return file.get_as_text()

func get_node_text(dialogue_data: Dictionary, node_name: String) -> String:
	if not dialogue_data.has("nodes"):
		return ""
	
	var node = dialogue_data["nodes"].get(node_name, {})
	return node.get("text", "")

func get_node_options(dialogue_data: Dictionary, node_name: String) -> Array:
	if not dialogue_data.has("nodes"):
		return []
	
	var node = dialogue_data["nodes"].get(node_name, {})
	return node.get("options", [])

func evaluate_condition(condition: Dictionary, game_manager: Node) -> bool:
	# Check if condition is met based on game state
	if condition.is_empty():
		return true
	
	var flag_name = condition.get("flag", "")
	var flag_value = condition.get("is", true)
	
	# Get flag from game manager safely
	if game_manager and "npc_completed" in game_manager and game_manager.npc_completed.has(flag_name):
		return game_manager.npc_completed[flag_name] == flag_value
	
	return false

func get_variant_node(dialogue_data: Dictionary, node_name: String, game_manager: Node) -> Dictionary:
	# Find variant that matches conditions
	if not dialogue_data.has("nodes"):
		return {}
	
	var node = dialogue_data["nodes"].get(node_name, {})
	
	if not node.has("variants"):
		return node
	
	for variant in node["variants"]:
		if variant.has("condition"):
			if evaluate_condition(variant["condition"], game_manager):
				return variant
		else:
			return variant
	
	return {}

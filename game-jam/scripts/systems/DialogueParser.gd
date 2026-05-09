extends Node

## Dialogue Parser
## Responsible for loading JSON dialogue trees and evaluating conditional variants.

# Dialogue cache to avoid redundant file I/O
var dialogue_cache = {}

func _ready():
	add_to_group("parsers")
	print("DialogueParser initialized")

## Loads a dialogue JSON file by NPC name
func load_dialogue(npc_name: String) -> Dictionary:
	dialogue_cache.clear()
	if dialogue_cache.has(npc_name.to_lower()):
		return dialogue_cache[npc_name.to_lower()]
	
	var file_path = "res://data/dialogue_trees/%s.json" % npc_name.to_lower()
	var json_string = load_file_as_text(file_path)
	
	if json_string == "":
		push_error("DialogueParser: Could not load dialogue for %s" % npc_name)
		return {}
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("DialogueParser: Failed to parse JSON for %s: %s" % [npc_name, json.get_error_message()])
		return {}
	
	var data = json.data
	dialogue_cache[npc_name.to_lower()] = data
	return data

func load_file_as_text(file_path: String) -> String:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()

## Returns the best matching variant for a node based on current GlobalState
func get_variant_node(dialogue_data: Dictionary, node_name: String) -> Dictionary:
	if not dialogue_data.get("dialogue", {}).has("nodes"):
		return {}
	
	var node = dialogue_data.get("dialogue", {}).get("nodes", {}).get(node_name, {})
	
	# If the node has no variants, return the base node
	if not node.has("variants"):
		return node
	
	# Iterate through variants and find the first one whose condition is met
	for variant in node["variants"]:
		if not variant.has("condition"):
			return variant # Default variant with no conditions
			
		if evaluate_condition(variant["condition"]):
			return variant
	
	# Fallback: return the first variant if nothing matches
	return node["variants"][0] if node["variants"].size() > 0 else {}

## Evaluates a single condition against the GlobalStateManager
func evaluate_condition(condition: Dictionary) -> bool:
	if condition.is_empty():
		return true
		
	var flag_name = condition.get("flag", "")
	var expected_value = condition.get("is", true)
	
	# Check against GlobalStateManager
	var global_state = get_node_or_null("/root/GlobalStateManager")
	if global_state:
		return global_state.check_flag(flag_name) == expected_value
	
	# Fallback if manager is missing
	push_warning("DialogueParser: GlobalStateManager not found during evaluation")
	return false

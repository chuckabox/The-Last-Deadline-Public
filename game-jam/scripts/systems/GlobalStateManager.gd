extends Node

## Global State Manager
## Tracks all story flags, quest progression, and handles global events triggered by dialogue.

# ===== SIGNALS =====
signal flag_changed(flag_name: String, value: bool)
signal alcohol_increased(amount: float)
signal quest_completed(quest_name: String)

# ===== STATE =====
## Dictionary to store all boolean flags for the dialogue system
var flags: Dictionary = {
	"hasSpokenToFriend": false,
	"bartenderDefeated": false,
	"fratBroDefeated": false,
	"fatChudDefeated": false,
	"djDefeated": false,
	"vipPoured": false,
	"vipDefeated": false,
	"bossConfronted": false
}

func _ready() -> void:
	add_to_group("managers")
	print("GlobalStateManager initialized")


# ===== FLAG METHODS =====

## Sets a flag and notifies listeners
func set_flag(flag_name: String, value: bool) -> void:
	flags[flag_name] = value
	flag_changed.emit(flag_name, value)
	
	# Check if this flag completes a major quest/NPC interaction
	if value == true:
		_check_quest_milestones(flag_name)

## Retrieves a flag value safely
func check_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)

## Helper to set multiple flags at once (from a dictionary)
func set_flags_from_dict(flag_dict: Dictionary) -> void:
	for f_name in flag_dict:
		set_flag(f_name, flag_dict[f_name])


# ===== GLOBAL TRIGGERS =====

## Called by DialogueUI or Minigames when a global action is required
func trigger_global_event(event_name: String) -> void:
	match event_name:
		"increaseAlcohol":
			increase_alcohol(0.15) # Default penalty for dialogue choices/losses
		"triggerBlackout":
			_trigger_ending("blackout")
		"triggerAverageEnding":
			_trigger_ending("job")
		"triggerSuccessEnding":
			_trigger_ending("academic")
		_:
			push_warning("GlobalStateManager: Unknown global event triggered: ", event_name)

## Interface for the AlcoholSystem
func increase_alcohol(amount: float) -> void:
	var alcohol_system = get_node_or_null("/root/AlcoholSystem")
	if alcohol_system and alcohol_system.has_method("drink_alcohol"):
		alcohol_system.drink_alcohol(amount * 100.0) # System uses 0-100 range
		alcohol_increased.emit(amount)
	else:
		push_error("GlobalStateManager: AlcoholSystem not found!")


# ===== INTERNAL LOGIC =====

func _check_quest_milestones(flag_name: String) -> void:
	# Synchronize with GameManager if it exists
	var game_manager = get_node_or_null("/root/GameManager")
	
	match flag_name:
		"bartenderDefeated":
			if game_manager: game_manager.mark_npc_completed("bartender")
			quest_completed.emit("bar_intro")
		"djDefeated":
			if game_manager: game_manager.mark_npc_completed("dj")
			quest_completed.emit("disco_beat")
		"vipDefeated":
			if game_manager: game_manager.mark_npc_completed("vip_access")

func _trigger_ending(ending_id: String) -> void:
	var ending_manager = get_node_or_null("/root/EndingManager")
	if ending_manager:
		ending_manager.trigger_ending(ending_id)
	else:
		# Fallback if EndingManager isn't a singleton yet
		push_error("GlobalStateManager: EndingManager not found!")

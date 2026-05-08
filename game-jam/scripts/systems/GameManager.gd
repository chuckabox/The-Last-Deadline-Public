extends Node

# ===== GAME STATE =====
## The current room the player is in ("bar", "disco", "vip", "office", "ending")
var current_room: String = "bar"
## The name of the player character
var player_name: String = ""
## Whether the game has started (renamed from game_started to avoid signal conflict)
var is_game_started: bool = false
## Whether the player successfully submitted their assignment
var assignment_submitted: bool = false

# ===== NPC FLAGS =====
## Dictionary tracking which NPCs the player has completed quests/interactions for
## (Renamed from npc_completed to avoid signal conflict)
var npc_completed_status: Dictionary = {
	"bartender": false,
	"frat_bro": false,
	"fat_chud": false,
	"dj": false,
	"vip": false,
	"owner": false
}

# ===== SIGNALS =====
signal game_started()
signal scene_changed(new_scene: String)
signal npc_completed(npc_name: String)


func _ready() -> void:
	add_to_group("managers")
	print("GameManager initialized")


# ===== METHODS =====

## Starts the game and emits the game_started signal
func start_game() -> void:
	is_game_started = true
	game_started.emit()

## Changes the current room state and emits the scene_changed signal
func change_scene(scene_name: String) -> void:
	current_room = scene_name
	scene_changed.emit(scene_name)
	# TODO: Actually load the new scene into the Main CurrentScene node

## Marks an NPC's interaction as complete and emits the associated signal
func mark_npc_completed(npc_name: String) -> void:
	if npc_completed_status.has(npc_name):
		npc_completed_status[npc_name] = true
		npc_completed.emit(npc_name)
	else:
		push_error("GameManager: Tried to complete unknown NPC '%s'" % npc_name)

## Checks if an NPC is marked as completed
func is_npc_completed(npc_name: String) -> bool:
	return npc_completed_status.get(npc_name, false)

## Determines if the player is allowed to enter a specific room
func is_room_accessible(room_name: String) -> bool:
	# TODO: Implement actual room access conditions based on NPC flags
	match room_name:
		"bar":
			return true
		"disco":
			return true # Accessible by default? Or need bartender?
		"vip":
			# Example: Need DJ or Fat Chud completed
			# return npc_completed_status["dj"] or npc_completed_status["fat_chud"]
			return true 
		"office":
			# Example: Need VIP/Owner completed
			# return npc_completed_status["vip"]
			return true
		_:
			return true

extends Area2D

class_name DoorTrigger

# Door Properties
@export var target_room: String = "bar"  # "bar", "disco", "vip", "office"
@export var is_locked: bool = false
@export var lock_message: String = "You need something to unlock this door"
@export var requires_flag: String = ""  # e.g., "dj_completed"

# References
var game_manager: Node
var room_transition_manager: Node
var dialogue_ui: Panel
var audio_manager: Node

func _ready():
	# Get references safely
	game_manager = get_node_or_null("/root/GameManager")
	room_transition_manager = get_node_or_null("/root/RoomTransitionManager")
	dialogue_ui = get_node_or_null("/root/Main/HUD/DialogueUI")
	audio_manager = get_node_or_null("/root/AudioManager")
	
	# Connect signal
	area_entered.connect(_on_area_entered)
	
	print("Door trigger ready - Target: %s, Locked: %s" % [target_room, is_locked])

func _on_area_entered(area):
	if area.name == "PlayerCollision":
		attempt_transition()

func attempt_transition():
	# Check if locked
	if is_locked:
		if requires_flag and game_manager and "npc_completed" in game_manager:
			if not game_manager.npc_completed.get(requires_flag, false):
				show_locked_message()
				return
		elif requires_flag == "":
			# Generic lock
			show_locked_message()
			return
		else:
			# Fallback if systems aren't ready
			show_locked_message()
			return
	
	# Check room access rules
	if not is_room_accessible():
		show_access_denied()
		return
	
	# Attempt transition
	if room_transition_manager and room_transition_manager.has_method("change_room"):
		var success = await room_transition_manager.change_room(target_room)
		if success and audio_manager:
			audio_manager.play_sfx("door_unlock")
	else:
		print("ERROR: RoomTransitionManager not found or change_room method missing!")

func is_room_accessible() -> bool:
	if not game_manager or not "npc_completed" in game_manager:
		return true # Allow transition if game manager isn't ready for testing
		
	# Room-specific access checks
	match target_room:
		"disco":
			# Must complete bar quests
			var bar_complete = (
				game_manager.npc_completed.get("bartender", false) and
				game_manager.npc_completed.get("frat_bro", false) and
				game_manager.npc_completed.get("fat_chud", false)
			)
			if not bar_complete:
				return false
		
		"vip":
			# Must complete DJ quest
			if not game_manager.npc_completed.get("dj", false):
				return false
		
		"office":
			# Must complete champagne pop
			if not game_manager.npc_completed.get("champagne_pop", false):
				return false
	
	return true

func show_locked_message():
	print("Door locked: %s" % lock_message)
	if audio_manager:
		audio_manager.play_sfx("error")
	
	# TODO: Display lock message on screen near player/door

func show_access_denied():
	print("Access denied to room: %s" % target_room)
	if audio_manager:
		audio_manager.play_sfx("error")
	
	# TODO: Display access denied message on screen

func unlock():
	is_locked = false
	print("Door unlocked!")
	if audio_manager:
		audio_manager.play_sfx("door_unlock")

func lock():
	is_locked = true
	print("Door locked!")

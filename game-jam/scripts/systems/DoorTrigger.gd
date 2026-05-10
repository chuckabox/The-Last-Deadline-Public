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
var dialogue_ui: Control
var audio_manager: Node

# Interaction State
var player_in_range: bool = false
var hud: Node

func _ready():
	# Get references safely
	game_manager = get_node_or_null("/root/GameManager")
	room_transition_manager = get_node_or_null("/root/RoomTransitionManager")
	dialogue_ui = get_node_or_null("/root/Main/HUD/DialogueUI")
	hud = get_node_or_null("/root/Main/HUD")
	audio_manager = get_node_or_null("/root/AudioManager")
	
	# Connect signals
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not area_exited.is_connected(_on_area_exited):
		area_exited.connect(_on_area_exited)
	
	# Also connect body signals for backup
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	

	
	print("Door trigger ready - Target: %s, Locked: %s" % [target_room, is_locked])



func _input(event):
	if player_in_range and event.is_action_pressed("ui_interact"):
		print("DoorTrigger: Interaction key 'E' pressed!")
		attempt_transition()

func _on_area_entered(area):
	print("DoorTrigger: Area entered: ", area.name)
	if area.name == "PlayerCollision" or area.get_parent().name == "Player":
		_set_player_in_range(true)

func _on_area_exited(area):
	if area.name == "PlayerCollision" or area.get_parent().name == "Player":
		_set_player_in_range(false)

func _on_body_entered(body):
	print("DoorTrigger: Body entered: ", body.name)
	if body.name == "Player":
		_set_player_in_range(true)

func _on_body_exited(body):
	if body.name == "Player":
		_set_player_in_range(false)

func _set_player_in_range(value: bool):
	if player_in_range == value: return
	
	player_in_range = value
	print("DoorTrigger: Player in range = ", value)
	
	if value:
		if hud and hud.has_method("show_interaction_prompt"):
			hud.show_interaction_prompt("ui_interact")
	else:
		if hud and hud.has_method("hide_interaction_prompt"):
			hud.hide_interaction_prompt()

func attempt_transition():
	# Check if locked
	if is_locked:
		if requires_flag and game_manager:
			if game_manager.has_method("is_npc_completed"):
				if not game_manager.is_npc_completed(requires_flag):
					show_locked_message()
					return
			elif "npc_completed_status" in game_manager:
				if not game_manager.npc_completed_status.get(requires_flag, false):
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
	if not game_manager:
		return true # Allow transition if game manager isn't ready for testing
		
	# Room-specific access checks
	match target_room:
		"disco":
			# Players can enter the disco room without doing minigames.
			# The DJ will gate the VIP room.
			pass
		
		"vip":
			# Must complete DJ quest
			if game_manager.has_method("is_npc_completed"):
				if not game_manager.is_npc_completed("dj"):
					return false
			elif "npc_completed_status" in game_manager:
				if not game_manager.npc_completed_status.get("dj", false):
					return false
		
		"office":
			# Must complete champagne pop
			if game_manager.has_method("is_npc_completed"):
				if not game_manager.is_npc_completed("champagne_pop"):
					return false
			elif "npc_completed_status" in game_manager:
				if not game_manager.npc_completed_status.get("champagne_pop", false):
					return false
	
	return true

func show_locked_message():
	print("Door locked: %s" % lock_message)
	if audio_manager:
		audio_manager.play_sfx("error")
	
	if hud and hud.has_method("show_warning"):
		hud.show_warning(lock_message)

func show_access_denied():
	print("Access denied to room: %s" % target_room)
	if audio_manager:
		audio_manager.play_sfx("error")
	
	if hud and hud.has_method("show_warning"):
		if target_room == "vip":
			hud.show_warning("You don't have a VIP pass")
		else:
			hud.show_warning("Access Denied")

func unlock():
	is_locked = false
	print("Door unlocked!")
	if audio_manager:
		audio_manager.play_sfx("door_unlock")

func lock():
	is_locked = true
	print("Door locked!")

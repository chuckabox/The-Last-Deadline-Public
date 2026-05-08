extends Node

## Friend Time Degradation
## Automatically updates the Friend's dialogue and behavior as time progresses towards midnight.

# References
var time_manager: Node
var global_state: Node
var current_stage: int = 0

func _ready():
	time_manager = get_node_or_null("/root/TimeManager")
	global_state = get_node_or_null("/root/GlobalStateManager")
	
	if time_manager:
		time_manager.time_updated.connect(_on_time_updated)
	
	print("FriendTimeDegradation initialized")

func _on_time_updated(time_string: String):
	# Extract minutes from HH:MM
	var parts = time_string.split(":")
	if parts.size() < 2: return
	
	var hour = int(parts[0])
	var minute = int(parts[1])
	
	# Mapping time to 4 distinct stages of drunkenness
	# Game window: 11:50 PM - 12:00 AM
	var new_stage = 0
	
	if hour == 12 or hour == 0:
		new_stage = 3 # Midnight (Passed out)
	elif minute >= 58:
		new_stage = 3 # 11:58 (Incoherent)
	elif minute >= 56:
		new_stage = 2 # 11:56 (Slurred)
	elif minute >= 53:
		new_stage = 1 # 11:53 (Urgent / Buzzed)
	else:
		new_stage = 0 # 11:50 (Normal)

	if new_stage != current_stage:
		_apply_stage(new_stage)

func _apply_stage(stage: int):
	current_stage = stage
	if global_state:
		# This flag will be checked in friend.json variants
		global_state.set_flag("friendDrunkStage", stage)
		
		# Also provide a hint flag based on player progress if not too drunk
		if stage < 2:
			_update_progression_hints()
			
	print("Friend updated to Drunk Stage: ", stage)

func _update_progression_hints():
	if not global_state: return
	
	# Provide logic for what the friend should hint at
	var hint = "start"
	
	if global_state.check_flag("djDefeated"):
		hint = "go_to_boss"
	elif global_state.check_flag("fatChudDefeated") and global_state.check_flag("fratBroDefeated"):
		hint = "go_to_dj"
	elif global_state.check_flag("bartenderDefeated"):
		hint = "go_to_room2"
	else:
		hint = "talk_to_bartender"
		
	global_state.set_flag("friendHint", hint)

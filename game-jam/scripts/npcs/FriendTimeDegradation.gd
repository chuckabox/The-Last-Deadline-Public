extends Node

## Friend Time Degradation
## Watches the global clock and pushes per-stage drunk flags into
## GlobalStateManager so friend.json variants can react to the time progressing
## from 11:50 PM toward 12:00 AM.

var time_manager: Node
var global_state: Node
var current_stage: int = 0

func _ready() -> void:
	time_manager = get_node_or_null("/root/TimeManager")
	global_state = get_node_or_null("/root/GlobalStateManager")

	if time_manager:
		time_manager.time_updated.connect(_on_time_updated)

	print("FriendTimeDegradation initialized")

func _on_time_updated(time_string: String) -> void:
	var parts := time_string.split(":")
	if parts.size() < 2:
		return

	var hour := int(parts[0])
	var minute := int(parts[1])

	# Map clock minute to drunk stage (game window: 11:50 PM - 12:00 AM).
	var new_stage := 0
	if hour == 12 or hour == 0:
		new_stage = 3
	elif minute >= 58:
		new_stage = 3
	elif minute >= 56:
		new_stage = 2
	elif minute >= 53:
		new_stage = 1

	if new_stage != current_stage:
		_apply_stage(new_stage)

func _apply_stage(stage: int) -> void:
	current_stage = stage
	if global_state:
		# Cumulative bool flags: friend.json variants check from highest stage
		# down (friendStage3 first, then friendStage2, friendStage1, default).
		global_state.set_flag("friendStage1", stage >= 1)
		global_state.set_flag("friendStage2", stage >= 2)
		global_state.set_flag("friendStage3", stage >= 3)

	print("Friend updated to Drunk Stage: ", stage)

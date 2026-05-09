extends Node

## Global Ending Manager
## Listens for and triggers the 5 possible game endings.

# ===== SIGNALS =====
signal ending_triggered(ending_id: String, title: String, description: String)

# ===== ENDING CONSTANTS =====
const ENDING_PROCRASTINATOR = "procrastinator"
const ENDING_BLACKOUT = "blackout"
const ENDING_DRINK = "drink"
const ENDING_JOB = "job"
const ENDING_ACADEMIC = "academic"

# ===== STATE =====
var current_ending: String = ""
var pending_ending: String = ""

func _ready() -> void:
	add_to_group("managers")
	
	# Connect to TimeManager for the deadline
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		if not time_manager.deadline_reached.is_connected(_on_deadline_reached):
			time_manager.deadline_reached.connect(_on_deadline_reached)
	
	# Connect to GameManager for minigame losses
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		if not game_manager.minigame_lost.is_connected(handle_minigame_loss):
			game_manager.minigame_lost.connect(handle_minigame_loss)
	
	print("EndingManager initialized")


# ===== EVENT LISTENERS =====

## Triggered when the global clock hits 12:00 AM
func _on_deadline_reached() -> void:
	trigger_ending(ENDING_PROCRASTINATOR)

## Should be called by Minigame scripts or MinigameManager when a game is lost
func handle_minigame_loss() -> void:
	var alcohol_system = get_node_or_null("/root/AlcoholSystem")
	if alcohol_system and alcohol_system.current_stage >= 4:
		trigger_ending(ENDING_BLACKOUT)


# ===== PUBLIC TRIGGER METHODS =====

## Main entry point to trigger an ending
func trigger_ending(ending_id: String) -> void:
	if current_ending != "":
		return # Already triggered an ending
		
	current_ending = ending_id
	pending_ending = ending_id
	
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_method("pause_time"):
		time_manager.pause_time()
	
	# If no dialogue is open, we can show it immediately via DialogueUI
	var dialogue_ui = get_node_or_null("/root/Main/HUD/DialogueUI")
	if dialogue_ui and not dialogue_ui.visible:
		dialogue_ui.show_ending_cutscene(ending_id)
		
	var title = ""
	var description = ""
	
	match ending_id:
		ENDING_PROCRASTINATOR:
			title = "The Procrastinator"
			description = "Grade: 0% - Feedback: Late submission not accepted"
			perform_transition(ending_id, title, description)
			
		ENDING_BLACKOUT:
			title = "The Blackout"
			description = "You woke up on a lawn at 8:00 AM with 50 missed calls."
			perform_transition(ending_id, title, description)
			
		ENDING_DRINK:
			title = "The Drink Branch"
			description = "Everything went fuzzy. You woke up at 3:00 AM on the office sofa. The deadline is gone."
			perform_transition(ending_id, title, description)
			
		ENDING_JOB:
			title = "The Job Offer"
			description = "You become the new Floor Manager. You have money, but your degree is abandoned."
			perform_transition(ending_id, title, description)
			
		ENDING_ACADEMIC:
			title = "Academic Weapon"
			description = "Assignment 2 due in 6 hours."
			perform_transition(ending_id, title, description)
	
	ending_triggered.emit(ending_id, title, description)
	print("Ending Triggered: %s - %s" % [title, description])


# ===== INTERNAL METHODS =====

func perform_transition(id: String, _title: String, _description: String) -> void:
	var path = ""
	
	match id:
		ENDING_PROCRASTINATOR:
			path = "res://scenes/endings/procrastinator_ending/Ending_Procrastinator.tscn"
		ENDING_BLACKOUT:
			path = "res://scenes/endings/blackout_ending/Ending_Blackout.tscn"
		ENDING_DRINK:
			path = "res://scenes/endings/drunk_mistake_ending/Ending_DrunkMistake.tscn"
		ENDING_JOB:
			path = "res://scenes/endings/floor_manager_ending/Ending_FloorManager.tscn"
		ENDING_ACADEMIC:
			path = "res://scenes/endings/academic_weapon_ending/Ending_AcademicWeapon.tscn"
			
	if path != "":
		get_tree().change_scene_to_file(path)
	else:
		push_error("EndingManager: No path defined for ending %s" % id)

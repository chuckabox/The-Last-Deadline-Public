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

func _ready() -> void:
	add_to_group("managers")
	
	# Connect to TimeManager for the deadline
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		if not time_manager.deadline_reached.is_connected(_on_deadline_reached):
			time_manager.deadline_reached.connect(_on_deadline_reached)
	
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
	var title = ""
	var description = ""
	
	match ending_id:
		ENDING_PROCRASTINATOR:
			title = "The Procrastinator"
			description = "Grade: 0% - Feedback: Late submission not accepted"
			_perform_transition(ending_id, title, description)
			
		ENDING_BLACKOUT:
			title = "The Blackout"
			description = "You woke up on a lawn at 8:00 AM with 50 missed calls."
			_perform_transition(ending_id, title, description)
			
		ENDING_DRINK:
			title = "The Drink Branch"
			description = "Everything went fuzzy. You woke up at 3:00 AM on the office sofa. The deadline is gone."
			_perform_transition(ending_id, title, description)
			
		ENDING_JOB:
			title = "The Job Offer"
			description = "You become the new Floor Manager. You have money, but your degree is abandoned."
			_perform_transition(ending_id, title, description)
			
		ENDING_ACADEMIC:
			title = "Academic Weapon"
			description = "Assignment 2 due in 6 hours."
			_perform_transition(ending_id, title, description)
	
	ending_triggered.emit(ending_id, title, description)
	print("Ending Triggered: %s - %s" % [title, description])


# ===== INTERNAL METHODS =====

func _perform_transition(id: String, title: String, description: String) -> void:
	var game_manager = get_node_or_null("/root/GameManager")
	
	# Special cinematic/visual logic for each ending
	match id:
		ENDING_PROCRASTINATOR:
			# Cut to player crying on floor (Visual implementation would be in the Ending Scene)
			pass
		ENDING_BLACKOUT:
			# Cut to waking up on lawn
			pass
		ENDING_DRINK:
			# Fade to black
			pass
		ENDING_ACADEMIC:
			# Cinematic of sprinting home
			pass
			
	if game_manager:
		game_manager.change_scene("ending")
	else:
		# Fallback if GameManager is not found
		get_tree().change_scene_to_file("res://scenes/EndingScene.tscn")

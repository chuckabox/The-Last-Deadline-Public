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
		
	# Clear drunk visual effects
	var alcohol_system = get_node_or_null("/root/AlcoholSystem")
	if alcohol_system and alcohol_system.has_method("reset"):
		alcohol_system.reset()
	
	# Close any open dialogue so we go straight to the ending scene with no
	# intermediate black-screen cutscene or text reveal.
	var dialogue_ui = get_node_or_null("/root/Main/HUD/DialogueUI")
	if dialogue_ui and dialogue_ui.has_method("close_dialogue"):
		dialogue_ui.close_dialogue()


	# Play ending music
	var music = get_node_or_null("/root/MusicManager")
	if music:
		match ending_id:
			ENDING_PROCRASTINATOR: music.play_track("procrastinator")
			ENDING_BLACKOUT: music.play_track("blackout")
			ENDING_DRINK: music.play_track("blackout") # Use blackout for drink failure
			ENDING_JOB: music.play_track("job_offer")
			ENDING_ACADEMIC: music.play_track("academic_weapon")
		
	var title = ""
	var description = ""
	
	match ending_id:
		ENDING_PROCRASTINATOR:
			title = "The Procrastinator"
			description = "Grade: 0% - Feedback: Late submission not accepted"
			perform_transition(ending_id, title, description)
			
		ENDING_BLACKOUT:
			title = "The Blackout"
			description = "You woke up on a lawn at 8:00 AM with 16 missed calls."
			perform_transition(ending_id, title, description)
			
		ENDING_DRINK:
			title = "The Drink Branch"
			description = "Everything went fuzzy. You woke up at 2:00AM on the streets. The deadline is gone."
			perform_transition(ending_id, title, description)
			
		ENDING_JOB:
			title = "The Job Offer"
			description = "You take the Job offer. This is objectively the worst ending."
			perform_transition(ending_id, title, description)
			
		ENDING_ACADEMIC:
			title = "Academic Weapon"
			description = "After successfully submitting your assignment despite all the odds, you head to the real club... Your room."
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
		# Defer the scene change so that all signal callbacks finish
		# processing before the current tree is freed. This prevents
		# crashes when a minigame loss triggers the ending mid-signal-chain.
		get_tree().call_deferred("change_scene_to_file", path)
	else:
		push_error("EndingManager: No path defined for ending %s" % id)

extends Node

## Intro Cutscene Manager
## Handles the opening sequence: Bar ambiance -> Friend Dialogue -> Phone Notification -> Panic.

# References
var dialogue_ui: Control
var phone_ui: Control # We will build this in a later step
var time_manager: Node
var game_manager: Node

func _ready():
	# Initial references
	dialogue_ui = get_tree().root.get_node_or_null("Main/HUD/DialoguePanel")
	time_manager = get_node_or_null("/root/TimeManager")
	game_manager = get_node_or_null("/root/GameManager")
	
	# Make sure time is paused during intro
	if time_manager:
		time_manager.pause_time()
	
	# Wait for a brief moment of bar ambiance
	await get_tree().create_timer(2.0).timeout
	start_sequence()

func start_sequence():
	# 1. Start dialogue with Friend (Intro part)
	if dialogue_ui:
		# The "talk" node in friend.json sets up the scene
		dialogue_ui.show_dialogue("friend", "talk")
		
		# Connect to when the dialogue closes to trigger the phone event
		# Note: The 'friend.json' logic might lead to 'phoneTrigger' automatically, 
		# but we want to ensure the phone UI pops up.
		dialogue_ui.dialogue_closed.connect(_on_intro_finished, CONNECT_ONE_SHOT)
	else:
		push_error("IntroCutscene: DialogueUI not found!")
		_on_intro_finished()

func _on_intro_finished():
	# 2. Check if we need to show the phone notification manually
	# The friend.json 'talk' node ends by going to 'phoneTrigger'.
	# We'll wait a split second for the next part of dialogue to start or for the player to react.
	
	# In our implementation, we'll let the Dialogue system handle the flow, 
	# but we use this script to manage the 'Control' handover and Clock start.
	
	# We listen for the FINAL exit of the friend's intro dialogue
	# which happens after the "I gotta go!" option in 'panic' node.
	dialogue_ui.dialogue_closed.connect(_on_panic_finished, CONNECT_ONE_SHOT)

func _on_panic_finished():
	# 3. Start the Clock
	print("Intro Cutscene Finished. Starting the countdown!")
	if time_manager:
		time_manager.resume_time()
	
	# 4. Enable player movement/interaction
	if game_manager:
		game_manager.is_game_started = true
	
	# 5. Clean up cutscene controller
	queue_free()

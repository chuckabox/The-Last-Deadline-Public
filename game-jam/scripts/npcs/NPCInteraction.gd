extends Node2D

class_name NPCInteraction

# NPC Identity
@export var npc_id: String = "npc_name"  # e.g., "bartender", "dj"
@export var npc_display_name: String = "NPC"  # Display name
@export var portrait_texture: Texture2D = null  # Character portrait

# Interaction
var player_in_range = false
var is_interacting = false
var has_completed_quest = false

# References
var dialogue_ui: Panel
var game_manager: Node
var alcohol_system: Node
var audio_manager: Node
var animated_sprite: AnimatedSprite2D
var interaction_area: Area2D

# Signals
signal interaction_started(npc_id)
signal quest_completed(npc_id)
signal dialogue_ended()

func _ready():
	# Get child nodes (assuming standard setup)
	interaction_area = get_node_or_null("InteractionArea")
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	
	# Get system references safely
	dialogue_ui = get_node_or_null("/root/Main/HUD/DialogueUI")
	game_manager = get_node_or_null("/root/GameManager")
	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	audio_manager = get_node_or_null("/root/AudioManager")
	
	# Connect area signals
	if interaction_area:
		interaction_area.area_entered.connect(_on_area_entered)
		interaction_area.area_exited.connect(_on_area_exited)
	
	# Check if quest already completed
	if game_manager and "npc_completed" in game_manager:
		has_completed_quest = game_manager.npc_completed.get(npc_id, false)
	
	print("NPC '%s' initialized" % npc_id)

func _input(event):
	if event.is_action_pressed("ui_interact") and player_in_range and not is_interacting:
		interact()

func _on_area_entered(area):
	if area.name == "PlayerCollision":
		player_in_range = true
		# Optional: show interaction prompt UI here

func _on_area_exited(area):
	if area.name == "PlayerCollision":
		player_in_range = false

func interact():
	if has_completed_quest:
		print("NPC '%s' quest already completed" % npc_id)
		# We can still talk, but we return early if you want to block repeat interaction
		# return 
	
	is_interacting = true
	emit_signal("interaction_started", npc_id)
	
	# Play talk animation
	play_animation("talk")
	
	# Show dialogue UI
	if dialogue_ui and dialogue_ui.has_method("show_dialogue"):
		dialogue_ui.show_dialogue(npc_id)
		if not dialogue_ui.option_selected.is_connected(_on_dialogue_complete):
			dialogue_ui.option_selected.connect(_on_dialogue_complete)
	else:
		# Fallback just in case dialogue_ui wasn't ready at _ready
		dialogue_ui = get_node_or_null("/root/Main/HUD/DialogueUI")
		if dialogue_ui and dialogue_ui.has_method("show_dialogue"):
			dialogue_ui.show_dialogue(npc_id)
			if not dialogue_ui.option_selected.is_connected(_on_dialogue_complete):
				dialogue_ui.option_selected.connect(_on_dialogue_complete)
		else:
			print("ERROR: Dialogue UI not found!")
	
	if audio_manager:
		audio_manager.play_sfx("notification_ping")

func _on_dialogue_complete(option_index: int, next_node: String):
	is_interacting = false
	emit_signal("dialogue_ended")
	
	# Clean up signal connection
	if dialogue_ui and dialogue_ui.option_selected.is_connected(_on_dialogue_complete):
		dialogue_ui.option_selected.disconnect(_on_dialogue_complete)
	
	# If dialogue ended (no next node), mark quest as potential completion
	if next_node == "" or next_node == "exit":
		# Subclass can override to determine actual completion
		check_quest_completion()

func check_quest_completion():
	# Override in subclass to implement specific quest logic
	# Call complete_quest() when ready
	pass

func complete_quest():
	if not has_completed_quest:
		has_completed_quest = true
		if game_manager and game_manager.has_method("mark_npc_completed"):
			game_manager.mark_npc_completed(npc_id)
		emit_signal("quest_completed", npc_id)
		print("Quest completed: %s" % npc_id)

func play_animation(anim_name: String):
	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)

func get_gibberish_text() -> String:
	# Return gibberish based on current alcohol stage
	var stage = 0
	if alcohol_system and "current_stage" in alcohol_system:
		stage = alcohol_system.current_stage
	
	var gibberish_by_stage = {
		0: [
			"I heard the back exit is through the office.",
			"Did you see the DJ?",
			"This place is packed!"
		],
		1: [
			"Is it hot in here?",
			"Everything feels good right now.",
			"I could beat anyone at beer pong!"
		],
		2: [
			"Why is the hallway getting longer?",
			"Do you have water?",
			"I need to sit down..."
		],
		3: [
			"The floor is judging my shoes.",
			"Did the wall just move?",
			"I'm not drunk, you're drunk."
		],
		4: [
			"Zzz... cheese... assignment...",
			"Blargh... what year is it?",
			"I'm not crying, you're a lamp."
		]
	}
	
	var options = gibberish_by_stage.get(stage, gibberish_by_stage[0])
	return options[randi() % options.size()]

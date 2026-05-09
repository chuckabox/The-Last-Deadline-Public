extends Node2D

## Base class for NPC interactions.
## Handles proximity detection, interaction prompt, and dialogue triggering.
class_name NPCInteraction

# NPC Identity
@export var npc_id: String = "npc_name"  # e.g., "bartender", "dj"
@export var npc_name: String = "NPC"     # Display name

# Interaction State
var is_in_range = false
var can_interact = true
var is_interacting = false
var has_completed_quest = false
var prompt_sprite: Sprite2D

# References
var dialogue_ui: Panel
var game_manager: Node
var alcohol_system: Node
var audio_manager: Node
var animated_sprite: AnimatedSprite2D
var collision_area: Area2D

# Signals
signal interaction_started(npc_id)
signal quest_completed(npc_id)
signal interaction_ended(npc_id)

func _ready():
	# Get child nodes with fallbacks
	collision_area = get_node_or_null("Area2D")
	if not collision_area:
		collision_area = get_node_or_null("InteractionArea")
		
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	
	# Get system references safely
	dialogue_ui = get_node_or_null("/root/Main/HUD/DialogueUI")
	game_manager = get_node_or_null("/root/GameManager")
	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	audio_manager = get_node_or_null("/root/AudioManager")
	
	# Connect area signals
	if collision_area:
		if not collision_area.area_entered.is_connected(_on_area_entered):
			collision_area.area_entered.connect(_on_area_entered)
		if not collision_area.area_exited.is_connected(_on_area_exited):
			collision_area.area_exited.connect(_on_area_exited)
	
	# Setup visual prompt
	_setup_prompt()
	
	# Check if quest already completed
	if game_manager:
		if game_manager.has_method("is_npc_completed"):
			has_completed_quest = game_manager.is_npc_completed(npc_id)
		elif "npc_completed_status" in game_manager:
			has_completed_quest = game_manager.npc_completed_status.get(npc_id, false)
	
	print("NPC '%s' initialized" % npc_id)

func _setup_prompt():
	if has_node("InteractionPrompt"): return
	
	prompt_sprite = Sprite2D.new()
	prompt_sprite.name = "InteractionPrompt"
	prompt_sprite.texture = load("res://assets/ui/Keyboard Letters and Symbols.png")
	prompt_sprite.region_enabled = true
	# 'E' key is at 64, 32 in the 16x16 grid
	prompt_sprite.region_rect = Rect2(64, 32, 16, 16)
	prompt_sprite.position = Vector2(0, -50) # Position above the NPC
	prompt_sprite.scale = Vector2(1.5, 1.5)
	prompt_sprite.hide()
	prompt_sprite.z_index = 10
	add_child(prompt_sprite)

func _input(event):
	if event.is_action_pressed("ui_interact") and is_in_range and can_interact and not is_interacting:
		# Don't trigger if dialogue is already open from another NPC or cutscene
		if dialogue_ui and dialogue_ui.visible:
			return
		interact()

func _on_area_entered(area):
	if area.name == "PlayerCollision":
		is_in_range = true
		_update_prompt_visibility()

func _on_area_exited(area):
	if area.name == "PlayerCollision":
		is_in_range = false
		_update_prompt_visibility()

func _update_prompt_visibility():
	if not prompt_sprite: return
	
	if is_in_range and not is_interacting and can_interact:
		if not prompt_sprite.visible:
			prompt_sprite.show()
			prompt_sprite.scale = Vector2.ZERO
			var t = create_tween()
			t.tween_property(prompt_sprite, "scale", Vector2(1.5, 1.5), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		prompt_sprite.hide()

func interact():
	if has_completed_quest:
		print("NPC '%s' quest already completed" % npc_id)
	
	is_interacting = true
	_update_prompt_visibility()
	emit_signal("interaction_started", npc_id)
	
	# Play talk animation
	play_animation("talk")
	
	# Find DialogueUI if not already set
	if not dialogue_ui:
		dialogue_ui = get_node_or_null("/root/Main/HUD/DialogueUI")
	
	if dialogue_ui and dialogue_ui.has_method("show_dialogue"):
		dialogue_ui.show_dialogue(npc_id)
		if not dialogue_ui.dialogue_closed.is_connected(_on_dialogue_complete):
			dialogue_ui.dialogue_closed.connect(_on_dialogue_complete)
	else:
		print("ERROR: Dialogue UI not found at /root/Main/HUD/DialogueUI")
	
	if audio_manager and audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx("notification_ping")

func _on_dialogue_complete():
	is_interacting = false
	emit_signal("interaction_ended", npc_id)
	_update_prompt_visibility()
	
	if dialogue_ui and dialogue_ui.dialogue_closed.is_connected(_on_dialogue_complete):
		dialogue_ui.dialogue_closed.disconnect(_on_dialogue_complete)
	
	check_quest_completion()

func check_quest_completion():
	# Override in subclass to implement specific quest logic
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
		0: ["I heard the back exit is through the office.", "Did you see the DJ?", "This place is packed!"],
		1: ["Is it hot in here?", "Everything feels good right now.", "I could beat anyone at beer pong!"],
		2: ["Why is the hallway getting longer?", "Do you have water?", "I need to sit down..."],
		3: ["The floor is judging my shoes.", "Did the wall just move?", "I'm not drunk, you're drunk."],
		4: ["Zzz... cheese... assignment...", "Blargh... what year is it?", "I'm not crying, you're a lamp."]
	}
	
	var options = gibberish_by_stage.get(stage, gibberish_by_stage[0])
	return options[randi() % options.size()]

func face_direction(direction: Vector2):
	if animated_sprite:
		if direction.x > 0:
			animated_sprite.flip_h = false
		elif direction.x < 0:
			animated_sprite.flip_h = true

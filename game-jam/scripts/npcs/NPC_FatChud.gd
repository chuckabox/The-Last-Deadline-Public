extends Node2D

# NPC Property
@export var npc_name = "Fat Chud"
@export var npc_id = "fat_chud"
var can_interact = true
var is_in_range = false

# References
var dialogue_ui: Panel
var animated_sprite: AnimatedSprite2D
var collision_area: Area2D
var game_manager: Node
var alcohol_system: Node

# Signals
signal interaction_started(npc_name)
signal interaction_ended(npc_name)
signal quest_completed(npc_name)

func _ready():
	dialogue_ui = get_node_or_null("/root/Main/HUD/DialogueUI")
	collision_area = get_node_or_null("Area2D")
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	game_manager = get_node_or_null("/root/GameManager")
	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	
	if collision_area:
		collision_area.area_entered.connect(_on_area_entered)
		collision_area.area_exited.connect(_on_area_exited)
	
	print("NPC %s initialized" % npc_name)

func _input(event):
	if event.is_action_pressed("ui_interact") and is_in_range and can_interact:
		on_player_interact()

func _on_area_entered(area):
	if area.name == "PlayerCollision":
		is_in_range = true

func _on_area_exited(area):
	if area.name == "PlayerCollision":
		is_in_range = false

func on_player_interact():
	if not can_interact or not is_in_range:
		return
	
	emit_signal("interaction_started", npc_name)
	
	if not dialogue_ui:
		dialogue_ui = get_node_or_null("/root/Main/HUD/DialogueUI")
	
	if dialogue_ui and dialogue_ui.has_method("show_dialogue"):
		dialogue_ui.show_dialogue(npc_id)
		if not dialogue_ui.dialogue_closed.is_connected(_on_dialogue_ended):
			dialogue_ui.dialogue_closed.connect(_on_dialogue_ended)
	else:
		print("ERROR: Dialogue UI not found at /root/Main/HUD/DialogueUI")
	
	if animated_sprite:
		animated_sprite.play("talk")

func _on_dialogue_ended():
	emit_signal("interaction_ended", npc_name)
	if dialogue_ui and dialogue_ui.dialogue_closed.is_connected(_on_dialogue_ended):
		dialogue_ui.dialogue_closed.disconnect(_on_dialogue_ended)

func complete_quest():
	if game_manager and game_manager.has_method("mark_npc_completed"):
		game_manager.mark_npc_completed(npc_id)
	emit_signal("quest_completed", npc_name)

func get_gibberish_text() -> String:
	var stage = 0
	if alcohol_system and "current_stage" in alcohol_system:
		stage = alcohol_system.current_stage
	
	var gibberish_by_stage = {
		0: ["I heard the back exit is through the office.", "Did you hear the music?", "This place is packed!"],
		1: ["Is it hot in here?", "Everything feels good right now.", "I think I could beat anyone at beer pong!"],
		2: ["Why is the hallway getting longer?", "Do you have water?", "I need to sit down..."],
		3: ["The floor is judging my shoes.", "Did the wall just move?", "I'm not drunk, you're drunk."],
		4: ["Zzz... cheese... assignment...", "Blargh... what year is it?", "I'm not crying, you're a lamp."]
	}
	
	var options = gibberish_by_stage.get(stage, gibberish_by_stage[0])
	return options[randi() % options.size()]

func play_animation(anim_name: String):
	if animated_sprite:
		animated_sprite.play(anim_name)

func face_direction(direction: Vector2):
	if animated_sprite:
		if direction.x > 0:
			animated_sprite.flip_h = false
		elif direction.x < 0:
			animated_sprite.flip_h = true

extends NPCInteraction

## Generic Named NPC script.
## Attach this to any CharacterBody2D NPC that needs simple dialogue.
## Set the exported npc_id and npc_display_name in the Inspector, or
## override them in a subclass _ready().
##
## This script also creates an InteractionArea at runtime if one doesn't
## already exist, so you don't need to manually add Area2D nodes to the scene.
## A small speech bubble animation floats above the NPC's head.

@export var npc_display_name: String = ""

var _named_bubble: AnimatedSprite2D

func _ready():
	# Use the display name for npc_name if set
	if npc_display_name != "":
		npc_name = npc_display_name
	
	# Ensure an InteractionArea exists (creates one if missing)
	if not get_node_or_null("InteractionArea") and not get_node_or_null("Area2D"):
		var area = Area2D.new()
		area.name = "InteractionArea"
		var shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 40.0
		shape.shape = circle
		area.add_child(shape)
		add_child(area)
	
	super._ready()
	_setup_named_bubble()

func _setup_named_bubble():
	if has_node("SpeechBubble"):
		return
	
	var tex = load("res://assets/npc/tiny-speech-indicators/speech_bubble_animation-11x11.png")
	if not tex:
		return
	
	var frames = SpriteFrames.new()
	var frame_size = 11
	for i in range(8):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_size, 0, frame_size, frame_size)
		frames.add_frame("default", atlas)
	frames.set_animation_speed("default", 6.0)
	
	_named_bubble = AnimatedSprite2D.new()
	_named_bubble.name = "SpeechBubble"
	_named_bubble.sprite_frames = frames
	_named_bubble.position = Vector2(0, -35)
	_named_bubble.scale = Vector2(2.5, 2.5)
	_named_bubble.z_index = 100
	add_child(_named_bubble)
	_named_bubble.play("default")
	
	# Bobbing animation
	var t = create_tween().set_loops()
	t.tween_property(_named_bubble, "position", Vector2(0, -38), 0.8).set_trans(Tween.TRANS_SINE)
	t.tween_property(_named_bubble, "position", Vector2(0, -35), 0.8).set_trans(Tween.TRANS_SINE)

func check_quest_completion():
	pass


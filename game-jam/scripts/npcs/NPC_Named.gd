extends NPCInteraction

## Generic Named NPC script.
## Attach this to any CharacterBody2D NPC that needs simple dialogue.
## Set the exported npc_id and npc_display_name in the Inspector, or
## override them in a subclass _ready().
##
## This script also creates an InteractionArea at runtime if one doesn't
## already exist, so you don't need to manually add Area2D nodes to the scene.

@export var npc_display_name: String = ""

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

func check_quest_completion():
	pass

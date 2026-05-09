extends NPCInteraction

# NPC_DJ.gd - Specialization for the DJ.

func _ready():
	npc_name = "DJ"
	npc_id = "dj"
	
	super._ready()

func check_quest_completion():
	# DJ quest involves the player dancing or something similar
	pass

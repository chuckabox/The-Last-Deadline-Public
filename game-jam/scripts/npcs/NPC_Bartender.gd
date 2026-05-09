extends NPCInteraction

# NPC_Bartender.gd - Specialization for the Bartender.

func _ready():
	npc_name = "Bartender"
	npc_id = "bartender"
	
	super._ready()

func check_quest_completion():
	pass

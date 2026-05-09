extends NPCInteraction

# NPC_Friend.gd - Specialization for the Friend character (Homeboy).

func _ready():
	npc_name = "Homeboy"
	npc_id = "friend"
	
	super._ready()

func check_quest_completion():
	pass

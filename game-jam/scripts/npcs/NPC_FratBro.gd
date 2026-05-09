extends NPCInteraction

# NPC_FratBro.gd - Specialization for the Frat Bro character.

func _ready():
	# Set inherited variables
	npc_name = "Frat Bro"
	npc_id = "frat_bro"
	
	super._ready()

func check_quest_completion():
	pass

extends NPCInteraction

# NPC_FratBro.gd - Specialization for the Frat Bro character.
# Most logic is inherited from NPCInteraction.

func _ready():
	# Character-specific values
	npc_name = "Frat Bro"
	npc_id = "frat_bro"
	
	# Call base class _ready to handle setup
	super._ready()

# Add any frat-bro specific quest logic here
func check_quest_completion():
	pass

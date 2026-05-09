extends Control

# Reference the nodes we just created
@onready var text_label = $DialogueBox/DialogueText
@onready var btn_stop = $DialogueBox/OptionsContainer/OptionStop
@onready var btn_drunk = $DialogueBox/OptionsContainer/OptionGibberish
@onready var btn_next = $DialogueBox/OptionsContainer/OptionProgress

var drunk_lines = ["I... I love you, man.", "Where's the floor?", "Is that a cat?"]

func _ready():
	# Set up the buttons
	btn_stop.text = "Leave"
	btn_drunk.text = "???"
	btn_next.text = "Talk"
	
	# Connect the buttons to functions
	btn_stop.pressed.connect(_on_stop_pressed)
	btn_drunk.pressed.connect(_on_drunk_pressed)
	btn_next.pressed.connect(_on_progress_pressed)

func start_dialogue(npc_name, main_text):
	self.show() # Show the UI
	text_label.text = main_text

func _on_stop_pressed():
	self.hide() # Close the dialogue

func _on_drunk_pressed():
	text_label.text = drunk_lines.pick_random()

func _on_progress_pressed():
	# This is where you check the Global script
	if Global.minigames_won == 0:
		text_label.text = "Go talk to the Bartender first!"
	else:
		text_label.text = "Great job, head to the disco."

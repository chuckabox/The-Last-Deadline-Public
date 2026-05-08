extends Node

## Gibberish Database
## Stores ambient dialogue lines that appear on the middle button of the dialogue UI,
## changing based on the player's alcohol stage.

const LINES = {
	0: [ # Stage 0 (Normal)
		"I heard the back exit is through the office.",
		"Someone said the doors are timed-locked.",
		"I'm just here for the music.",
		"The DJ only talks to people with 'clout.' Good luck with that.",
		"I heard the Owner keeps the back key in a safe made of gold. Probably a lie.",
		"Did you see the bouncer? He looks like he eats bricks for breakfast."
	],
	1: [ # Stage 1 (The Buzz)
		"Everything is just... a little bit better right now.",
		"I feel like I could win at Beer Pong against a pro!",
		"Is the floor moving? Like, in a good way?",
		"Is it hot in here, or is it just the 400 people breathing on me?",
		"I think I just saw a guy pour a beer into his shoe. Club life, man.",
		"You ever feel like you're in a video game? No? Me neither."
	],
	2: [ # Stage 2 (Tunnel Vision)
		"Why is the hallway getting longer?",
		"Wait, did I leave my stove on? I don't even have a stove.",
		"I need a water. Do you have three dollars?",
		"I'm trying to find the exit, but every time I turn around, there's just more bar.",
		"Why is your face doing that? You know... the thing? Never mind."
	],
	3: [ # Stage 3 (The Spin)
		"I tried to tell the wall a joke but it didn't laugh.",
		"If I close one eye, there are two of you.",
		"Who invited the floor to hit me in the face?",
		"The floor is definitely judging my shoes right now. I can feel it.",
		"Don't look now, but the DJ is actually three toddlers in a trench coat.",
		"I'm not drunk, I'm just... practicing my gravity resistance."
	],
	4: [ # Stage 4 (Blackout)
		"Zzz... the assignment... it's made of cheese...",
		"Blargh... tell my mom... I found the legendary taco...",
		"I'm not crying, you're a lamp.",
		"If I fall down, just leave me here. I live here now. This is my kitchen.",
		"Who put this wall in my way? I want to speak to the manager of walls.",
		"Zzz... 11:59... is that a time or a score? I'm winning..."
	]
}

## Returns a random line for the given alcohol stage
func get_random_line(stage: int) -> String:
	var s = clampi(stage, 0, 4)
	var stage_lines = LINES[s]
	return stage_lines[randi() % stage_lines.size()]

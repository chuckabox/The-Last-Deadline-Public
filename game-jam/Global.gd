extends Node

# These variables store your game's progress
var bac: float = 0.0          # Blood Alcohol Level
var minigames_won: int = 0    # How many games you've finished
var has_vip_card: bool = false # Did the DJ give you the card?
var perfect_run: bool = true  # Changes to false if you lose a game

# This function can be called from anywhere to add BAC
func add_alcohol(amount: float):
	bac += amount
	print("Current BAC is: ", bac)

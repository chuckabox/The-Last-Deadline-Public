extends Control

func _ready():
	print("Blackout Ending")
	
	var text_label = get_node_or_null("TextLabel")
	var music = get_node_or_null("/root/MusicManager")
	
	# Silence the club music
	if music:
		music.stop_music()
	
	if text_label:
		text_label.text = "Everything went black.\n\n..."
		text_label.show()
	
	await get_tree().create_timer(3.0).timeout
	
	if text_label:
		text_label.text = "You woke up on the lawn at 8:00 AM.\nYour phone showed 50 missed calls.\n\nYou failed the deadline."
	
	await get_tree().create_timer(5.0).timeout
	
	# Closing game
	print("Game Over - Blackout Ending reached.")
	get_tree().quit()

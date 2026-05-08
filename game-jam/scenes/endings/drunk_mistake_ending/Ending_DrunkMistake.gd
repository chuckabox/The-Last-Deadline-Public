extends Control

func _ready():
	print("Drunk Mistake Ending")
	
	var text_label = get_node_or_null("TextLabel")
	var music = get_node_or_null("/root/MusicManager")
	
	# Stop the music for the fuzzy fade out
	if music:
		music.stop_music()
	
	if text_label:
		text_label.text = "Everything went fuzzy.\n\n..."
		text_label.show()
	
	await get_tree().create_timer(3.0).timeout
	
	if text_label:
		text_label.text = "You woke up at 3:00 AM on the office sofa.\nThe deadline had passed.\n\nYou failed."
	
	await get_tree().create_timer(5.0).timeout
	
	# Close game
	print("Game Over - Drunk Mistake Ending reached.")
	get_tree().quit()

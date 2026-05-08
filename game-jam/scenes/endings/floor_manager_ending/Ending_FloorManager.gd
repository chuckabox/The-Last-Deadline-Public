extends Control

func _ready():
	print("Floor Manager Ending")
	
	var text_label = get_node_or_null("TextLabel")
	var music = get_node_or_null("/root/MusicManager")
	
	# Dim the music for a more somber mood
	if music:
		music.volume_db = -25.0
	
	if text_label:
		text_label.text = "You became the new Floor Manager.\n\nYou have money, but your degree is abandoned.\n\nA year later, you're still pouring drinks\nand wondering what could have been."
		text_label.show()
	
	# Give the player more time to read this longer ending
	await get_tree().create_timer(7.0).timeout
	
	# End game
	print("Ending - Floor Manager reached.")
	get_tree().quit()

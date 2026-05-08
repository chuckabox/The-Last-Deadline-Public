extends Control

func _ready():
	print("Procrastinator Ending")
	
	var text_label = get_node_or_null("TextLabel")
	var phone_label = get_node_or_null("PhoneLabel")
	
	# Reference managers
	var music = get_node_or_null("/root/MusicManager")
	var sfx = get_node_or_null("/root/SFXManager")
	
	# Stop all music for dramatic effect
	if music:
		music.stop_music()
	
	# Animate sequence
	await get_tree().create_timer(1.0).timeout
	if text_label:
		text_label.show()
		text_label.text = "The clock struck midnight."
	
	await get_tree().create_timer(2.0).timeout
	if text_label:
		text_label.text = "You never made it out."
	
	await get_tree().create_timer(2.0).timeout
	
	# Play vibration sound if available
	if sfx:
		sfx.play_sfx("phone_vibrate")
		
	if phone_label:
		phone_label.show()
		phone_label.text = "Grade: 0% - Late submission not accepted."
	
	await get_tree().create_timer(4.0).timeout
	
	# Ending the game
	print("Game Over - Procrastinator Ending reached.")
	get_tree().quit()

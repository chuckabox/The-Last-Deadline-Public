extends Control

func _ready():
	print("Academic Weapon Ending")
	
	var text_label = get_node_or_null("TextLabel")
	var clock_label = get_node_or_null("ClockLabel")
	
	# System references for feedback
	var music = get_node_or_null("/root/MusicManager")
	var sfx = get_node_or_null("/root/SFXManager")
	
	if text_label:
		text_label.text = "You sprinted out the back door.\n\n..."
		text_label.show()
	
	await get_tree().create_timer(2.0).timeout
	
	if clock_label:
		clock_label.show()
		clock_label.text = "11:59:55"
	
	# Count down the final seconds
	for i in range(5):
		await get_tree().create_timer(1.0).timeout
		if clock_label:
			clock_label.text = "11:59:%02d" % (54 - i)
		if sfx:
			sfx.play_sfx("menu_scroll") # Play a beep sound
	
	await get_tree().create_timer(1.0).timeout
	
	if sfx:
		sfx.play_sfx("sequence_correct") # Success sound
		
	if clock_label:
		clock_label.text = "SUBMITTED!"
		clock_label.add_theme_color_override("font_color", Color.GREEN)
	
	if text_label:
		text_label.text = "You hit submit at 11:59:59 PM.\n\nAssignment 2 is due in 6 hours.\n\nYou're an Academic Weapon."
	
	await get_tree().create_timer(6.0).timeout
	
	# Victory Exit
	print("VICTORY - Academic Weapon Ending reached.")
	get_tree().quit()

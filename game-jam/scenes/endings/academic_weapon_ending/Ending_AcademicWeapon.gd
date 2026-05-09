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
	
	var time_manager = get_node_or_null("/root/TimeManager")
	var final_elapsed = 599
	var start_h = 11
	var start_m = 50
	
	if time_manager:
		time_manager.pause_time()
		final_elapsed = int(time_manager.elapsed_seconds)
		start_h = time_manager.start_hour
		start_m = time_manager.start_minute
		
	var anim_start_elapsed = max(0, final_elapsed - 5)
	
	var get_time_str = func(elapsed: int) -> String:
		var m = start_m + (elapsed / 60)
		var h = start_h
		if m >= 60:
			h += 1
			m = m % 60
		var s = elapsed % 60
		return "%d:%02d:%02d" % [h, m, s]
	
	if clock_label:
		clock_label.show()
		clock_label.text = get_time_str.call(anim_start_elapsed)
	
	# Count up the final seconds
	for i in range(5):
		await get_tree().create_timer(1.0).timeout
		if clock_label:
			clock_label.text = get_time_str.call(anim_start_elapsed + i + 1)
		if sfx:
			sfx.play_sfx("menu_scroll") # Play a beep sound
	
	await get_tree().create_timer(1.0).timeout
	
	if sfx:
		sfx.play_sfx("sequence_correct") # Success sound
		
	if clock_label:
		clock_label.text = "SUBMITTED!"
		clock_label.add_theme_color_override("font_color", Color.GREEN)
	
	var final_time_str = get_time_str.call(final_elapsed)
	var am_pm = "AM" if final_time_str.begins_with("12") else "PM"
	
	if text_label:
		text_label.text = "You hit submit at %s %s.\n\nAssignment 2 is due in 6 hours.\n\nYou're an Academic Weapon." % [final_time_str, am_pm]
	
	await get_tree().create_timer(6.0).timeout
	
	# Victory Exit
	print("VICTORY - Academic Weapon Ending reached.")
	get_tree().quit()

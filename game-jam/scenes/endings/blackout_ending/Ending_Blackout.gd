extends Control

func _ready():
	print("Blackout Ending")
	get_tree().paused = false # Ensure game isn't stuck paused from a minigame/dialogue
	
	# Clear any leftover fade to black from RoomTransitionManager
	var fade_layer = get_tree().get_root().get_node_or_null("FadeLayer")
	if fade_layer:
		fade_layer.queue_free()
	
	var text_label = get_node_or_null("TextLabel")
	var image_rect = get_node_or_null("TextureRect")
	var buttons_container = get_node_or_null("Buttons")
	var music = get_node_or_null("/root/MusicManager")
	
	# Silence the club music
	if music:
		music.stop_music()
	
	# Initial state: hide everything except the first text
	if image_rect:
		image_rect.modulate.a = 0.0
	if buttons_container:
		buttons_container.hide()
		
	if text_label:
		text_label.modulate.a = 0.0
		text_label.text = "Everything went black.\n\n..."
		var t1 = create_tween()
		t1.tween_property(text_label, "modulate:a", 1.0, 1.0)
		
	# Wait for black screen effect
	await get_tree().create_timer(3.0).timeout
	
	if image_rect:
		var tween = create_tween()
		tween.tween_property(image_rect, "modulate:a", 1.0, 1.5)
	
	if text_label:
		var t2 = create_tween()
		t2.tween_property(text_label, "modulate:a", 0.0, 0.5)
		t2.tween_callback(func(): text_label.text = "You woke up on the lawn at 8:00 AM.\nYour phone showed 16 missed calls.\n\nYou failed the deadline.")
		t2.tween_property(text_label, "modulate:a", 1.0, 0.5)
	
	await get_tree().create_timer(3.0).timeout
	
	if buttons_container:
		buttons_container.show()
		
	var menu_btn = get_node_or_null("Buttons/MainMenuButton")
	if menu_btn:
		if not menu_btn.pressed.is_connected(_on_menu_pressed):
			menu_btn.pressed.connect(_on_menu_pressed)

func _on_menu_pressed():
	var menu_path = "res://scenes/ui/MainMenu.tscn"
	if ResourceLoader.exists(menu_path):
		get_tree().change_scene_to_file(menu_path)
	else:
		get_tree().change_scene_to_file("res://Main.tscn")

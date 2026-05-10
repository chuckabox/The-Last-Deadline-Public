extends Control

func _ready():
	print("Floor Manager Ending")
	get_tree().paused = false

	var fade_layer = get_tree().get_root().get_node_or_null("FadeLayer")
	if fade_layer:
		fade_layer.queue_free()

	var music = get_node_or_null("/root/MusicManager")
	if music:
		music.volume_db = -25.0

	var menu_btn = get_node_or_null("Buttons/MainMenuButton")
	if menu_btn and not menu_btn.pressed.is_connected(_on_menu_pressed):
		menu_btn.pressed.connect(_on_menu_pressed)

func _on_menu_pressed():
	var menu_path = "res://scenes/ui/MainMenu.tscn"
	if ResourceLoader.exists(menu_path):
		get_tree().change_scene_to_file(menu_path)
	else:
		get_tree().change_scene_to_file("res://Main.tscn")

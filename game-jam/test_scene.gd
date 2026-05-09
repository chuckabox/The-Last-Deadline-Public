extends SceneTree
func _init():
	var scene = ResourceLoader.load("res://scenes/endings/blackout_ending/Ending_Blackout.tscn")
	if scene:
		var instance = scene.instantiate()
		print("Loaded successfully")
	else:
		print("Failed to load scene")
	quit()

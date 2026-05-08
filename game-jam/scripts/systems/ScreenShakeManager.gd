extends Node

class_name ScreenShakeManager

# References
var camera: Camera2D

# Shake parameters
var shake_intensity = 0.0
var shake_decay_rate = 20.0 # Adjusted for more noticeable decay in physics steps

func _ready():
	add_to_group("effects")
	camera = get_viewport().get_camera_2d()
	print("ScreenShakeManager initialized")

func _physics_process(delta):
	# Refresh camera reference if it changes (common during room transitions)
	if Engine.get_frames_drawn() % 60 == 0:
		camera = get_viewport().get_camera_2d()
		
	if shake_intensity <= 0.0:
		if camera:
			# Smoothly return to zero offset
			camera.offset = camera.offset.lerp(Vector2.ZERO, 0.2)
		return
	
	if camera:
		# Apply random shake offset
		var shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		camera.offset = shake_offset
	
	# Gradually decay the shake intensity
	shake_intensity = max(0.0, shake_intensity - (delta * shake_decay_rate))

func shake(intensity: float, duration: float):
	shake_intensity = intensity
	
	# Auto-stop shake after the specified duration
	await get_tree().create_timer(duration).timeout
	shake_intensity = 0.0

# Convenience functions for game events
func shake_minigame_loss():
	shake(5.0, 0.5)

func shake_deadline_warning():
	shake(3.0, 2.0)

func shake_persistent(intensity: float):
	shake_intensity = intensity  # Persistent shake until manually stopped

func stop_shake():
	shake_intensity = 0.0

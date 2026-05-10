extends PointLight2D

# Controls for the Inspector
@export_group("Movement Settings")
@export var radius: float = 150.0      # How far it wanders
@export var move_speed: float = 2.0    # Speed of wandering
@export var rotate_speed: float = 0.4  # Speed of rotation

@export_group("Visual Settings")
@export var flicker: bool = true       # Should it pulse in brightness?
@export var random_colors: bool = true # Should it cycle colors?

var target_position: Vector2
var start_position: Vector2
var time_passed: float = 0.0

func _ready():
	start_position = position
	_pick_new_target()
	
	# Give each light a random starting rotation so they aren't synced
	rotation = randf_range(0, TAU) 

func _process(delta):
	time_passed += delta
	
	# 1. MOVEMENT: Smoothly move toward the random target
	position = position.move_toward(target_position, move_speed * delta * 60)
	
	# 2. ROTATION: Constant rotation (TAU is a full 360 degree circle)
	rotation += rotate_speed * delta
	
	# 3. ROTATION OFFSET: Add a slight "wobble" to the rotation
	rotation += sin(time_passed * 2.0) * 0.01 
	
	# 4. SCALE PULSE: Makes the beam grow and shrink slightly
	var pulse = 1.0 + (sin(time_passed * 5.0) * 0.1)
	texture_scale = pulse

	# 5. TARGET LOGIC: Pick a new spot when close to the current one
	if position.distance_to(target_position) < 10:
		_pick_new_target()
	
	# 6. OPTIONAL FLICKER: Rapid energy shifts
	if flicker:
		energy = randf_range(0.9, 1.3)
	
	# 7. COLOR CYCLING: Slowly shift through the rainbow
	if random_colors:
		color = Color.from_hsv(fmod(time_passed * 0.1, 1.0), 0.8, 1.0)

func _pick_new_target():
	# Calculate a random point within the allowed radius
	var angle = randf() * TAU
	var distance = randf() * radius
	target_position = start_position + Vector2(cos(angle), sin(angle)) * distance

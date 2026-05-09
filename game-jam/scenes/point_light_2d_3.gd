extends PointLight2D

# How far the light can move from its starting point
@export var radius: float = 200.0
# How fast the light moves
@export var speed: float = 3.0

var target_position: Vector2
var start_position: Vector2

func _ready():
	start_position = position
	_pick_new_target()

func _process(delta):
	# Move the light toward the target position
	position = position.move_toward(target_position, speed * delta * 50)
	
	# If we reached the target, pick a new random spot
	if position.distance_to(target_position) < 5:
		_pick_new_target()
	
	# Optional: Randomly flicker the intensity
	energy = randf_range(0.8, 1.5)

func _pick_new_target():
	# Pick a random spot within a circle around the start
	var random_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	target_position = start_position + (random_offset * randf_range(50, radius))

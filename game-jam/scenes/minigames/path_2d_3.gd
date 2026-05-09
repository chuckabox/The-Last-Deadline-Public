extends Path2D

# This allows you to change the speed in the Inspector window on the right
@export var speed: float = 1.5

func _ready():
	# We hide the ball initially so it doesn't just sit at the start point
	# $PathFollow2D/Ball is the path to your sprite
	$PathFollow2D/Sprite2D.visible = false

func play_arc_animation():
	var follower = $PathFollow2D
	var ball = $PathFollow2D/Sprite2D
	
	# Show the ball and start the animation
	ball.visible = true
	follower.progress_ratio = 0.0
	
	var tween = create_tween()
	tween.tween_property(follower, "progress_ratio", 1.0, speed).set_trans(Tween.TRANS_SINE)
	
	# Delete everything once the ball finishes its arc
	tween.finished.connect(queue_free)

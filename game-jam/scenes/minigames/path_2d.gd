extends Path2D

# This allows you to change the speed in the Inspector window on the right
@export var speed: float = 1.5

func _ready():
	# We hide the ball initially so it doesn't just sit at the start point
	# $PathFollow2D/Ball is the path to your sprite
	$PathFollow2D/Ball.visible = false

func play_arc_animation():
	var follower = $PathFollow2D
	var ball = $PathFollow2D/Ball
	
	# Show the ball and start the animation
	ball.visible = true
	ball.modulate.a = 1.0 # Ensure it's fully visible
	follower.progress_ratio = 0.0
	
	var tween = create_tween()
	# Animate the movement
	tween.tween_property(follower, "progress_ratio", 1.0, speed).set_trans(Tween.TRANS_SINE)
	
	# Animate the fade out as it enters the cup (very quick fade at the end)
	var fade_duration = 0.2
	var fade_start_time = max(0.0, speed - fade_duration)
	tween.parallel().tween_property(ball, "modulate:a", 0.0, fade_duration).set_delay(fade_start_time)
	
	# Delete everything once the ball finishes its arc
	tween.finished.connect(queue_free)

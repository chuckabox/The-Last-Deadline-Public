extends CharacterBody2D

const SPEED = 300.0

func _physics_process(_delta):
	# Get direction from keys
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# 1. HANDLE MOVEMENT LOGIC
	if direction:
		velocity = direction * SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)

	# 2. HANDLE ANIMATION SWITCHING
	if velocity.length() > 0:
		# We are moving!
		$AnimatedSprite2D.play("Walk")
		
		# Flip the sprite left/right based on horizontal movement
		if velocity.x < 0:
			$AnimatedSprite2D.flip_h = true
		elif velocity.x > 0:
			$AnimatedSprite2D.flip_h = false
	else:
		# We are standing still!
		$AnimatedSprite2D.play("Idle")

	# 3. Apply the physics movement
	move_and_slide()

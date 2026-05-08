extends CharacterBody2D

const SPEED = 300.0

func _physics_process(_delta):
	# 1. Get the direction from player input (Arrows or WASD)
	# Go to Project Settings > Input Map to define "ui_left", etc., or use defaults
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# 2. Apply movement
	if direction:
		velocity = direction * SPEED
		$AnimatedSprite2D.play("Walk") # Play your walk animation
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
		$AnimatedSprite2D.play("Idle") # Play idle if not moving

	# 3. Flip the sprite based on direction
	if direction.x < 0:
		$AnimatedSprite2D.flip_h = true
	elif direction.x > 0:
		$AnimatedSprite2D.flip_h = false

	# 4. Move and handle collisions with walls
	move_and_slide()

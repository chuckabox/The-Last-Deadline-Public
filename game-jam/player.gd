extends CharacterBody2D

const SPEED := 300.0

# Movement smoothing — interpolated between sober and drunk by `_drunk` (0..1)
const ACCEL_SOBER := 4000.0      # near-instant directional response
const ACCEL_DRUNK := 600.0
const FRICTION_SOBER := 4000.0
const FRICTION_DRUNK := 200.0    # slides on stop

# Sway: perpendicular drift added to velocity while moving
const SWAY_AMPLITUDE := 30.0     # px/s peak (Reduced from 60)
const SWAY_FREQ := 0.8           # Hz (Reduced from 1.6)

# Turn overshoot: input direction is rotated by up to JITTER_MAX radians
const JITTER_MAX := 0.15

# How fast the smoothed drunk factor follows the actual stage (per second).
const DRUNK_LERP_RATE := 2.0

var alcohol_system: Node
var _drunk: float = 0.0
var _sway_phase: float = 0.0
var can_move: bool = true

func _ready() -> void:
	add_to_group("player")
	alcohol_system = get_node_or_null("/root/AlcoholSystem")

func _physics_process(delta: float) -> void:
	# Disable movement during dialogue, intro cutscene, or if manually frozen
	var dialogue_ui = get_tree().root.get_node_or_null("Main/HUD/DialogueUI")
	if not can_move or (dialogue_ui and dialogue_ui.visible):
		velocity = Vector2.ZERO
		$AnimatedSprite2D.play("Idle")
		move_and_slide()
		return

	_drunk = lerpf(_drunk, _target_drunkness(), delta * DRUNK_LERP_RATE)
	_sway_phase += delta * SWAY_FREQ * TAU

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Turn overshoot: rotate input off-axis when drunk
	if _drunk > 0.0 and input_dir != Vector2.ZERO:
		input_dir = input_dir.rotated(sin(_sway_phase * 1.7) * JITTER_MAX * _drunk)

	var accel: float = lerpf(ACCEL_SOBER, ACCEL_DRUNK, _drunk)
	var friction: float = lerpf(FRICTION_SOBER, FRICTION_DRUNK, _drunk)

	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * SPEED, accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	# Sway: small perpendicular drift while moving
	if _drunk > 0.0 and velocity.length() > 1.0:
		var perp := Vector2(-velocity.y, velocity.x).normalized()
		velocity += perp * sin(_sway_phase) * SWAY_AMPLITUDE * _drunk

	# --- ANIMATION LOGIC START ---
	if velocity.length() > 10.0: # Use a small threshold to avoid jitter
		# Check if vertical movement is stronger than horizontal
		if abs(velocity.y) > abs(velocity.x):
			if velocity.y < 0:
				$AnimatedSprite2D.play("Walk_up")
			else:
				$AnimatedSprite2D.play("Walk_down")
		else:
			# Horizontal movement is stronger
			$AnimatedSprite2D.play("Walk_side")
			
			# Flip horizontal based on velocity
			if velocity.x < 0:
				$AnimatedSprite2D.flip_h = true
			else:
				$AnimatedSprite2D.flip_h = false
	else:
		$AnimatedSprite2D.play("Idle")
	# --- ANIMATION LOGIC END ---

	move_and_slide()

func _target_drunkness() -> float:
	if alcohol_system and "current_stage" in alcohol_system:
		return clampf(float(alcohol_system.current_stage) / 4.0, 0.0, 1.0)
	return 0.0

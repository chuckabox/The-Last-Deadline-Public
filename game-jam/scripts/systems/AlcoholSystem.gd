extends Node

# ===== STATE =====
## Current alcohol level (0.0 to 1.0)
var alcohol: float = 0.0
## Current stage index (0 to 4)
var current_stage: int = 0
## Previous stage (used for the carry-over fade on stage change)
var previous_stage: int = 0
## Time in milliseconds when the stage last changed
var stage_changed_time: float = 0.0

## Per-stage effect intensity (0.0–1.0).
## Current stage is 1.0 (primary strength); the prior stage starts at
## SECONDARY_CARRY and decays to 0.0 on stage exit. Other stages stay 0.0.
## External effect layers (vignette, blur, sway, etc.) read these to scale
## their visuals so transitions don't snap on/off.
var stage_intensities: Array[float] = [1.0, 0.0, 0.0, 0.0, 0.0]

# Active decay tween; killed if a new stage change comes in mid-decay
var _decay_tween: Tween

# ===== SIGNALS =====
signal alcohol_changed(new_value: float, new_stage: int)
signal stage_changed(new_stage: int)
signal stage_intensities_changed(intensities: Array)
signal blackout_warning()

# ===== STAGE DEFINITIONS =====
var stage_thresholds: Dictionary = {
	0: {"min": 0.0, "max": 0.24, "name": "Normal"},
	1: {"min": 0.25, "max": 0.49, "name": "Buzz"},
	2: {"min": 0.50, "max": 0.74, "name": "Tunnel Vision"},
	3: {"min": 0.75, "max": 0.99, "name": "Spin"},
	4: {"min": 1.0, "max": 1.0, "name": "Blackout"}
}

# ===== TUNING =====
const SECONDARY_CARRY := 0.5
const DECAY_DURATION_RAMP_UP := 2.0   # Going up: previous stage lingers (drunker)
const DECAY_DURATION_SOBER := 0.5     # Going down: clears faster (sobering up)


func _ready() -> void:
	add_to_group("managers")
	print("AlcoholSystem initialized")


# ===== METHODS =====

## Increases alcohol level by amount and updates stage
func drink_alcohol(amount: float = 0.25) -> void:
	alcohol = min(1.0, alcohol + amount)
	update_stage()
	alcohol_changed.emit(alcohol, current_stage)
	
	# Play crowd cheer with rising pitch per stage
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play_sfx"):
		var pitch = 1.0 + current_stage * 0.1  # Gets more intense each stage
		sfx.play_sfx("crowd_cheer", 0.0, pitch)

## Decreases alcohol level (e.g. drinking water)
func drink_water() -> void:
	alcohol = max(0.0, alcohol - 0.125)  # 1/8 reduction
	update_stage()
	alcohol_changed.emit(alcohol, current_stage)

## Recalculates current stage and emits signals if it changed
func update_stage() -> void:
	var new_stage: int = calculate_stage(alcohol)
	if new_stage != current_stage:
		previous_stage = current_stage
		current_stage = new_stage
		stage_changed_time = Time.get_ticks_msec()
		_apply_stage_intensities()
		stage_changed.emit(current_stage)

		# Stage 4 is the danger zone: emit a warning for HUD/audio cues only.
		# The actual blackout ending is triggered by EndingManager when the
		# player loses another minigame while at stage 4.
		if current_stage == 4:
			blackout_warning.emit()

## Sets the new intensity layout (current = 1.0, previous = 0.5 → tween → 0.0).
func _apply_stage_intensities() -> void:
	if _decay_tween and _decay_tween.is_valid():
		_decay_tween.kill()

	for i in stage_intensities.size():
		stage_intensities[i] = 0.0
	stage_intensities[current_stage] = 1.0

	if previous_stage == current_stage:
		stage_intensities_changed.emit(stage_intensities)
		return

	stage_intensities[previous_stage] = SECONDARY_CARRY
	stage_intensities_changed.emit(stage_intensities)

	var decay_duration: float = DECAY_DURATION_RAMP_UP if current_stage > previous_stage else DECAY_DURATION_SOBER
	_decay_tween = create_tween()
	_decay_tween.tween_method(_set_previous_intensity, SECONDARY_CARRY, 0.0, decay_duration)

func _set_previous_intensity(v: float) -> void:
	if previous_stage < 0 or previous_stage >= stage_intensities.size():
		return
	stage_intensities[previous_stage] = v
	stage_intensities_changed.emit(stage_intensities)

## Returns the live intensity (0.0–1.0) for a given stage.
func get_stage_intensity(stage: int) -> float:
	if stage < 0 or stage >= stage_intensities.size():
		return 0.0
	return stage_intensities[stage]

## Computes which stage a given alcohol value falls into
func calculate_stage(value: float) -> int:
	for stage in range(5):
		if value >= stage_thresholds[stage]["min"] and value <= stage_thresholds[stage]["max"]:
			return stage
	return 4 # Default to blackout if exceeded

## Returns the human-readable name of the current stage
func get_stage_name() -> String:
	return stage_thresholds[current_stage]["name"]

## Returns the number of seconds spent in the current stage
func get_time_in_stage() -> float:
	return (Time.get_ticks_msec() - stage_changed_time) / 1000.0

## Resets the system back to sober
func reset() -> void:
	if _decay_tween and _decay_tween.is_valid():
		_decay_tween.kill()
	alcohol = 0.0
	current_stage = 0
	previous_stage = 0
	stage_changed_time = Time.get_ticks_msec()
	for i in stage_intensities.size():
		stage_intensities[i] = 0.0
	stage_intensities[0] = 1.0
	alcohol_changed.emit(alcohol, current_stage)
	stage_intensities_changed.emit(stage_intensities)

extends Node

# ===== STATE =====
## Current alcohol level (0.0 to 1.0)
var alcohol: float = 0.0
## Current stage index (0 to 4)
var current_stage: int = 0
## Time in milliseconds when the stage last changed
var stage_changed_time: float = 0.0

# ===== SIGNALS =====
signal alcohol_changed(new_value: float, new_stage: int)
signal stage_changed(new_stage: int)
signal blackout_warning()
signal blackout()

# ===== STAGE DEFINITIONS =====
var stage_thresholds: Dictionary = {
	0: {"min": 0.0, "max": 0.24, "name": "Normal"},
	1: {"min": 0.25, "max": 0.49, "name": "Buzz"},
	2: {"min": 0.50, "max": 0.74, "name": "Tunnel Vision"},
	3: {"min": 0.75, "max": 0.89, "name": "Spin"},
	4: {"min": 0.90, "max": 1.0, "name": "Blackout"}
}


func _ready() -> void:
	add_to_group("managers")
	print("AlcoholSystem initialized")


# ===== METHODS =====

## Increases alcohol level by amount and updates stage
func drink_alcohol(amount: float = 0.25) -> void:
	alcohol = min(1.0, alcohol + amount)
	update_stage()
	alcohol_changed.emit(alcohol, current_stage)

## Decreases alcohol level (e.g. drinking water)
func drink_water() -> void:
	alcohol = max(0.0, alcohol - 0.125)  # 1/8 reduction
	update_stage()
	alcohol_changed.emit(alcohol, current_stage)

## Recalculates current stage and emits signals if it changed
func update_stage() -> void:
	var new_stage: int = calculate_stage(alcohol)
	if new_stage != current_stage:
		current_stage = new_stage
		stage_changed_time = Time.get_ticks_msec()
		stage_changed.emit(current_stage)
		
		# If we hit max stage
		if current_stage == 4:
			blackout_warning.emit()
			blackout.emit()

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
	alcohol = 0.0
	current_stage = 0
	stage_changed_time = Time.get_ticks_msec()
	alcohol_changed.emit(alcohol, current_stage)

extends Node

# ===== STATE =====
## Elapsed real-world seconds since the game started
var elapsed_seconds: float = 0.0
## Whether time is currently paused
var is_paused: bool = true

# ===== CONSTANTS (10-Minute Real-Time System) =====
# Start time: 11:50 PM
var start_hour: int = 11
var start_minute: int = 50

# 10 minutes total (11:50 to 12:00)
var warning_yellow_time: float = 8.0 * 60.0  # 11:58 PM
var warning_red_time: float = 9.0 * 60.0     # 11:59 PM
var deadline_time: float = 10.0 * 60.0       # 12:00 AM

# Internal flags so we only emit warnings once
var _warned_yellow: bool = false
var _warned_red: bool = false
var _deadline_reached: bool = false

# ===== SIGNALS =====
signal time_updated(current_time: String)  # Format: "11:55"
signal warning_yellow()                    # 11:58 PM
signal warning_red()                       # 11:59 PM
signal deadline_reached()                  # 12:00 AM


func _ready() -> void:
	add_to_group("managers")
	print("TimeManager initialized - Game starts at 11:50 PM")


func _process(delta: float) -> void:
	if is_paused or _deadline_reached:
		return
	
	# We are using 1:1 real-time (10 minutes actual gameplay)
	elapsed_seconds += delta
	
	# Check for key warning times
	if elapsed_seconds >= warning_yellow_time and not _warned_yellow:
		_warned_yellow = true
		warning_yellow.emit()
	
	if elapsed_seconds >= warning_red_time and not _warned_red:
		_warned_red = true
		warning_red.emit()
	
	# Check for deadline
	if elapsed_seconds >= deadline_time and not _deadline_reached:
		_deadline_reached = true
		elapsed_seconds = deadline_time # Cap the visual timer
		deadline_reached.emit()
		pause_time()
	
	time_updated.emit(get_time_string())


# ===== METHODS =====

## Returns the current time formatted as "HH:MM" (e.g. "11:55" or "12:00")
func get_time_string() -> String:
	var total_seconds: int = int(elapsed_seconds)
	var current_m: int = start_minute + (total_seconds / 60)
	var current_h: int = start_hour
	
	if current_m >= 60:
		current_h += 1
		current_m = current_m % 60
	
	return "%d:%02d" % [current_h, current_m]

## Returns the number of full minutes left until deadline
func get_minutes_remaining() -> int:
	return max(0, int((deadline_time - elapsed_seconds) / 60))

## Returns the seconds part of the countdown timer
func get_seconds_remaining() -> int:
	return max(0, int(deadline_time - elapsed_seconds) % 60)

## Pauses the countdown clock
func pause_time() -> void:
	is_paused = true

## Resumes the countdown clock
func resume_time() -> void:
	if not _deadline_reached:
		is_paused = false

## Completely resets the timer for a new playthrough
func reset() -> void:
	elapsed_seconds = 0.0
	_warned_yellow = false
	_warned_red = false
	_deadline_reached = false
	is_paused = false

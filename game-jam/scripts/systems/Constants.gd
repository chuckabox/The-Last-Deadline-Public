extends Node

# =============================================================================
# Constants.gd — Game-Wide Constants for "The Last Deadline"
# =============================================================================
# This autoload singleton holds every tunable constant used across the project.
# Reference values via:  Constants.ALCOHOL_INCREMENT_PER_DRINK, etc.
# =============================================================================


# ===== ALCOHOL SYSTEM =====

## Stage thresholds (inclusive lower bound)
const ALCOHOL_STAGE_NORMAL := 0.0     # 0.00 – 0.24
const ALCOHOL_STAGE_BUZZ := 0.25      # 0.25 – 0.49
const ALCOHOL_STAGE_TUNNEL := 0.50    # 0.50 – 0.74
const ALCOHOL_STAGE_SPIN := 0.75      # 0.75 – 0.99
const ALCOHOL_STAGE_BLACKOUT := 1.0   # 1.00 (instant game-over / ending)

## Per-action deltas
const ALCOHOL_INCREMENT_PER_DRINK := 0.25

## Hard cap
const ALCOHOL_MAXIMUM := 1.0
const ALCOHOL_MINIMUM := 0.0


# ===== TIME SYSTEM =====

## In-game clock values (represented as minutes elapsed since 11:50 PM)
## Real-time: 1 real second = 1 game second (no scaling)
const TIME_START_MINUTES := 0         # 11:50 PM
const TIME_DEADLINE_MINUTES := 10     # 12:00 AM (midnight)
const TIME_TOTAL_SECONDS := 600       # 10 real minutes = 600 seconds

## Warning thresholds (minutes elapsed since 11:50 PM)
const TIME_WARNING_YELLOW := 8        # 11:58 PM — clock turns yellow
const TIME_WARNING_RED := 9           # 11:59 PM — clock turns red


# ===== UI CONSTANTS =====

## Viewport / resolution
const SCREEN_WIDTH := 1980
const SCREEN_HEIGHT := 1080

## HUD layout
const HUD_MARGIN := 16               # pixels from screen edge
const DIALOGUE_BOX_HEIGHT := 120      # pixels


# ===== COLOR PALETTE =====

## Environment
const COLOR_BACKGROUND := Color("#0a0a1a")   # Dark blue club ambience
const COLOR_ACCENT := Color("#00ff88")        # Neon green accent
const COLOR_TEXT := Color("#ffffff")           # Default text

## Alcohol meter stage colors
const COLOR_STAGE_NORMAL := Color("#ffffff")   # White  — sober
const COLOR_STAGE_BUZZ := Color("#00ff88")     # Green  — feeling good
const COLOR_STAGE_TUNNEL := Color("#ff8800")   # Orange — tunnel vision
const COLOR_STAGE_SPIN := Color("#ff0033")     # Red    — room is spinning
const COLOR_STAGE_BLACKOUT := Color("#000000") # Black  — lights out

## Clock warning colors
const COLOR_CLOCK_DEFAULT := Color("#ffffff")
const COLOR_CLOCK_YELLOW := Color("#ffdd00")
const COLOR_CLOCK_RED := Color("#ff0033")


# ===== AUDIO CONSTANTS =====

## Volume levels (decibels)
const AUDIO_VOLUME_MASTER := -10.0
const AUDIO_VOLUME_MUSIC := -6.0      # Lower so dialogue stays audible
const AUDIO_VOLUME_SFX := -3.0


# ===== CAMERA SETTINGS =====

## Pixel-perfect zoom
const CAMERA_ZOOM := Vector2(2.0, 2.0)

## Screen-shake intensity (pixels, scaled per alcohol stage)
const CAMERA_SHAKE_INTENSITY := 5.0


# ===== HELPER FUNCTIONS =====

## Returns the alcohol stage name for a given alcohol value.
static func get_alcohol_stage(alcohol: float) -> String:
	if alcohol >= ALCOHOL_STAGE_BLACKOUT:
		return "blackout"
	elif alcohol >= ALCOHOL_STAGE_SPIN:
		return "spin"
	elif alcohol >= ALCOHOL_STAGE_TUNNEL:
		return "tunnel"
	elif alcohol >= ALCOHOL_STAGE_BUZZ:
		return "buzz"
	else:
		return "normal"


## Returns the matching meter color for a given alcohol value.
static func get_alcohol_color(alcohol: float) -> Color:
	if alcohol >= ALCOHOL_STAGE_BLACKOUT:
		return COLOR_STAGE_BLACKOUT
	elif alcohol >= ALCOHOL_STAGE_SPIN:
		return COLOR_STAGE_SPIN
	elif alcohol >= ALCOHOL_STAGE_TUNNEL:
		return COLOR_STAGE_TUNNEL
	elif alcohol >= ALCOHOL_STAGE_BUZZ:
		return COLOR_STAGE_BUZZ
	else:
		return COLOR_STAGE_NORMAL


## Returns the clock color based on minutes elapsed.
static func get_clock_color(minutes_elapsed: int) -> Color:
	if minutes_elapsed >= TIME_WARNING_RED:
		return COLOR_CLOCK_RED
	elif minutes_elapsed >= TIME_WARNING_YELLOW:
		return COLOR_CLOCK_YELLOW
	else:
		return COLOR_CLOCK_DEFAULT


## Converts elapsed minutes to a display string like "11:53 PM" or "12:00 AM".
@warning_ignore("integer_division")
static func format_game_time(minutes_elapsed: int) -> String:
	var total_minutes := 23 * 60 + 50 + minutes_elapsed  # 11:50 PM = 23:50 in 24h
	var hours_24 := (total_minutes / 60) % 24
	var mins := total_minutes % 60
	var period := "AM" if hours_24 < 12 or hours_24 == 24 else "PM"
	var hours_12 := hours_24 % 12
	if hours_12 == 0:
		hours_12 = 12
	return "%d:%02d %s" % [hours_12, mins, period]

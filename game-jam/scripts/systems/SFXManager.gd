extends Node


# Extensions Godot can natively import (in resolution order: smallest+streaming
# preferred, then PCM, then mp3). Drop any of these with a matching basename
# and the manager will find it regardless of the path configured below.
const SUPPORTED_AUDIO_EXTENSIONS := [".ogg", ".wav", ".mp3"]


# SFX library
@export var sfx_library: Dictionary = {
	# Player
	"footsteps_tile": "res://audio/sfx/footsteps_tile.ogg",
	"footsteps_club": "res://audio/sfx/footsteps_club.ogg",
	"phone_vibrate": "res://audio/sfx/phone_vibrate.ogg",
	
	# UI
	"menu_select": "res://audio/sfx/menu_select.ogg",
	"menu_scroll": "res://audio/sfx/menu_scroll.ogg",
	"notification_ping": "res://audio/sfx/notification_ping.ogg",
	"error": "res://audio/sfx/error.ogg",
	
	# Mini-games
	"sequence_correct": "res://audio/sfx/sequence_correct.ogg",
	"sequence_wrong": "res://audio/sfx/sequence_wrong.ogg",
	"cup_sink": "res://audio/sfx/cup_sink.ogg",
	"rim_bounce": "res://audio/sfx/rim_bounce.ogg",
	"liquid_pour": "res://audio/sfx/liquid_pour.ogg",
	"cork_pop": "res://audio/sfx/cork_pop.ogg",
	"pose_match": "res://audio/sfx/pose_match.ogg",
	
	# Alcohol
	"drink_gulp": "res://audio/sfx/drink_gulp.ogg",
	"water_refresh": "res://audio/sfx/water_refresh.ogg",
	"stage_transition": "res://audio/sfx/stage_transition.ogg",
	
	# Environment
	"door_unlock": "res://audio/sfx/door_unlock.ogg"
}

# Audio player pool
var audio_players: Array[AudioStreamPlayer] = []

@export var max_simultaneous_sfx: int = 12 # Increased for complex mini-game moments

func _ready():
	add_to_group("managers")
	
	# Create audio player pool for simultaneous playback
	for i in range(max_simultaneous_sfx):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX" # Ensure "SFX" bus exists in Audio settings
		add_child(player)
		audio_players.append(player)
	
	print("SFXManager initialized with %d audio players" % max_simultaneous_sfx)

func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0):
	# Find available player in the pool
	var player = get_available_player()
	
	# Verify sound exists in library
	if not sfx_library.has(sfx_name):
		print("WARNING: SFX '%s' not found in library" % sfx_name)
		return
	
	var track_path := _resolve_audio_path(sfx_library[sfx_name])
	if track_path == "":
		# No supported audio file found at this basename — silent no-op.
		return

	var audio_file = load(track_path)
	if not audio_file:
		print("ERROR: Could not load SFX: %s" % sfx_name)
		return
	
	# Assign and play
	player.stream = audio_file
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()

## Resolves a configured audio path to the first existing sibling whose
## extension is supported by Godot. Drop .ogg / .wav / .mp3 with the same
## basename and it will be picked up regardless of what's configured above.
func _resolve_audio_path(base_path: String) -> String:
	if FileAccess.file_exists(base_path):
		return base_path
	var stem := base_path.get_basename()
	for ext: String in SUPPORTED_AUDIO_EXTENSIONS:
		var candidate := stem + ext
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


func get_available_player() -> AudioStreamPlayer:
	# Find a player that isn't currently busy
	for player in audio_players:
		if not player.playing:
			return player
	
	# If the entire pool is busy, recycle the oldest one (first in array)
	return audio_players[0]

func stop_all_sfx():
	for player in audio_players:
		player.stop()

func set_sfx_volume(db: float):
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if sfx_bus_idx != -1:
		AudioServer.set_bus_mute(sfx_bus_idx, false)
		AudioServer.set_bus_volume_db(sfx_bus_idx, db)
	else:
		print("WARNING: SFX Audio Bus not found!")

extends AudioStreamPlayer


# Extensions Godot can natively import. Drop any of these with a matching
# basename and the manager will find it regardless of the configured path.
const SUPPORTED_AUDIO_EXTENSIONS := [".ogg", ".wav", ".mp3"]


# Music tracks by stage
@export var music_by_stage: Dictionary = {
	0: "res://audio/music/stage_0_chill.ogg",
	1: "res://audio/music/stage_1_buzz.ogg",
	2: "res://audio/music/stage_2_hype.ogg",
	3: "res://audio/music/stage_3_chaos.ogg",
	4: "res://audio/music/stage_4_distorted.ogg"
}

# References
var alcohol_system: Node
var current_stage = -1
var is_crossfading = false

# Crossfade settings
@export var crossfade_duration: float = 1.5

func _ready():
	add_to_group("managers")
	
	# Get reference to the alcohol system to listen for state changes
	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	if alcohol_system and alcohol_system.has_signal("stage_changed"):
		alcohol_system.stage_changed.connect(_on_stage_changed)
	
	# Set audio bus to "Music" (ensure this exists in your Audio bus layout)
	bus = "Music"
	
	# Start with stage 0 music
	play_music_for_stage(0)
	
	print("MusicManager initialized")

func _on_stage_changed(new_stage: int):
	if new_stage != current_stage:
		# Trigger the transition to the new stage's theme
		crossfade_to_stage(new_stage)

func crossfade_to_stage(stage: int):
	if is_crossfading:
		return
	
	is_crossfading = true
	
	# Fade out current track
	var tween_out = create_tween()
	tween_out.set_trans(Tween.TRANS_SINE)
	tween_out.tween_property(self, "volume_db", -80.0, crossfade_duration / 2.0)
	await tween_out.finished
	
	# Switch the track stream
	play_music_for_stage(stage)
	
	# Fade in the new track
	volume_db = -80.0
	var tween_in = create_tween()
	tween_in.set_trans(Tween.TRANS_SINE)
	tween_in.tween_property(self, "volume_db", -10.0, crossfade_duration / 2.0)
	await tween_in.finished
	
	is_crossfading = false

func play_music_for_stage(stage: int):
	if not music_by_stage.has(stage):
		print("ERROR: No music track defined for stage %d" % stage)
		return
	
	var track_path := _resolve_audio_path(music_by_stage[stage])
	if track_path == "":
		print("WARNING: Music file missing for stage %d (configured: %s). System waiting for assets..." % [stage, music_by_stage[stage]])
		current_stage = stage
		return

	var audio_file = load(track_path)
	if audio_file:
		stream = audio_file
		play()
		current_stage = stage
		print("Now playing: Stage %d music (%s)" % [stage, track_path])
	else:
		print("ERROR: Could not load music file: %s" % track_path)


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

func set_music_volume(db: float):
	volume_db = db

func stop_music():
	stop()

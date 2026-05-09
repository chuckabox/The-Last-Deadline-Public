extends Node

# AudioManager.gd
# Facade for playing sounds and music, delegating to SFXManager and MusicManager.

func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0):
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play_sfx"):
		sfx.play_sfx(sfx_name, volume_db, pitch_scale)
	else:
		push_warning("AudioManager: SFXManager not found or play_sfx method missing")

func stop_all_sfx():
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("stop_all_sfx"):
		sfx.stop_all_sfx()

func play_music(music_name: String):
	var music = get_node_or_null("/root/MusicManager")
	if music and music.has_method("play_track"):
		music.play_track(music_name)
	else:
		push_warning("AudioManager: MusicManager not found or play_track method missing")

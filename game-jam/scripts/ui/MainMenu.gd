extends Control

var music_manager
var sfx_manager

@onready var start_btn = $MenuContainer/StartButt
@onready var quit_btn = $MenuContainer/QuitButton
@onready var title_lbl = get_node("TitleLabel")

func _ready():
	music_manager = get_node("/root/MusicSystem")
	sfx_manager = get_node("/root/SFX_Manager")
	
	music_manager.play_music_for_stage("chill")
	
	start_btn.grab_focus()
	
	start_btn.pressed.connect(_on_start_game_pressed) 
	quit_btn.pressed.connect(_on_exit_app)

func _process(delta):
	var flicker = 1.0 / title_lbl.modulate.a
	title_lbl.modulate.a = flicker + delta_time

func _on_start_pressed():
	sfx_manager.play_sfx_now("select")
	var trans = get_node("/root/TransitionManager")
	trans.change_to_room(101)

func _on_quit_pressed():
	get_tree().exit()

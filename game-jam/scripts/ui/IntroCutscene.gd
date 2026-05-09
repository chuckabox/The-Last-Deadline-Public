extends Node

## Intro Cutscene
## Pauses the clock, fades in over a dim ambient bar backdrop, runs the friend
## dialogue chain (talk -> phoneTrigger -> panic), fades out, and hands control
## to gameplay via GameManager.start_game().
##
## Expects to be added as a child of /root/Main/CurrentScene with the HUD
## (and DialogueUI) already present at /root/Main/HUD/DialogueUI.

var dialogue_ui: Control
var time_manager: Node
var game_manager: Node

# Visuals (built in code so the .tscn stays minimal)
var visuals: CanvasLayer
var ambient_label: Label
var fade_overlay: ColorRect

func _ready() -> void:
	dialogue_ui = get_tree().root.get_node_or_null("Main/HUD/DialogueUI")
	time_manager = get_node_or_null("/root/TimeManager")
	game_manager = get_node_or_null("/root/GameManager")

	if time_manager:
		time_manager.pause_time()

	_build_visuals()
	_run()

func _build_visuals() -> void:
	visuals = CanvasLayer.new()
	# Layer 0 = world canvas, sits above bar.tscn but below the HUD (layer 1)
	# so the DialogueUI renders on top of our backdrop.
	visuals.layer = 0
	add_child(visuals)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.02, 0.08, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	visuals.add_child(bg)

	ambient_label = Label.new()
	ambient_label.text = "the music is loud.\nthe bass is thumping.\nyou take another sip..."
	ambient_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	ambient_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ambient_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ambient_label.add_theme_font_size_override("font_size", 48)
	var font = load("res://assets/fonts/monogram.ttf")
	if font:
		ambient_label.add_theme_font_override("font", font)
	ambient_label.modulate.a = 0.0
	visuals.add_child(ambient_label)

	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	visuals.add_child(fade_overlay)

func _run() -> void:
	# Fade in from black; ambient flavor text appears.
	var t := create_tween().set_parallel(true)
	t.tween_property(fade_overlay, "modulate:a", 0.0, 1.2)
	t.tween_property(ambient_label, "modulate:a", 1.0, 1.4).set_delay(0.4)
	await t.finished

	await get_tree().create_timer(1.6).timeout

	# Fade out the ambient text so it doesn't overlap with the dialogue.
	create_tween().tween_property(ambient_label, "modulate:a", 0.0, 0.4)

	if dialogue_ui and dialogue_ui.has_method("show_dialogue"):
		dialogue_ui.dialogue_closed.connect(_on_dialogue_closed, CONNECT_ONE_SHOT)
		dialogue_ui.show_dialogue("friend", "talk")
	else:
		push_error("IntroCutscene: DialogueUI not found at /root/Main/HUD/DialogueUI")
		_finish()

func _on_dialogue_closed() -> void:
	_finish()

func _finish() -> void:
	# Transition instantly to gameplay without fading back to black
	if time_manager:
		time_manager.resume_time()
	if game_manager and game_manager.has_method("start_game"):
		game_manager.start_game()

	queue_free()

extends Node

## MinigameManager
## Autoload that launches minigame scenes on demand and reports results.
## Dialogue/NPC code calls launch(id) and listens for `minigame_finished`.

signal minigame_started(minigame_id: String)
signal minigame_finished(minigame_id: String, won: bool, cash: int)

const MINIGAME_SCENES := {
	"beer_pong":        "res://scenes/minigames/BeerPong.tscn",
	"drink_pour":       "res://scenes/minigames/DrinkPour.tscn",
	"dance_rhythm":     "res://scenes/minigames/DanceRhythm.tscn",
	"champaigne_pop":   "res://scenes/minigames/ChampaignePop.tscn",
	"bartender_memory": "res://scenes/minigames/BartenderMemory.tscn",
}

var current_id: String = ""
var current_instance: Node = null

func is_running() -> bool:
	return current_instance != null and is_instance_valid(current_instance)

## Launches a minigame by id. `parent` is where the scene is added; defaults to
## the HUD CanvasLayer if available, otherwise the current scene root.
func launch(minigame_id: String, parent: Node = null) -> bool:
	if is_running():
		push_warning("MinigameManager: already running '%s'" % current_id)
		return false

	if not MINIGAME_SCENES.has(minigame_id):
		push_error("MinigameManager: unknown minigame id '%s'" % minigame_id)
		return false

	var scene: PackedScene = load(MINIGAME_SCENES[minigame_id])
	if scene == null:
		push_error("MinigameManager: failed to load scene for '%s'" % minigame_id)
		return false

	var host: Node = parent
	if host == null:
		host = get_tree().get_root().get_node_or_null("Main/HUD")
	if host == null:
		host = get_tree().current_scene

	current_id = minigame_id
	current_instance = scene.instantiate()
	host.add_child(current_instance)

	if current_instance.has_signal("minigame_won"):
		current_instance.minigame_won.connect(_on_won)
	if current_instance.has_signal("minigame_lost"):
		current_instance.minigame_lost.connect(_on_lost)

	minigame_started.emit(minigame_id)
	return true

func _on_won(cash_reward: int = 0) -> void:
	_finish(true, cash_reward)

func _on_lost() -> void:
	_finish(false, 0)

func _finish(won: bool, cash: int) -> void:
	var finished_id := current_id
	if is_instance_valid(current_instance):
		current_instance.queue_free()
	current_instance = null
	current_id = ""

	if won and cash > 0:
		var gm := get_node_or_null("/root/GameManager")
		if gm and gm.has_method("add_cash"):
			gm.add_cash(cash)

	minigame_finished.emit(finished_id, won, cash)

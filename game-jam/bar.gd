extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("The game has started!")
	print("The current BAC is: ", Global.bac)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

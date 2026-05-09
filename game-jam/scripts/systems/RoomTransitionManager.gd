extends Node


# Room Management
var current_room = "bar"
var current_room_scene: Node = null

var room_paths = {
	"main_menu": "res://scenes/ui/MainMenu.tscn",
	"bar": "res://scenes/rooms/room_1_bar.tscn",
	"disco": "res://scenes/rooms/room_2_disco.tscn",
	"vip": "res://scenes/rooms/room_3_vip.tscn",
	"office": "res://scenes/rooms/room_4_office.tscn"
}

# Transition state
var is_transitioning = false

# References
var game_manager: Node
var audio_manager: Node

# Signals
signal room_changed(room_name)
signal transition_started()
signal transition_ended()

func _ready():
	add_to_group("managers")
	game_manager = get_node_or_null("/root/GameManager")
	audio_manager = get_node_or_null("/root/AudioManager")
	
	# Try to find existing room if already loaded in Main
	var current_scene_node = get_node_or_null("/root/Main/CurrentScene")
	if current_scene_node and current_scene_node.get_child_count() > 0:
		current_room_scene = current_scene_node.get_child(0)
	
	print("RoomTransitionManager initialized")

func change_room(room_name: String) -> bool:
	# Prevent concurrent transitions
	if is_transitioning:
		print("Already transitioning, cannot change rooms")
		return false
	
	# Verify room exists
	if not room_paths.has(room_name):
		print("ERROR: Room '%s' does not exist" % room_name)
		return false
	
	is_transitioning = true
	emit_signal("transition_started")
	
	# Fade to black
	await fade_to_black(0.5)
	
	# Unload current room
	if current_room_scene:
		current_room_scene.queue_free()
		# Wait a frame for cleanup
		await get_tree().process_frame
	
	# Load new room
	var room_path = room_paths[room_name]
	var room_scene = load(room_path)
	
	if room_scene == null:
		print("ERROR: Could not load room '%s' from path '%s'" % [room_name, room_path])
		is_transitioning = false
		await fade_from_black(0.5)
		return false
	
	# Instantiate and add to scene tree
	current_room_scene = room_scene.instantiate()
	var current_scene_node = get_node_or_null("/root/Main/CurrentScene")
	if current_scene_node:
		current_scene_node.add_child(current_room_scene)
	else:
		# Fallback to Main root if CurrentScene placeholder is missing
		var main_node = get_node_or_null("/root/Main")
		if main_node:
			main_node.add_child(current_room_scene)
	
	# Update current room state
	current_room = room_name
	if game_manager and "current_room" in game_manager:
		game_manager.current_room = room_name
	
	print("Loaded room: %s" % room_name)
	
	# Fade from black
	await fade_from_black(0.5)
	
	emit_signal("room_changed", room_name)
	emit_signal("transition_ended")
	is_transitioning = false
	return true

func fade_to_black(duration: float) -> void:
	# Create fade overlay on a top-level CanvasLayer
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "FadeLayer"
	canvas_layer.layer = 100 # Topmost
	
	var fade = ColorRect.new()
	fade.name = "FadeOverlay"
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP # Block inputs during transition
	fade.modulate.a = 0.0
	
	canvas_layer.add_child(fade)
	get_tree().get_root().add_child(canvas_layer)
	
	# Fade in
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(fade, "modulate:a", 1.0, duration)
	await tween.finished

func fade_from_black(duration: float) -> void:
	# Find the fade overlay
	var fade_layer = get_tree().get_root().get_node_or_null("FadeLayer")
	if fade_layer:
		var fade = fade_layer.get_node_or_null("FadeOverlay")
		if fade:
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.tween_property(fade, "modulate:a", 0.0, duration)
			await tween.finished
		fade_layer.queue_free()

func iris_to_black(duration: float) -> void:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "FadeLayer"
	canvas_layer.layer = 100
	
	var fade = ColorRect.new()
	fade.name = "FadeOverlay"
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform float radius = 1.0;
	uniform float aspect = 1.0;
	void fragment() {
		vec2 center = vec2(0.5, 0.5);
		vec2 uv = UV - center;
		uv.x *= aspect;
		if (length(uv) > radius) {
			COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		} else {
			COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		}
	}
	"""
	mat.shader = shader
	var viewport_size = get_viewport().get_visible_rect().size
	mat.set_shader_parameter("aspect", viewport_size.x / viewport_size.y)
	mat.set_shader_parameter("radius", 1.0)
	fade.material = mat
	
	canvas_layer.add_child(fade)
	get_tree().get_root().add_child(canvas_layer)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_method(func(v): mat.set_shader_parameter("radius", v), 1.0, 0.0, duration)
	await tween.finished

func iris_from_black(duration: float) -> void:
	var fade_layer = get_tree().get_root().get_node_or_null("FadeLayer")
	if fade_layer:
		var fade = fade_layer.get_node_or_null("FadeOverlay")
		if fade and fade.material:
			var mat = fade.material
			var viewport_size = get_viewport().get_visible_rect().size
			mat.set_shader_parameter("aspect", viewport_size.x / viewport_size.y)
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.tween_method(func(v): mat.set_shader_parameter("radius", v), 0.0, 1.0, duration)
			await tween.finished
		fade_layer.queue_free()

func change_room_iris(room_name: String) -> bool:
	if is_transitioning: return false
	if not room_paths.has(room_name): return false
	
	is_transitioning = true
	emit_signal("transition_started")
	
	await iris_to_black(0.8)
	
	if current_room_scene:
		current_room_scene.queue_free()
		await get_tree().process_frame
	
	var room_scene = load(room_paths[room_name])
	current_room_scene = room_scene.instantiate()
	var current_scene_node = get_node_or_null("/root/Main/CurrentScene")
	if current_scene_node:
		current_scene_node.add_child(current_room_scene)
	else:
		var main_node = get_node_or_null("/root/Main")
		if main_node: main_node.add_child(current_room_scene)
	
	current_room = room_name
	if game_manager and "current_room" in game_manager:
		game_manager.current_room = room_name
	
	await iris_from_black(0.8)
	
	emit_signal("room_changed", room_name)
	emit_signal("transition_ended")
	is_transitioning = false
	return true

func get_current_room() -> String:
	return current_room

func get_current_room_scene() -> Node:
	return current_room_scene

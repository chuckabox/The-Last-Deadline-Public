extends NPCInteraction

var has_moved = false

func _ready():
	npc_name = "Bouncer"
	npc_id = "bouncer"
	super._ready()

func _on_area_entered(area):
	if area.name.to_lower().contains("playercollision"):
		var global_state = get_node_or_null("/root/GlobalStateManager")
		if global_state and not has_moved:
			# DEBUG: always step aside
			_step_aside()
			return
			
	super._on_area_entered(area)

func _step_aside():
	has_moved = true
	can_interact = false
	is_in_range = false # Force false to prevent prompt
	
	# Play side_step animation
	if animated_sprite:
		animated_sprite.play("side_step")
	
	# Hide prompt and exclamation
	if hud and hud.has_method("hide_interaction_prompt"):
		hud.hide_interaction_prompt()
	if speech_bubble:
		speech_bubble.hide()
		
	# Don't move position, just wait and play idle
	var tween = create_tween()
	tween.tween_interval(0.8)
	tween.tween_callback(func(): if animated_sprite: animated_sprite.play("idle"))

func interact():
	var global_state = get_node_or_null("/root/GlobalStateManager")
	if global_state and global_state.check_flag("djDefeated"):
		return # No dialogue if they have the pass
		
	super.interact()

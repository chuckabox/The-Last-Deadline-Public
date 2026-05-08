extends Node

## Audio Filter Manager
## Dynamically applies audio effects to the Master bus based on the player's alcohol stage.

# Effect Instances
var reverb = AudioEffectReverb.new()
var pitch_shift = AudioEffectPitchShift.new()
var low_pass = AudioEffectLowPassFilter.new()
var distortion = AudioEffectDistortion.new() # For Bitcrush mode

var master_bus_idx: int
var alcohol_system: Node

# Warble state
var time_passed: float = 0.0

func _ready():
	master_bus_idx = AudioServer.get_bus_index("Master")
	alcohol_system = get_node_or_null("/root/AlcoholSystem")
	
	# Setup Effects
	_setup_effects()
	
	if alcohol_system:
		alcohol_system.alcohol_changed.connect(_on_alcohol_changed)
	
	print("AudioFilterManager initialized")

func _setup_effects():
	# Add effects to the bus (initially disabled)
	AudioServer.add_bus_effect(master_bus_idx, reverb, 0)
	AudioServer.set_bus_effect_enabled(master_bus_idx, 0, false)
	
	pitch_shift.oversampling = 4
	AudioServer.add_bus_effect(master_bus_idx, pitch_shift, 1)
	AudioServer.set_bus_effect_enabled(master_bus_idx, 1, false)
	
	AudioServer.add_bus_effect(master_bus_idx, low_pass, 2)
	AudioServer.set_bus_effect_enabled(master_bus_idx, 2, false)
	
	distortion.mode = AudioEffectDistortion.MODE_BITCRUSH
	distortion.drive = 0.2
	AudioServer.add_bus_effect(master_bus_idx, distortion, 3)
	AudioServer.set_bus_effect_enabled(master_bus_idx, 3, false)

func _process(delta):
	# Oscillate pitch if in Stage 3 (Warble)
	if alcohol_system and alcohol_system.get("current_stage") == 3:
		time_passed += delta
		# Subtle pitch oscillation (0.95 to 1.05)
		pitch_shift.pitch_scale = 1.0 + (sin(time_passed * 2.0) * 0.05)

func _on_alcohol_changed(_amount: float, stage: int):
	# Reset all first
	for i in range(4):
		AudioServer.set_bus_effect_enabled(master_bus_idx, i, false)
	
	match stage:
		0:
			pass # Normal
		1, 2:
			# Stage 1-2: Reverb (Distant feel)
			reverb.room_size = 0.3 if stage == 1 else 0.6
			reverb.wet = 0.2 if stage == 1 else 0.4
			AudioServer.set_bus_effect_enabled(master_bus_idx, 0, true)
		3:
			# Stage 3: Warble (Nausea)
			AudioServer.set_bus_effect_enabled(master_bus_idx, 1, true)
			# Keep reverb on but lower
			reverb.room_size = 0.4
			AudioServer.set_bus_effect_enabled(master_bus_idx, 0, true)
		4:
			# Stage 4: Muffled/Glitchy (Blackout)
			low_pass.cutoff_hz = 800
			low_pass.resonance = 0.5
			AudioServer.set_bus_effect_enabled(master_bus_idx, 2, true)
			AudioServer.set_bus_effect_enabled(master_bus_idx, 3, true)

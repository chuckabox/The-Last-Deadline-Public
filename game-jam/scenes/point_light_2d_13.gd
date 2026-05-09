extends PointLight2D

@export_group("Pulse Settings")
@export var bpm: float = 80.0       # Beats Per Minute (Tempo)
@export var min_energy: float = 0.5  # Lowest brightness
@export var max_energy: float = 1.5  # Highest brightness
@export var sync_scale: bool = true  # Should the light also grow/shrink?

var time_passed: float = 0.0

func _process(delta):
	# 1. Calculate frequency based on BPM
	# Frequency (Hz) = BPM / 60
	var frequency = bpm / 60.0
	time_passed += delta
	
	# 2. Use a Sine wave to create a smooth 0 to 1 value
	# sin() goes from -1 to 1, so we map it to 0 to 1
	var raw_sine = sin(time_passed * frequency * TAU)
	var pulse_value = (raw_sine + 1.0) / 2.0
	
	# 3. Apply the pulse to the energy (brightness)
	energy = lerp(min_energy, max_energy, pulse_value)
	
	# 4. Optional: Pulse the size as well
	if sync_scale:
		var scale_factor = lerp(0.8, 1.2, pulse_value)
		texture_scale = scale_factor

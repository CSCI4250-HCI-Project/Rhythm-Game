extends Control

@onready var score_manager = $ScoreManager
@onready var conductor = $Conductor
@onready var webcam_input = $WebcamInput

var upcoming_beats: Array = []

func _ready():
	print("Integration test scene ready")

	# Connect Conductor and WebcamInput signals
	conductor.connect("beat", Callable(self, "_on_beat"))
	webcam_input.connect("hand_hit", Callable(self, "_on_hand_hit"))

	# Start the song if available
	if conductor.has_method("start_song"):
		conductor.start_song()
	else:
		print("⚠️ Conductor does not have start_song() method.")

func _on_beat(time: float):
	upcoming_beats.append(time)
	# Optional: print debug info
	print("Beat received at:", time)

func _on_hand_hit(hit_time: float):
	if upcoming_beats.is_empty():
		return
	
	# Find the closest beat to this hit
	var closest_beat_time = upcoming_beats[0]
	for beat_time in upcoming_beats:
		if abs(beat_time - hit_time) < abs(closest_beat_time - hit_time):
			closest_beat_time = beat_time
	
	# Register the hit with the score manager
	score_manager.register_hit(closest_beat_time, hit_time)

	# Remove that beat so it’s not reused
	upcoming_beats.erase(closest_beat_time)

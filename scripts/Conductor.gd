extends Node

signal beat(time: float)
signal song_started
signal song_ended

@export var bpm: float = 120.0
@export var song_length: float = 60.0 # seconds
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

var start_time: float
var beat_interval: float

func _ready():
	beat_interval = 60.0 / bpm
	print("Conductor ready — BPM:", bpm)

func start_song():
	if audio_player == null:
		push_warning("⚠️ AudioStreamPlayer not found — no audio will play.")
	else:
		audio_player.play()

	start_time = Time.get_ticks_msec() / 1000.0
	emit_signal("song_started")
	_start_beat_timer()

func _start_beat_timer():
	var beat_index = 0
	while beat_index * beat_interval < song_length:
		await get_tree().create_timer(beat_interval).timeout
		var beat_time = Time.get_ticks_msec() / 1000.0
		emit_signal("beat", beat_time)
		beat_index += 1
		print("Beat", beat_index, "at", beat_time)

func stop_song():
	if audio_player:
		audio_player.stop()
	emit_signal("song_ended")

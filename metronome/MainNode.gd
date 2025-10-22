extends Node2D

var group
var counter: float
var song_position: float = 0.0
var bpm

func _ready():
	group = ButtonGroup.new()
	
	$Button60BPM.set_button_group(group)	
	$Button120BPM.set_button_group(group)
	
	pass

func _physics_process(delta: float) -> void:
	#song_position = $AudioStreamPlayer2D.get_playback_position() + AudioServer.get_time_since_last_mix()
	song_position += delta
	#song_position -= AudioServer.get_output_latency()
	print(song_position)
	if $Button60BPM.button_pressed:
		bpm = 60
	elif $Button120BPM.button_pressed:
		bpm = 120.0
		print($Button120BPM.button_pressed)
	while song_position > 60.0/bpm:
		song_position = 0
		$AudioStreamPlayer2D.play()
	pass

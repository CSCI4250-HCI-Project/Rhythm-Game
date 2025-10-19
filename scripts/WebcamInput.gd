extends Node

signal hand_hit(hit_time: float)

func _ready():
	print("WebcamInput ready — press Space to simulate a hand hit")

func _unhandled_input(event):
	if event.is_action_pressed("ui_accept"):  # e.g., Spacebar
		var hit_time = Time.get_ticks_msec() / 1000.0
		emit_signal("hand_hit", hit_time)

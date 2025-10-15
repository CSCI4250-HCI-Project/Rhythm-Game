extends Control

@onready var score_manager = $ScoreManager
@onready var feedback_label = $FeedbackLabel
@onready var test_button = $TestButton

func _ready():
	print("TestScene ready — press the button to simulate hits!")

func _on_TestButton_pressed() -> void:
	var hit_time = Time.get_ticks_msec() / 1000.0
	var expected_time = hit_time  # simulate a perfect hit for now
	score_manager.register_hit(expected_time, hit_time)

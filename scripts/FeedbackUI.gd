extends Label

@onready var score_manager = get_node("../ScoreManager")

func _ready() -> void:
	# Connect to ScoreManager's hit_result signal
	if score_manager:
		score_manager.connect("hit_result", Callable(self, "_on_hit_result"))
		text = "Score: %d" % score_manager.score
	else:
		print("⚠️ ScoreManager not found!")

# Show hit/miss messages temporarily
func _on_hit_result(result: String, new_score: int, combo: int) -> void:
	var msg = "%s! Combo: %d" % [result, combo]
	text = msg

	# Timer to revert text after a short delay
	var t = Timer.new()
	t.wait_time = 0.8
	t.one_shot = true
	add_child(t)
	t.start()
	t.timeout.connect(_on_timer_timeout.bind(new_score, t))

# Called when the feedback timer finishes
func _on_timer_timeout(new_score: int, t: Timer) -> void:
	text = "Score: %d" % new_score
	remove_child(t)
	t.queue_free()

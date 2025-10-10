extends Label

func show_feedback(text_to_show: String) -> void:
	text = text_to_show

func _on_score_updated(new_score: int) -> void:
	text = "Score: %d" % new_score

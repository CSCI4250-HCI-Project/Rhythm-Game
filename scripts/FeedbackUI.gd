extends Label

@onready var score_manager = get_node("../ScoreManager")

func _ready() -> void:
	# Connect to ScoreManager's hit_result signal
	if score_manager:
		score_manager.connect("hit_result", Callable(self, "_on_hit_result"))
		text = "Score: %d" % score_manager.score
	else:
		push_warning("⚠️ ScoreManager not found!")

# Called when a hit result is emitted from ScoreManager
func _on_hit_result(result: String, new_score: int, combo: int) -> void:
	# Set color based on result
	match result:
		"Perfect":
			add_theme_color_override("font_color", Color(0, 1, 0))  # Green
		"Good":
			add_theme_color_override("font_color", Color(1, 1, 0))  # Yellow
		"Miss":
			add_theme_color_override("font_color", Color(1, 0, 0))  # Red
	
	# Update the text
	text = "%s! Combo: %d" % [result, combo]
	modulate.a = 1.0  # Reset transparency if it was fading out

	# Create a tween to fade out text, then restore score display
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.5)
	tween.tween_callback(Callable(self, "_restore_score_text").bind(new_score))

func _restore_score_text(new_score: int) -> void:
	# Restore normal text and color
	add_theme_color_override("font_color", Color(1, 1, 1))
	text = "Score: %d" % new_score
	modulate.a = 1.0

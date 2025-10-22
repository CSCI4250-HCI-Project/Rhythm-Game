extends Label

# This function displays a message for a short time
func show_feedback(message: String, duration: float = 0.5) -> void:
    text = message
    show()
    # Hide after `duration` seconds
    await get_tree().create_timer(duration).timeout
    hide()

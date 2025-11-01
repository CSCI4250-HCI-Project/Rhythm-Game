
extends Node

# Game settings that persist across scenes
var difficulty = "Normal"  # Default difficulty

# Song selection data
var selected_song: String = ""
var selected_chart: String = ""

# Difficulty settings - only affects arrow speed
func get_arrow_speed() -> float:
    match difficulty:
        "Easy":
            return 300.0
        "Normal":
            return 400.0
        "Hard":
            return 550.0
        _:
            return 400.0

# Timing windows stay the same for all difficulties
# (Will adjust later when webcam is implemented)
const PERFECT_WINDOW = 0.10
const GOOD_WINDOW = 0.25
const MISS_WINDOW = 0.40

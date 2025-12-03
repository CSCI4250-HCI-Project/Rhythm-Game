extends Node

# Game settings for Rhythm Game
var difficulty: String = "Normal"
var selected_song: String = ""
var selected_chart: String = ""

# NEW: Store chart paths for all difficulties
var song_charts: Dictionary = {}

# NEW: Store last game statistics for game over screen
var last_game_stats: Dictionary = {}

# NEW: Track which game mode we're playing
var current_game_mode: String = "Rhythm"  # Can be "Rhythm" or "Karate"

func reset():
	difficulty = "Normal"
	selected_song = ""
	selected_chart = ""
	song_charts = {}
	last_game_stats = {}
	current_game_mode = "Rhythm"

# NEW: Difficulty time limits for Karate Reflexes Game
func get_karate_time_limit() -> float:
	match difficulty:
		"Easy":
			return 1.0
		"Normal":
			return 0.7
		"Hard":
			return 0.5
		_:
			return 0.7  # Default to Normal

# NEW: Helper function to set game mode
func set_game_mode(mode: String):
	current_game_mode = mode
	print("Game mode set to: " + mode)

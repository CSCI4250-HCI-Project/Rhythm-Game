extends Node

# Game settings
var difficulty: String = "Normal"
var selected_song: String = ""
var selected_chart: String = ""

# NEW: Store chart paths for all difficulties
var song_charts: Dictionary = {}

# NEW: Store last game statistics for game over screen
var last_game_stats: Dictionary = {}

func reset():
	difficulty = "Normal"
	selected_song = ""
	selected_chart = ""
	song_charts = {}
	last_game_stats = {}

extends Control

# Reference to the song buttons
@onready var billie_jean_button = $"SongScrollContainer/SongList/Billie Jean by Michael Jackson"
@onready var seven_nation_button = $"SongScrollContainer/SongList/Seven Nation Army by The White Stripes"
@onready var rolling_deep_button = $"SongScrollContainer/SongList/Rolling In The Deep by Adele"
@onready var take_on_me_button = $"SongScrollContainer/SongList/Take on Me by A-Ha"
@onready var set_fire_button = $"SongScrollContainer/SongList/Set Fire To The Rain by Adele"
@onready var back_button = $BackButton

# NEW: Add this if you have a button for I'll Follow The Sun
var follow_sun_button = null

func _ready():
	# Connect button signals
	billie_jean_button.pressed.connect(_on_billie_jean_pressed)
	rolling_deep_button.pressed.connect(_on_rolling_deep_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# NEW: Try to find I'll Follow The Sun button if it exists
	if has_node("SongScrollContainer/SongList/I'll Follow The Sun by The Beatles"):
		follow_sun_button = $"SongScrollContainer/SongList/I'll Follow The Sun by The Beatles"
		follow_sun_button.pressed.connect(_on_follow_sun_pressed)
	
	# We'll add the other buttons later when we have charts for them
	# seven_nation_button.pressed.connect(_on_seven_nation_pressed)
	# take_on_me_button.pressed.connect(_on_take_on_me_pressed)
	# set_fire_button.pressed.connect(_on_set_fire_pressed)

func _on_billie_jean_pressed():
	# Store song audio path
	GameSettings.selected_song = "res://assets/audio/Billie Jean by Michael Jackson.mp3"
	
	# Pick the chart based on the difficulty that was already selected
	var difficulty = GameSettings.difficulty
	
	if difficulty == "Easy":
		GameSettings.selected_chart = "res://charts/billie_jean_easy.json"
	elif difficulty == "Normal":
		GameSettings.selected_chart = "res://charts/billie_jean_normal.json"
	elif difficulty == "Hard":
		GameSettings.selected_chart = "res://charts/billie_jean_hard.json"
	else:
		# Fallback to easy if something went wrong
		GameSettings.selected_chart = "res://charts/billie_jean_easy.json"
	
	print("Song selected: Billie Jean by Michael Jackson")
	print("Difficulty: ", difficulty)
	print("Chart: ", GameSettings.selected_chart)
	
	# Start the game!
	get_tree().change_scene_to_file("res://scenes/ArrowGame.tscn")

func _on_rolling_deep_pressed():
	# Store song audio path
	GameSettings.selected_song = "res://assets/audio/Rolling In The Deep by Adele.mp3"
	
	# Pick the chart based on the difficulty that was already selected
	var difficulty = GameSettings.difficulty
	
	if difficulty == "Easy":
		GameSettings.selected_chart = "res://charts/Rolling_In_The_Deep_Easy.json"
	elif difficulty == "Normal":
		GameSettings.selected_chart = "res://charts/Rolling_In_The_Deep_Normal.json"
	elif difficulty == "Hard":
		GameSettings.selected_chart = "res://charts/Rolling_In_The_Deep_Hard.json"
	else:
		# Fallback to easy if something went wrong
		GameSettings.selected_chart = "res://charts/Rolling_In_The_Deep_Easy.json"
	
	print("Song selected: Rolling in the Deep by Adele")
	print("Difficulty: ", difficulty)
	print("Chart: ", GameSettings.selected_chart)
	
	# Start the game!
	get_tree().change_scene_to_file("res://scenes/ArrowGame.tscn")

# NEW: I'll Follow The Sun by The Beatles
func _on_follow_sun_pressed():
	# Store song audio path
	GameSettings.selected_song = "res://assets/audio/I'll Follow The Sun by The Beatles.mp3"
	
	# Pick the chart based on the difficulty that was already selected
	var difficulty = GameSettings.difficulty
	
	if difficulty == "Easy":
		GameSettings.selected_chart = "res://charts/I'll_Follow_The_Sun_Easy.json"
	elif difficulty == "Normal":
		GameSettings.selected_chart = "res://charts/I'll_Follow_The_Sun_Normal.json"
	elif difficulty == "Hard":
		GameSettings.selected_chart = "res://charts/I'll_Follow_The_Sun_Hard.json"
	else:
		# Fallback to easy if something went wrong
		GameSettings.selected_chart = "res://charts/I'll_Follow_The_Sun_Easy.json"
	
	print("Song selected: I'll Follow The Sun by The Beatles")
	print("Difficulty: ", difficulty)
	print("Chart: ", GameSettings.selected_chart)
	
	# Start the game!
	get_tree().change_scene_to_file("res://scenes/ArrowGame.tscn")

# Back button function
func _on_back_pressed():
	# Go back to difficulty selection
	get_tree().change_scene_to_file("res://scenes/DifficultySelection.tscn")

# Future song buttons ready for when you create charts
#func _on_seven_nation_pressed():
#	GameSettings.selected_song = "res://assets/audio/Seven Nation Army by The White Stripes.mp3"
#	var difficulty = GameSettings.difficulty
#	# ... set chart based on difficulty
#	get_tree().change_scene_to_file("res://scenes/ArrowGame.tscn")

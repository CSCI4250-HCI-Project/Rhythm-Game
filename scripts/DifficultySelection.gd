extends Control

@onready var easy_button = $ButtonContainer/EasyButton
@onready var normal_button = $ButtonContainer/NormalButton
@onready var hard_button = $ButtonContainer/HardButton

var back_button = null

func _ready():
	# Connect button signals
	easy_button.pressed.connect(_on_easy_pressed)
	normal_button.pressed.connect(_on_normal_pressed)
	hard_button.pressed.connect(_on_hard_pressed)
	
	# BackButton is at root level (not in ButtonContainer)
	if has_node("BackButton"):
		back_button = $BackButton
		back_button.pressed.connect(_on_back_pressed)
		print("BackButton connected successfully")
	else:
		print("WARNING: BackButton not found!")

func _on_easy_pressed():
	GameSettings.difficulty = "Easy"
	print("Difficulty selected: Easy")
	_go_to_next_scene()

func _on_normal_pressed():
	GameSettings.difficulty = "Normal"
	print("Difficulty selected: Normal")
	_go_to_next_scene()

func _on_hard_pressed():
	GameSettings.difficulty = "Hard"
	print("Difficulty selected: Hard")
	_go_to_next_scene()

func _go_to_next_scene():
	# Route to the correct game based on current_game_mode
	if GameSettings.current_game_mode == "Rhythm":
		get_tree().change_scene_to_file("res://scenes/SongSelection.tscn")
	elif GameSettings.current_game_mode == "Karate":
		get_tree().change_scene_to_file("res://scenes/KarateReflexesGame.tscn")
	else:
		print("ERROR: Unknown game mode: " + GameSettings.current_game_mode)
		# Default to Rhythm game
		get_tree().change_scene_to_file("res://scenes/SongSelection.tscn")

func _on_back_pressed():
	print("Back button pressed - returning to TitleScreen")
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

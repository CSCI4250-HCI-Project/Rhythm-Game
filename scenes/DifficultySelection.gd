extends Control

@onready var easy_button = $ButtonContainer/EasyButton
@onready var normal_button = $ButtonContainer/NormalButton
@onready var hard_button = $ButtonContainer/HardButton

# BackButton might not exist, so we'll check
var back_button = null

func _ready():
	# Connect button signals
	easy_button.pressed.connect(_on_easy_pressed)
	normal_button.pressed.connect(_on_normal_pressed)
	hard_button.pressed.connect(_on_hard_pressed)
	
	# Try to find BackButton (it might not exist in your scene)
	if has_node("ButtonContainer/BackButton"):
		back_button = $ButtonContainer/BackButton
		back_button.pressed.connect(_on_back_pressed)
	else:
		print("Note: BackButton not found in DifficultySelection scene")

func _on_easy_pressed():
	GameSettings.difficulty = "Easy"
	
	print("Difficulty selected: Easy")
	
	# Go to SONG selection
	get_tree().change_scene_to_file("res://scenes/SongSelection.tscn")

func _on_normal_pressed():
	GameSettings.difficulty = "Normal"
	
	print("Difficulty selected: Normal")
	
	# Go to SONG selection
	get_tree().change_scene_to_file("res://scenes/SongSelection.tscn")

func _on_hard_pressed():
	GameSettings.difficulty = "Hard"
	
	print("Difficulty selected: Hard")
	
	# Go to SONG selection
	get_tree().change_scene_to_file("res://scenes/SongSelection.tscn")

func _on_back_pressed():
	# Go back to title screen
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

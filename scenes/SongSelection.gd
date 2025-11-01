extends Control

# Reference to the song buttons - using exact names from scene tree
@onready var billie_jean_button = $"SongScrollContainer/SongList/Billie Jean by Michael Jackson"
@onready var seven_nation_button = $"SongScrollContainer/SongList/Seven Nation Army by The White Stripes"
@onready var rolling_deep_button = $"SongScrollContainer/SongList/Rolling In The Deep by Adele"
@onready var take_on_me_button = $"SongScrollContainer/SongList/Take on Me by A-Ha"
@onready var set_fire_button = $"SongScrollContainer/SongList/Set Fire To The Rain by Adele"

func _ready():
    # Connect button signals
    billie_jean_button.pressed.connect(_on_billie_jean_pressed)
    # We'll add the other buttons later when we have charts for them
    # seven_nation_button.pressed.connect(_on_seven_nation_pressed)
    # rolling_deep_button.pressed.connect(_on_rolling_deep_pressed)
    # take_on_me_button.pressed.connect(_on_take_on_me_pressed)
    # set_fire_button.pressed.connect(_on_set_fire_pressed)

func _on_billie_jean_pressed():
    # Set up the song data for ArrowGame to use
    GameSettings.selected_song = "Billie Jean by Michael Jackson.mp3"
    GameSettings.selected_chart = "res://charts/billie_jean_easy.json"  # CHANGED THIS LINE
    
    # Debug: Print to confirm values are set
    print("Song selected: ", GameSettings.selected_song)
    print("Chart selected: ", GameSettings.selected_chart)
    
    # Load the ArrowGame scene
    get_tree().change_scene_to_file("res://scenes/ArrowGame.tscn")

# These functions are ready for when you create charts for the other songs
#func _on_seven_nation_pressed():
#	GameSettings.selected_song = "Seven Nation Army by The White Stripes.mp3"
#	GameSettings.selected_chart = "res://charts/seven_nation_army_chart.json"
#	get_tree().change_scene_to_file("res://scenes/ArrowGame.tscn")

#func _on_rolling_deep_pressed():
#	GameSettings.selected_song = "Rolling In The Deep by Adele.mp3"
#	GameSettings.selected_chart = "res://charts/rolling_deep_chart.json"
#	get_tree().change_scene_to_file("res://scenes/ArrowGame.tscn")

#func _on_take_on_me_pressed():
#	GameSettings.selected_song = "Take On Me by A-Ha.mp3"
#	GameSettings.selected_chart = "res://charts/take_on_me_chart.json"
#	get_tree().change_scene_to_file("res://scenes/ArrowGame.tscn")

#func _on_set_fire_pressed():
#	GameSettings.selected_song = "Set Fire To The Rain by Adele.mp3"
#	GameSettings.selected_chart = "res://charts/set_fire_chart.json"
#	get_tree().change_scene_to_file("res://scenes/ArrowGame.tscn")

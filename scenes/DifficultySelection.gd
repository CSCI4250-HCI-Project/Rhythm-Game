extends Control

@onready var easy_button = $ButtonContainer/EasyButton
@onready var normal_button = $ButtonContainer/NormalButton
@onready var hard_button = $ButtonContainer/HardButton
@onready var back_button = $BackButton

func _ready():
    # Connect button signals
    easy_button.pressed.connect(_on_easy_pressed)
    normal_button.pressed.connect(_on_normal_pressed)
    hard_button.pressed.connect(_on_hard_pressed)
    back_button.pressed.connect(_on_back_pressed)
    
    # Highlight the current difficulty
    _highlight_current_difficulty()

func _highlight_current_difficulty():
    # Reset all buttons to normal
    easy_button.modulate = Color.WHITE
    normal_button.modulate = Color.WHITE
    hard_button.modulate = Color.WHITE
    
    # Highlight the currently selected difficulty
    match GameSettings.difficulty:
        "Easy":
            easy_button.modulate = Color.YELLOW
        "Normal":
            normal_button.modulate = Color.YELLOW
        "Hard":
            hard_button.modulate = Color.YELLOW

func _on_easy_pressed():
    GameSettings.difficulty = "Easy"
    _go_to_song_selection()

func _on_normal_pressed():
    GameSettings.difficulty = "Normal"
    _go_to_song_selection()

func _on_hard_pressed():
    GameSettings.difficulty = "Hard"
    _go_to_song_selection()

func _on_back_pressed():
    # Go back to the title screen
    get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

func _go_to_song_selection():
    # Go to song selection screen
    get_tree().change_scene_to_file("res://scenes/SongSelection.tscn")

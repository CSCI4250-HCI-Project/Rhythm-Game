# PauseMenu.gd
# Pause menu system for the rhythm game
# Attach this script to a CanvasLayer node in your ArrowGame scene

extends CanvasLayer

@onready var pause_panel = $PausePanel
@onready var resume_button = $PausePanel/VBoxContainer/ResumeButton
@onready var restart_button = $PausePanel/VBoxContainer/RestartButton
@onready var quit_button = $PausePanel/VBoxContainer/QuitButton

var is_paused = false

signal resume_game
signal restart_game
signal quit_to_menu

func _ready():
    # Hide pause menu at start
    hide_pause_menu()
    
    # Make buttons bigger
    if resume_button:
        resume_button.add_theme_font_size_override("font_size", 80)
        resume_button.pressed.connect(_on_resume_pressed)
    if restart_button:
        restart_button.add_theme_font_size_override("font_size", 80)
        restart_button.pressed.connect(_on_restart_pressed)
    if quit_button:
        quit_button.add_theme_font_size_override("font_size", 80)
        quit_button.pressed.connect(_on_quit_pressed)

func _input(event):
    # Toggle pause with SPACE key
    if event.is_action_pressed("ui_select"):  # SPACE bar
        if is_paused:
            resume_game_func()
        else:
            pause_game()

func pause_game():
    if is_paused:
        return
    
    is_paused = true
    show_pause_menu()
    get_tree().paused = true
    
    # Pause both audio players
    var conductor_audio = get_node_or_null("../Conductor/AudioStreamPlayer")
    if conductor_audio:
        conductor_audio.stream_paused = true
    
    var main_audio = get_node_or_null("../AudioStreamPlayer")
    if main_audio:
        main_audio.stream_paused = true

func resume_game_func():
    if not is_paused:
        return
    
    is_paused = false
    hide_pause_menu()
    get_tree().paused = false
    
    # Resume both audio players
    var conductor_audio = get_node_or_null("../Conductor/AudioStreamPlayer")
    if conductor_audio:
        conductor_audio.stream_paused = false
    
    var main_audio = get_node_or_null("../AudioStreamPlayer")
    if main_audio:
        main_audio.stream_paused = false
    
    emit_signal("resume_game")

func show_pause_menu():
    pause_panel.visible = true

func hide_pause_menu():
    pause_panel.visible = false

func _on_resume_pressed():
    resume_game_func()

func _on_restart_pressed():
    is_paused = false
    get_tree().paused = false
    
    # Reset score and combo in ScoreManager
    ScoreManager.score = 0
    ScoreManager.combo = 0
    
    emit_signal("restart_game")
    get_tree().reload_current_scene()

func _on_quit_pressed():
    is_paused = false
    get_tree().paused = false
    
    # Reset score and combo in ScoreManager
    ScoreManager.score = 0
    ScoreManager.combo = 0
    
    emit_signal("quit_to_menu")
    get_tree().change_scene_to_file("res://scenes/SongSelection.tscn")

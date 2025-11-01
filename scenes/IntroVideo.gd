extends Control

@onready var video_player = $VideoStreamPlayer

func _ready():
    # Connect the finished signal to go to the next scene
    video_player.finished.connect(_on_video_finished)
    
    # Make sure the video plays
    video_player.play()

func _input(event):
    # Allow skipping the video with various inputs
    if event.is_action_pressed("ui_accept") or \
       event.is_action_pressed("ui_cancel") or \
       (event is InputEventMouseButton and event.pressed):
        _skip_video()

func _skip_video():
    # Stop the video and go to next scene
    video_player.stop()
    _on_video_finished()

func _on_video_finished():
    # Go to the title screen
    get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

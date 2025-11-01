extends Control

# How long to display the developer screen (in seconds)
const DISPLAY_TIME = 3.0

func _ready():
    # Wait for DISPLAY_TIME seconds, then go to the intro video
    await get_tree().create_timer(DISPLAY_TIME).timeout
    get_tree().change_scene_to_file("res://scenes/IntroVideo.tscn")

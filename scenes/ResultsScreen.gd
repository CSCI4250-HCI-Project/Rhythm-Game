extends Control

@export var song_title_label: Label
@export var score_label: Label
@export var accuracy_label: Label
@export var max_combo_label: Label
@export var perfect_label: Label
@export var good_label: Label
@export var miss_label: Label
@export var high_score_label: Label
@export var new_high_score_label: Label
@export var retry_button: Button
@export var menu_button: Button

func _ready():
    retry_button.pressed.connect(_on_retry_pressed)
    menu_button.pressed.connect(_on_menu_pressed)
    new_high_score_label.hide()
    
    display_results()

func display_results():
    # Get song info from GameSettings
    var song_name = GameSettings.selected_song_title
    var difficulty = GameSettings.selected_difficulty
    
    # Display basic stats
    song_title_label.text = song_name
    score_label.text = "Score: " + str(ScoreManager.score)
    accuracy_label.text = "Accuracy: " + "%.1f" % ScoreManager.get_accuracy() + "%"
    max_combo_label.text = "Max Combo: " + str(ScoreManager.max_combo)
    perfect_label.text = "Perfect: " + str(ScoreManager.perfects)
    good_label.text = "Good: " + str(ScoreManager.goods)
    miss_label.text = "Miss: " + str(ScoreManager.misses)
    
    # Check if this is a new high score
    var previous_high = ScoreManager.get_high_score(song_name, difficulty)
    if previous_high.is_empty():
        high_score_label.text = "Previous High Score: None"
    else:
        high_score_label.text = "Previous High Score: " + str(previous_high["score"])
    
    # Save high score and check if it's new
    var is_new_high_score = ScoreManager.save_high_score(song_name, difficulty)
    if is_new_high_score:
        new_high_score_label.show()
        new_high_score_label.text = "🎉 NEW HIGH SCORE! 🎉"
        # Add a pulsing animation
        var tween = create_tween().set_loops()
        tween.tween_property(new_high_score_label, "scale", Vector2(1.2, 1.2), 0.5)
        tween.tween_property(new_high_score_label, "scale", Vector2(1.0, 1.0), 0.5)

func _on_retry_pressed():
    # Reset score and reload the game scene
    ScoreManager.reset_score()
    get_tree().change_scene_to_file("res://scenes/ArrowGame.tscn")

func _on_menu_pressed():
    # Reset score and return to song selection
    ScoreManager.reset_score()
    get_tree().change_scene_to_file("res://scenes/SongSelection.tscn")

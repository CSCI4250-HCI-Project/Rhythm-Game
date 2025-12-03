extends Control

# References to UI elements
@onready var song_title = $CenterContainer/VBoxContainer/SongTitle
@onready var score = $CenterContainer/VBoxContainer/Score
@onready var accuracy = $CenterContainer/VBoxContainer/Accuracy
@onready var max_combo = $CenterContainer/VBoxContainer/MaxCombo
@onready var perfect = $CenterContainer/VBoxContainer/Perfect
@onready var good = $CenterContainer/VBoxContainer/Good
@onready var miss = $CenterContainer/VBoxContainer/Miss
@onready var high_score = $CenterContainer/VBoxContainer/HighScore
@onready var new_high_score = $CenterContainer/VBoxContainer/NewHighScore
@onready var retry_button = $CenterContainer/VBoxContainer/Retry
@onready var menu_button = $CenterContainer/VBoxContainer/ReturnToMenu

func _ready():
	# Connect buttons
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	
	# Hide new high score label initially
	new_high_score.hide()
	
	# Display the results
	display_results()

func display_results():
	# Get stats from the last game
	var stats = GameSettings.last_game_stats
	
	if stats.is_empty():
		print("ERROR: No game stats found!")
		song_title.text = "No Data Available"
		return
	
	# Display all the stats
	song_title.text = stats.song + " - " + stats.difficulty
	score.text = "Score: " + str(stats.score)
	accuracy.text = "Accuracy: %.1f%%" % stats.accuracy
	max_combo.text = "Max Combo: " + str(stats.max_combo)
	perfect.text = "Perfect: " + str(stats.perfect)
	good.text = "Good: " + str(stats.good)
	miss.text = "Miss: " + str(stats.miss)
	
	# Load and display high score
	var key = "%s_%s" % [stats.song_id, stats.difficulty]
	var high_scores = load_high_scores()
	
	if high_scores.has(key) and high_scores[key].size() > 0:
		var top_score = high_scores[key][0].score
		high_score.text = "High Score: " + str(top_score)
		
		# Check if this is a new high score
		if stats.score == top_score:
			new_high_score.show()
			
			# Create pulsing animation
			var tween = create_tween().set_loops()
			tween.tween_property(new_high_score, "scale", Vector2(1.2, 1.2), 0.5)
			tween.tween_property(new_high_score, "scale", Vector2(1.0, 1.0), 0.5)
	else:
		high_score.text = "High Score: " + str(stats.score)
		new_high_score.show()
		
		# First time playing - it's automatically a high score!
		var tween = create_tween().set_loops()
		tween.tween_property(new_high_score, "scale", Vector2(1.2, 1.2), 0.5)
		tween.tween_property(new_high_score, "scale", Vector2(1.0, 1.0), 0.5)

func load_high_scores():
	"""Load high scores from save file"""
	var save_file = FileAccess.open("user://highscores.save", FileAccess.READ)
	
	if save_file:
		var json_string = save_file.get_as_text()
		save_file.close()
		
		if json_string != "":
			var json = JSON.new()
			if json.parse(json_string) == OK:
				return json.data
	
	return {}

func _on_retry_pressed():
	# Reset score manager
	ScoreManager.score = 0
	ScoreManager.combo = 0
	
	# Reload the game
	get_tree().change_scene_to_file("res://scenes/ArrowGame.tscn")

func _on_menu_pressed():
	# Reset score manager
	ScoreManager.score = 0
	ScoreManager.combo = 0
	
	# Go back to title screen
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

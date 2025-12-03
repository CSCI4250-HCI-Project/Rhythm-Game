extends Control

@onready var scores_container = $VBoxContainer/ScrollContainer/ScoresVBoxContainer
@onready var back_button = $BackButton  # Changed from $VBoxContainer/BackButton

var high_scores = []

func _ready():
	# Load high scores
	load_high_scores()
	
	# Connect signals
	back_button.pressed.connect(_on_back_pressed)
	
	# Display scores
	update_scores_display()


func load_high_scores():
	var save_file = FileAccess.open("user://karate_highscores.save", FileAccess.READ)
	
	if save_file:
		var json_string = save_file.get_as_text()
		save_file.close()
		
		if json_string != "":
			var json = JSON.new()
			if json.parse(json_string) == OK:
				high_scores = json.data
				if not high_scores is Array:
					high_scores = []


func update_scores_display():
	# Clear existing score entries
	for child in scores_container.get_children():
		child.queue_free()
	
	if high_scores.size() == 0:
		var no_scores_label = Label.new()
		no_scores_label.text = "No high scores yet! Play Karate Reflexes to set records!"
		no_scores_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_scores_label.add_theme_font_size_override("font_size", 75)
		scores_container.add_child(no_scores_label)
		return
	
	# Display scores (already sorted from game)
	for i in range(high_scores.size()):
		var score_entry = high_scores[i]
		var entry_panel = create_score_entry(i + 1, score_entry)
		scores_container.add_child(entry_panel)


func create_score_entry(rank: int, score_data: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)
	
	var hbox = HBoxContainer.new()
	panel.add_child(hbox)
	
	# Rank
	var rank_label = Label.new()
	rank_label.text = "#" + str(rank)
	rank_label.custom_minimum_size = Vector2(60, 0)
	rank_label.add_theme_font_size_override("font_size", 75)
	rank_label.add_theme_color_override("font_color", Color.GOLD)
	hbox.add_child(rank_label)
	
	# Score details
	var details_vbox = VBoxContainer.new()
	details_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var score_label = Label.new()
	score_label.text = "Score: %d" % score_data.score
	score_label.add_theme_font_size_override("font_size", 75)
	details_vbox.add_child(score_label)
	
	var stats_label = Label.new()
	stats_label.text = "Accuracy: %.1f%% | Max Combo: %d | Perfect:%d Good:%d Miss:%d" % [
		score_data.accuracy,
		score_data.max_combo,
		score_data.perfect,
		score_data.good,
		score_data.miss
	]
	stats_label.add_theme_font_size_override("font_size", 75)
	stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	details_vbox.add_child(stats_label)
	
	hbox.add_child(details_vbox)
	
	# Date
	var date_label = Label.new()
	var datetime = Time.get_datetime_dict_from_unix_time(score_data.timestamp)
	date_label.text = "%d/%d/%d" % [datetime.month, datetime.day, datetime.year]
	date_label.add_theme_font_size_override("font_size", 75)
	date_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hbox.add_child(date_label)
	
	return panel


func _on_back_pressed():
	# Go back to title screen
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

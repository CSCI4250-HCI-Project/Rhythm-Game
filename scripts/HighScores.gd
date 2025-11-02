extends Control

@onready var song_option_button = $VBoxContainer/FilterContainer/SongOptionButton
@onready var difficulty_option_button = $VBoxContainer/FilterContainer/DifficultyOptionButton
@onready var scores_container = $VBoxContainer/ScrollContainer/ScoresVBoxContainer
@onready var back_button = $VBoxContainer/BackButton

var high_scores = {}
var available_songs = []

func _ready():
	# Load high scores
	load_high_scores()
	
	# Populate song dropdown
	populate_song_options()
	
	# Setup difficulty dropdown
	difficulty_option_button.add_item("Easy")
	difficulty_option_button.add_item("Normal")
	difficulty_option_button.add_item("Hard")
	
	# Connect signals
	song_option_button.item_selected.connect(_on_filter_changed)
	difficulty_option_button.item_selected.connect(_on_filter_changed)
	back_button.pressed.connect(_on_back_pressed)
	
	# Display initial scores
	update_scores_display()


func load_high_scores():
	var save_file = FileAccess.open("user://highscores.save", FileAccess.READ)
	
	if save_file:
		var json_string = save_file.get_as_text()
		save_file.close()
		
		if json_string != "":
			var json = JSON.new()
			if json.parse(json_string) == OK:
				high_scores = json.data
	
	# Extract unique songs
	var songs_set = {}
	for key in high_scores.keys():
		var parts = key.split("_")
		if parts.size() >= 2:
			var song_id = parts[0]
			if not songs_set.has(song_id):
				songs_set[song_id] = true
				
				# Get song name from first entry
				if high_scores[key].size() > 0:
					available_songs.append({
						"id": song_id,
						"name": high_scores[key][0].song
					})


func populate_song_options():
	song_option_button.clear()
	
	if available_songs.size() == 0:
		song_option_button.add_item("No scores yet")
		song_option_button.disabled = true
		return
	
	for song in available_songs:
		song_option_button.add_item(song.name)


func _on_filter_changed(_index):
	update_scores_display()


func update_scores_display():
	# Clear existing score entries
	for child in scores_container.get_children():
		child.queue_free()
	
	if available_songs.size() == 0:
		var no_scores_label = Label.new()
		no_scores_label.text = "No high scores yet! Play some songs to set records!"
		no_scores_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_scores_label.add_theme_font_size_override("font_size", 24)
		scores_container.add_child(no_scores_label)
		return
	
	# Get selected filters
	var selected_song_index = song_option_button.selected
	var selected_difficulty_index = difficulty_option_button.selected
	
	if selected_song_index < 0 or selected_song_index >= available_songs.size():
		return
	
	var song_id = available_songs[selected_song_index].id
	var difficulty_names = ["Easy", "Normal", "Hard"]
	var difficulty = difficulty_names[selected_difficulty_index]
	
	# Get scores for this combination
	var key = "%s_%s" % [song_id, difficulty]
	var scores = high_scores.get(key, [])
	
	if scores.size() == 0:
		var no_scores_label = Label.new()
		no_scores_label.text = "No scores for this song/difficulty yet!"
		no_scores_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_scores_label.add_theme_font_size_override("font_size", 20)
		scores_container.add_child(no_scores_label)
		return
	
	# Display scores
	for i in range(scores.size()):
		var score_entry = scores[i]
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
	rank_label.add_theme_font_size_override("font_size", 32)
	rank_label.add_theme_color_override("font_color", Color.GOLD)
	hbox.add_child(rank_label)
	
	# Score details
	var details_vbox = VBoxContainer.new()
	details_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var score_label = Label.new()
	score_label.text = "Score: %d" % score_data.score
	score_label.add_theme_font_size_override("font_size", 24)
	details_vbox.add_child(score_label)
	
	var stats_label = Label.new()
	stats_label.text = "Accuracy: %.1f%% | Max Combo: %d | P:%d G:%d M:%d" % [
		score_data.accuracy,
		score_data.max_combo,
		score_data.perfect,
		score_data.good,
		score_data.miss
	]
	stats_label.add_theme_font_size_override("font_size", 16)
	stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	details_vbox.add_child(stats_label)
	
	hbox.add_child(details_vbox)
	
	# Date
	var date_label = Label.new()
	var datetime = Time.get_datetime_dict_from_unix_time(score_data.timestamp)
	date_label.text = "%d/%d/%d" % [datetime.month, datetime.day, datetime.year]
	date_label.add_theme_font_size_override("font_size", 16)
	date_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hbox.add_child(date_label)
	
	return panel


func _on_back_pressed():
	# Go back to title screen
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

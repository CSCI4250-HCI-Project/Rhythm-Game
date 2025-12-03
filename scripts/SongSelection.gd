extends Control

# Reference to the song buttons - we'll connect these in _ready()
@onready var song_list = $SongScrollContainer/SongList
@onready var back_button = $BackButton

# Dictionary to store song data
var songs = {
	"I'll Follow The Sun by The Beatles": {
		"audio": "res://assets/audio/I'll Follow The Sun by The Beatles.mp3",
		"charts": {
			"Easy": "res://charts/I'll_Follow_The_Sun_Easy.json",
			"Normal": "res://charts/I'll_Follow_The_Sun_Normal.json",
			"Hard": "res://charts/I'll_Follow_The_Sun_Hard.json"
		}
	},
	"First Steps from Celeste": {
		"audio": "res://assets/audio/Celeste_First_Steps.mp3",
		"charts": {
			"Easy": "res://charts/Celeste_First_Steps_Easy.json",
			"Normal": "res://charts/Celeste_First_Steps_Normal.json",
			"Hard": "res://charts/Celeste_First_Steps_Hard.json"
		}
	},
	"The Brink of Death from Chrono Cross": {
		"audio": "res://assets/audio/Chrono_Cross_The_Brink_Of_Death.mp3",
		"charts": {
			"Easy": "res://charts/Chrono_Cross_The_Brink_Of_Death_Easy.json",
			"Normal": "res://charts/Chrono_Cross_The_Brink_Of_Death_Normal.json",
			"Hard": "res://charts/Chrono_Cross_The_Brink_Of_Death_Hard.json"
		}
	},
	"Peaceful Days from Chrono Trigger SNES": {
		"audio": "res://assets/audio/Chrono_Trigger_Peaceful_Days_SNES.mp3",
		"charts": {
			"Easy": "res://charts/Chrono_Trigger_Peaceful_Days_SNES_Easy.json",
			"Normal": "res://charts/Chrono_Trigger_Peaceful_Days_SNES_Normal.json",
			"Hard": "res://charts/Chrono_Trigger_Peaceful_Days_SNES_Hard.json"
		}
	},
	"Title Screen from Chrono Trigger SNES": {
		"audio": "res://assets/audio/Chrono_Trigger_Title_Screen_SNES.mp3",
		"charts": {
			"Easy": "res://charts/Chrono_Trigger_Title_Screen_SNES_Easy.json",
			"Normal": "res://charts/Chrono_Trigger_Title_Screen_SNES_Normal.json",
			"Hard": "res://charts/Chrono_Trigger_Title_Screen_SNES_Hard.json"
		}
	},
	"Gauntlet NES": {
		"audio": "res://assets/audio/Gauntlet_NES.mp3",
		"charts": {
			"Easy": "res://charts/Gauntlet_NES_Easy.json",
			"Normal": "res://charts/Gauntlet_NES_Normal.json",
			"Hard": "res://charts/Gauntlet_NES_Hard.json"
		}
	},
	"Hollow Knight": {
		"audio": "res://assets/audio/Hollow_Knight.mp3",
		"charts": {
			"Easy": "res://charts/Hollow_Knight_Easy.json",
			"Normal": "res://charts/Hollow_Knight_Normal.json",
			"Hard": "res://charts/Hollow_Knight_Hard.json"
		}
	},
	"Radiance from Hollow Knight": {
		"audio": "res://assets/audio/Hollow_Knight_Radiance.mp3",
		"charts": {
			"Easy": "res://charts/Hollow_Knight_Radiance_Easy.json",
			"Normal": "res://charts/Hollow_Knight_Radiance_Normal.json",
			"Hard": "res://charts/Hollow_Knight_Radiance_Hard.json"
		}
	},
	"Title Screen from Mega Man 3 NES": {
		"audio": "res://assets/audio/Mega_Man_Title_Screen_NES.mp3",
		"charts": {
			"Easy": "res://charts/Mega_Man_Title_Screen_NES_Easy.json",
			"Normal": "res://charts/Mega_Man_Title_Screen_NES_Normal.json",
			"Hard": "res://charts/Mega_Man_Title_Screen_NES_Hard.json"
		}
	},
	"A Corner of Memories from Persona 4": {
		"audio": "res://assets/audio/Persona_4_A_Corner_Of_Memories.mp3",
		"charts": {
			"Easy": "res://charts/Persona_4_A_Corner_Of_Memories_Easy.json",
			"Normal": "res://charts/Persona_4_A_Corner_Of_Memories_Normal.json",
			"Hard": "res://charts/Persona_4_A_Corner_Of_Memories_Hard.json"
		}
	},
	"Persona 5": {
		"audio": "res://assets/audio/Persona_5.mp3",
		"charts": {
			"Easy": "res://charts/Persona_5_Easy.json",
			"Normal": "res://charts/Persona_5_Normal.json",
			"Hard": "res://charts/Persona_5_Hard.json"
		}
	},
	"Synthwave Burnout 1": {
		"audio": "res://assets/audio/Synthwave_Burnout_1.mp3",
		"charts": {
			"Easy": "res://charts/Synthwave_Burnout_1_Easy.json",
			"Normal": "res://charts/Synthwave_Burnout_1_Normal.json",
			"Hard": "res://charts/Synthwave_Burnout_1_Hard.json"
		}
	},
	"Synthwave Burnout 2": {
		"audio": "res://assets/audio/Synthwave_Burnout_2.mp3",
		"charts": {
			"Easy": "res://charts/Synthwave_Burnout_2_Easy.json",
			"Normal": "res://charts/Synthwave_Burnout_2_Normal.json",
			"Hard": "res://charts/Synthwave_Burnout_2_Hard.json"
		}
	},
	"Title Screen from The Legend of Zelda NES": {
		"audio": "res://assets/audio/The_Legend_Of_Zelda_Title_Screen_NES.mp3",
		"charts": {
			"Easy": "res://charts/The_Legend_Of_Zelda_Title_Screen_NES_Easy.json",
			"Normal": "res://charts/The_Legend_Of_Zelda_Title_Screen_NES_Normal.json",
			"Hard": "res://charts/The_Legend_Of_Zelda_Title_Screen_NES_Hard.json"
		}
	}
}

func _ready():
	# Connect all song buttons dynamically
	for child in song_list.get_children():
		if child is Button:
			var song_name = child.text if child.text != "" else child.name
			child.pressed.connect(_on_song_pressed.bind(song_name))
	
	# Connect back button
	back_button.pressed.connect(_on_back_pressed)

func _on_song_pressed(song_name: String):
	if not songs.has(song_name):
		push_error("Song not found: " + song_name)
		return
	
	var song_data = songs[song_name]
	var difficulty = GameSettings.difficulty
	
	# Set the audio path
	GameSettings.selected_song = song_data.audio
	
	# Set the chart based on difficulty
	if song_data.charts.has(difficulty):
		GameSettings.selected_chart = song_data.charts[difficulty]
	else:
		# Fallback to Easy if difficulty not found
		GameSettings.selected_chart = song_data.charts["Easy"]
	
	print("Song selected: ", song_name)
	print("Difficulty: ", difficulty)
	print("Chart: ", GameSettings.selected_chart)
	
	# Start the game!
	get_tree().change_scene_to_file("res://scenes/ArrowGame.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/DifficultySelection.tscn")

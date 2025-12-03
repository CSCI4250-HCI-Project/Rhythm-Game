extends TextureRect

# References to other nodes (drag these in from the editor)
@export var arrow_up: TextureRect
@export var arrow_down: TextureRect
@export var arrow_left: TextureRect
@export var arrow_right: TextureRect
@export var feedback_label: Label
@export var score_label: Label
@export var timer_label: Label
@export var countdown_label: Label
@export var combo_milestone_label: Label
@export var music_player: AudioStreamPlayer
@export var conductor: Node

# Particle systems
@export var up_particles: GPUParticles2D
@export var down_particles: GPUParticles2D
@export var left_particles: GPUParticles2D
@export var right_particles: GPUParticles2D

# Light nodes
@export var up_light: PointLight2D
@export var down_light: PointLight2D
@export var left_light: PointLight2D
@export var right_light: PointLight2D

# Corner nodes for convergence
@export var corner_upper_left: TextureRect
@export var corner_upper_right: TextureRect
@export var corner_lower_left: TextureRect
@export var corner_lower_right: TextureRect

# Corner particle systems
@export var upper_left_particles: GPUParticles2D
@export var upper_right_particles: GPUParticles2D
@export var lower_left_particles: GPUParticles2D
@export var lower_right_particles: GPUParticles2D

# Corner lights
@export var upper_left_light: PointLight2D
@export var upper_right_light: PointLight2D
@export var lower_left_light: PointLight2D
@export var lower_right_light: PointLight2D

# Flash Settings
@export_group("Flash Settings")
@export var flash_color_tint: Color = Color(0.2, 2.0, 2.0, 1.0) # For the Corner Box
@export var flash_intensity: float = 4.0      # How bright the Light gets
@export var flash_duration: float = 0.6       # Total time in seconds

# Chart file path
var chart_file: String = ""

# Preload arrow textures 
@onready var arrow_up_texture = preload("res://assets/visuals/up_arrow.png") 
@onready var arrow_down_texture = preload("res://assets/visuals/down_arrow.png") 
@onready var arrow_left_texture = preload("res://assets/visuals/left_arrow.png") 
@onready var arrow_right_texture = preload("res://assets/visuals/right_arrow.png")

# Movement
var arrows = {}
var corners = {}
var target_arrow = ""
var target_position = Vector2()
var center_position = Vector2()
var speed := 400.0
var base_speed := 400.0
var active := false
var overshoot_distance := 80.0  # CHANGED from 30 to 80
var overshooting := false
var speed_multiplier = 1.0

# Countdown
var countdown_active := false
var countdown_time := 3

# Timing
var arrow_start_time := 0.0
var travel_time := 0.0
var target_reach_time := 0.0
var hit_registered := false

# Combo multiplier system
var combo_multiplier := 1
var last_combo_milestone := 0

# Chart data
var chart_data = {}
var note_queue = []
var current_note_index = 0
var song_start_time := 0.0
var song_playing := false

# Song duration and game over tracking
var song_duration := 0.0
var game_over_triggered := false

# Statistics tracking
var stats = {
	"perfect": 0,
	"good": 0,
	"miss": 0,
	"max_combo": 0
}

# Preload the Arrow scene
var arrow_scene = preload("res://scenes/Arrow.tscn")

# Pause handling
var pause_start_time: float = 0.0
var total_pause_time: float = 0.0
var was_paused: bool = false

# Track active arrows (can be multiple for convergence)
var active_arrows = []
var current_note_type = ""  # "tap", "chord", or "convergence"
var convergence_corners_active = []  # Changed from single string to Array
var convergence_corners_original = []
var chord_keys_required = []
var chord_keys_pressed = []

func set_direction(direction): 
	if direction is Array:
		texture = get_texture_for_direction(direction[0])
	elif direction is String:
		texture = get_texture_for_direction(direction)
	else:
		texture = null

func get_texture_for_direction(dir: String):
	match dir: 
		"Up", "up": 
			return arrow_up_texture 
		"Down", "down": 
			return arrow_down_texture 
		"Left", "left": 
			return arrow_left_texture 
		"Right", "right": 
			return arrow_right_texture 
		_: 
			return arrow_up_texture

func _ready():
	print("Center._ready() START")
	
	# Make this node process during pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	center_position = global_position

	# Setup arrow positions
	arrows = {
		"Up": arrow_up.global_position,
		"Down": arrow_down.global_position,
		"Left": arrow_left.global_position,
		"Right": arrow_right.global_position,
		"up": arrow_up.global_position,
		"down": arrow_down.global_position,
		"left": arrow_left.global_position,
		"right": arrow_right.global_position
	}
	
	# Setup corner positions (calculated from arrow positions)
	corners = {
		"upper_left": Vector2(arrow_left.global_position.x, arrow_up.global_position.y),
		"upper_right": Vector2(arrow_right.global_position.x, arrow_up.global_position.y),
		"lower_left": Vector2(arrow_left.global_position.x, arrow_down.global_position.y),
		"lower_right": Vector2(arrow_right.global_position.x, arrow_down.global_position.y)
	}
	
	# --- FIX STARTS HERE ---
	# Apply these calculated positions to the actual Corner nodes!
	if corner_upper_left:
		corner_upper_left.global_position = corners["upper_left"]
	if corner_upper_right:
		corner_upper_right.global_position = corners["upper_right"]
	if corner_lower_left:
		corner_lower_left.global_position = corners["lower_left"]
	if corner_lower_right:
		corner_lower_right.global_position = corners["lower_right"]
	# --- FIX ENDS HERE ---
	
	# --- FIX START: Move the Lights too! ---
	if upper_left_light: upper_left_light.global_position = corners["upper_left"]
	if upper_right_light: upper_right_light.global_position = corners["upper_right"]
	if lower_left_light: lower_left_light.global_position = corners["lower_left"]
	if lower_right_light: lower_right_light.global_position = corners["lower_right"]
	# --- FIX END ---
	
	# Make directional arrows transparent
	arrow_up.modulate = Color(1, 1, 1, 0.3)
	arrow_down.modulate = Color(1, 1, 1, 0.3)
	arrow_left.modulate = Color(1, 1, 1, 0.3)
	arrow_right.modulate = Color(1, 1, 1, 0.3)

	size = arrow_up.size
	ScoreManager.hit_result.connect(_on_hit_result)

	score_label.text = "Score: " + str(ScoreManager.score)
	feedback_label.text = ""

	# Hide labels initially
	if timer_label:
		timer_label.hide()
	if combo_milestone_label:
		combo_milestone_label.hide()
	
# Set speed multiplier based on difficulty
	var difficulty = GameSettings.difficulty
	match difficulty:
		"Easy":
			# slightly faster than before
			base_speed = 350.0 
			speed_multiplier = 1.2 
		"Normal":
			# 25% speed boost to all notes
			base_speed = 400.0
			speed_multiplier = 1.5 
		"Hard":
			# 40% speed boost (Fast!)
			base_speed = 500.0
			speed_multiplier = 2.0
		_:
			base_speed = 400.0
			speed_multiplier = 1.0

	chart_file = GameSettings.selected_chart
	
	print("Center.gd _ready() - Chart file: ", chart_file)
	print("Center.gd _ready() - Song file: ", GameSettings.selected_song)
	print("Center.gd _ready() - Difficulty: ", difficulty)
	print("Center.gd _ready() - Base speed: ", base_speed)

	load_chart()
	print("Chart loaded, starting countdown...")
	
	start_countdown()
	
	# Hide the corner boxes by making them transparent
	if corner_upper_left: corner_upper_left.modulate.a = 0
	if corner_upper_right: corner_upper_right.modulate.a = 0
	if corner_lower_left: corner_lower_left.modulate.a = 0
	if corner_lower_right: corner_lower_right.modulate.a = 0


func start_countdown():
	if not countdown_label:
		push_error("CountdownLabel not found!")
		start_song()
		return
	
	countdown_active = true
	countdown_label.show()
	
	# Countdown 3, 2, 1, GO!
	for i in range(3, 0, -1):
		countdown_label.text = "   " + str(i) + "   "
		countdown_label.modulate = Color(1, 1, 1, 1)
		
		var tween = create_tween()
		tween.tween_property(countdown_label, "modulate:a", 0.5, 0.8)
		
		await get_tree().create_timer(1.0).timeout
	
	# Show GO!
	countdown_label.text = " " + "GO!" + "    "
	countdown_label.modulate = Color(1, 1, 1, 1)
	
	var go_tween = create_tween()
	go_tween.tween_property(countdown_label, "modulate:a", 0, 0.5)
	
	await get_tree().create_timer(0.6).timeout
	countdown_label.hide()
	countdown_active = false
	
	start_song()
	
	if timer_label:
		timer_label.show()


func load_chart():
	if chart_file == "":
		push_error("Chart file path is empty!")
		return
	
	if not FileAccess.file_exists(chart_file):
		push_error("Chart file not found: " + chart_file)
		return
	
	var file = FileAccess.open(chart_file, FileAccess.READ)
	if file == null:
		push_error("Could not open chart file: " + chart_file)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse chart JSON: " + chart_file)
		return
	
	chart_data = json.data
	note_queue = chart_data.get("notes", [])
	
	print("Chart loaded: " + chart_data.get("title", "Unknown"))
	print("Total notes: " + str(note_queue.size()))


func start_song():
	print("start_song() called")
	
	if not music_player:
		push_error("music_player is null!")
		return
	
	if not chart_data.has("song_file"):
		return
	
	var song_filename = chart_data["song_file"]
	
	var possible_paths = [
		"res://assets/audio/" + song_filename,
		"res://assets/audio/songs/" + song_filename,
		"res://audio/" + song_filename,
		"res://" + song_filename,
		GameSettings.selected_song
	]
	
	var song_path = ""
	for path in possible_paths:
		if FileAccess.file_exists(path):
			song_path = path
			break
	
	if song_path != "":
		var audio_stream = load(song_path)
		if audio_stream:
			music_player.stream = audio_stream
			song_duration = audio_stream.get_length()
			print("Song duration detected: ", song_duration, " seconds")
			
			music_player.play()
			song_start_time = Time.get_ticks_msec() / 1000.0
			song_playing = true
			current_note_index = 0
			print("Song started successfully!")
		else:
			push_error("Failed to load audio stream")
	else:
		push_error("Song file not found")
		song_start_time = Time.get_ticks_msec() / 1000.0
		song_playing = true
		current_note_index = 0


func lane_to_direction(lane: int) -> String:
	match lane:
		0: return "Left"
		1: return "Down"
		2: return "Up"
		3: return "Right"
		_: return "Up"


func direction_string_to_standard(dir: String) -> String:
	match dir.to_lower():
		"up": return "Up"
		"down": return "Down"
		"left": return "Left"
		"right": return "Right"
		_: return "Up"


func spawn_next_arrow():
	if current_note_index >= note_queue.size():
		return
	
	print("=== SPAWNING NOTE #", current_note_index + 1, " ===")
	
	var note = note_queue[current_note_index]
	print("Note data: ", note)
	
	var note_type = note.get("type", "tap")
	current_note_type = note_type
	
	# Get speed from note or use base speed
	var note_speed = base_speed
	if note.has("speed"):
		note_speed = float(note.get("speed"))
	note_speed = note_speed * speed_multiplier
	# Clear previous state
	clear_active_arrows()
	chord_keys_required.clear()
	chord_keys_pressed.clear()
	convergence_corners_active.clear() # <--- This is the new Array variable
	
	# Handle different note types
	if note_type == "convergence":
		# NEW: Convergence note
		spawn_convergence_note(note, note_speed)
	elif note_type == "chord":
		# Chord note - spawn from center
		var direction = note.get("direction", "up")
		var directions_to_spawn = []
		
		if direction is Array:
			for dir in direction:
				var normalized_dir = direction_string_to_standard(str(dir))
				directions_to_spawn.append(normalized_dir)
		else:
			directions_to_spawn.append(direction_string_to_standard(str(direction)))
		
		for dir in directions_to_spawn:
			spawn_regular_arrow(dir, note_speed)
			chord_keys_required.append(dir)
	else:
		# Single tap note - spawn from center
		var direction = note.get("direction", "up")
		var normalized_dir = direction_string_to_standard(str(direction))
		spawn_regular_arrow(normalized_dir, note_speed)
		chord_keys_required.append(normalized_dir)
	
	active = true
	hit_registered = false
	arrow_start_time = Time.get_ticks_msec() / 1000.0
	
	# Calculate when arrows should reach target
	if current_note_type == "convergence":
		# --- FIX IS HERE ---
		# We check the first corner in the active list
		var first_active_corner = convergence_corners_active[0]
		var corner_pos = corners[first_active_corner]
		
		var first_arrow = active_arrows[0]
		var distance = (corner_pos - first_arrow.global_position).length()
		travel_time = distance / note_speed
	else:
		# Use directional arrow position for timing
		var first_dir = chord_keys_required[0]
		travel_time = (arrows[first_dir] - center_position).length() / note_speed
	
	target_reach_time = arrow_start_time + travel_time
	
	current_note_index += 1

func spawn_regular_arrow(direction: String, arrow_speed: float):
	"""Spawn a regular arrow from center to directional arrow"""
	var arrow_instance = arrow_scene.instantiate()
	get_parent().add_child(arrow_instance)
	
	var target_pos = arrows[direction]
	arrow_instance.setup(direction, target_pos, center_position, arrow_speed)
	arrow_instance.modulate = Color(1, 1, 1, 1)  # Fully opaque
	
	active_arrows.append(arrow_instance)
	print("Spawned regular arrow: ", direction, " at speed ", arrow_speed)


func spawn_convergence_note(note: Dictionary, note_speed: float):
	"""Spawn a convergence note - supports single OR double convergence"""
	var corner_data = note.get("corner", "upper_right")
	
	# Handle both Single String ("upper_right") and Array (["upper_right", "lower_left"])
	var corners_to_spawn = []
	if corner_data is Array:
		corners_to_spawn = corner_data
	else:
		corners_to_spawn.append(corner_data)
		
	active = true
	
	# Clear previous
	convergence_corners_active.clear()
	convergence_corners_original.clear() # <--- Clear the memory list
	
	for corner in corners_to_spawn:
		convergence_corners_active.append(corner)
		convergence_corners_original.append(corner) # <--- Save to memory list
		
		# ... (Rest of the function stays exactly the same as before) ...
		# ... (Spawning arrows logic) ...
		# ...
		
		# (Just copy the rest of your spawning logic here from the previous step)
		# Determine directions, spawn arrows, etc.
		print("Spawning convergence note at corner: ", corner)
		var dir1 = ""; var dir2 = ""; var start_pos1 = Vector2(); var start_pos2 = Vector2()
		var corner_pos = corners[corner]
		match corner:
			"upper_right":
				dir1 = "Right"; dir2 = "Up"; start_pos1 = arrows["Up"]; start_pos2 = arrows["Right"]
			"lower_right":
				dir1 = "Down"; dir2 = "Right"; start_pos1 = arrows["Right"]; start_pos2 = arrows["Down"]
			"lower_left":
				dir1 = "Left"; dir2 = "Down"; start_pos1 = arrows["Down"]; start_pos2 = arrows["Left"]
			"upper_left":
				dir1 = "Up"; dir2 = "Left"; start_pos1 = arrows["Left"]; start_pos2 = arrows["Up"]
		
		var arrow1 = arrow_scene.instantiate(); get_parent().add_child(arrow1)
		arrow1.setup_convergence(dir1, corner_pos, start_pos1, note_speed); active_arrows.append(arrow1)
		
		var arrow2 = arrow_scene.instantiate(); get_parent().add_child(arrow2)
		arrow2.setup_convergence(dir2, corner_pos, start_pos2, note_speed); active_arrows.append(arrow2)


func clear_active_arrows():
	"""Remove all active arrows"""
	for arrow in active_arrows:
		if is_instance_valid(arrow):
			arrow.deactivate()
	active_arrows.clear()


func update_combo_multiplier():
	var current_combo = ScoreManager.combo
	
	if current_combo >= 40:
		combo_multiplier = 4
	elif current_combo >= 30:
		combo_multiplier = 4
	elif current_combo >= 20:
		combo_multiplier = 3
	elif current_combo >= 10:
		combo_multiplier = 2
	else:
		combo_multiplier = 1
	
	var milestone = 0
	if current_combo >= 40:
		milestone = 40
	elif current_combo >= 30:
		milestone = 30
	elif current_combo >= 20:
		milestone = 20
	elif current_combo >= 10:
		milestone = 10
	
	if milestone > 0 and milestone > last_combo_milestone:
		last_combo_milestone = milestone
		show_combo_milestone(milestone)


func show_combo_milestone(milestone: int):
	if not combo_milestone_label:
		return
	
	combo_milestone_label.text = "%d COMBO! %dx MULTIPLIER!" % [milestone, combo_multiplier]
	combo_milestone_label.modulate = Color(1, 0.843, 0, 1)
	combo_milestone_label.scale = Vector2(1.5, 1.5)
	combo_milestone_label.show()
	
	var tween = create_tween()
	tween.tween_property(combo_milestone_label, "modulate:a", 0, 1.5)
	tween.tween_callback(func(): combo_milestone_label.hide())


func _process(delta):
	# Handle pause state changes
	if get_tree().paused:
		if not was_paused:
			pause_start_time = Time.get_ticks_msec() / 1000.0
			was_paused = true
		return
	else:
		if was_paused:
			var pause_duration = Time.get_ticks_msec() / 1000.0 - pause_start_time
			total_pause_time += pause_duration
			
			song_start_time += pause_duration
			arrow_start_time += pause_duration
			target_reach_time += pause_duration
			
			was_paused = false
	
	update_combo_multiplier()
	
	if ScoreManager.combo > stats.max_combo:
		stats.max_combo = ScoreManager.combo
	
	if score_label:
		score_label.text = "Score: %d   Combo: %d   %dx" % [ScoreManager.score, ScoreManager.combo, combo_multiplier]

	# Update timer
	if song_playing and timer_label and music_player and music_player.playing:
		var time_remaining = music_player.stream.get_length() - music_player.get_playback_position()
		var minutes = int(time_remaining) / 60
		var seconds = int(time_remaining) % 60
		timer_label.text = "%d:%02d" % [minutes, seconds]
		
		if time_remaining <= 0.1 and not game_over_triggered:
			game_over_triggered = true
			call_deferred("trigger_game_over")

	# Check if time to spawn
	if song_playing and not active and current_note_index < note_queue.size():
		var current_song_time = Time.get_ticks_msec() / 1000.0 - song_start_time
		var next_note = note_queue[current_note_index]
		var note_time = next_note.get("time", 0.0)
		
		if note_time > 1000:
			note_time = note_time / 1000.0
		
		var spawn_travel_time = (arrows["Up"] - center_position).length() / base_speed
		var spawn_time = note_time - spawn_travel_time
		
		if current_song_time >= spawn_time:
			spawn_next_arrow()

	# Check for miss (arrows passed Good window)
	var current_time = Time.get_ticks_msec() / 1000.0
	if not hit_registered and active and current_time > target_reach_time + ScoreManager.GOOD_WINDOW:
		apply_score_with_multiplier("Miss", 0)
		hit_registered = true
		clear_active_arrows()
		active = false
		chord_keys_required.clear()
		chord_keys_pressed.clear()
		convergence_corners_active.clear()


func apply_score_with_multiplier(result: String, base_points: int):
	var final_points = base_points * combo_multiplier
	ScoreManager._apply_score(result, final_points)
	
	match result:
		"Perfect":
			stats.perfect += 1
		"Good":
			stats.good += 1
		"Miss":
			stats.miss += 1
			last_combo_milestone = 0


func _input(event):
	if get_tree().paused:
		return
	
	if not active:
		return
	
	# Handle convergence notes separately
	if current_note_type == "convergence":
		handle_convergence_input()
	else:
		handle_regular_input()


func handle_regular_input():
	"""Handle input for regular tap and chord notes"""
	var pressed_arrows = []
	if Input.is_action_just_pressed("ui_up"):
		pressed_arrows.append("Up")
	if Input.is_action_just_pressed("ui_down"):
		pressed_arrows.append("Down")
	if Input.is_action_just_pressed("ui_left"):
		pressed_arrows.append("Left")
	if Input.is_action_just_pressed("ui_right"):
		pressed_arrows.append("Right")
	
	if pressed_arrows.is_empty():
		return
	
	# Process each pressed arrow
	for pressed_arrow in pressed_arrows:
		# Check if this key is required
		if pressed_arrow not in chord_keys_required:
			# Wrong key
			apply_score_with_multiplier("Miss", 0)
			_show_feedback("Miss")
			clear_active_arrows()
			active = false
			hit_registered = true
			chord_keys_required.clear()
			chord_keys_pressed.clear()
			return
		
		# Add to pressed keys
		if pressed_arrow not in chord_keys_pressed:
			chord_keys_pressed.append(pressed_arrow)
	
	# Check if all required keys pressed
	if chord_keys_pressed.size() == chord_keys_required.size():
		var current_time = Time.get_ticks_msec() / 1000.0
		var offset = abs(current_time - target_reach_time)
		
		var result = ""
		var base_points = 0
		
		if chord_keys_required.size() > 1:
			# Chord note
			if offset <= ScoreManager.PERFECT_WINDOW:
				result = "Perfect"
				base_points = 500
				for dir in chord_keys_required:
					_trigger_particles(dir)
					_flash_arrow(dir)
			elif offset <= ScoreManager.GOOD_WINDOW:
				result = "Good"
				base_points = 200
			else:
				result = "Miss"
				base_points = 0
			
			apply_score_with_multiplier(result, base_points)
			_show_feedback(result + " Chord!")
		else:
			# Single note
			if offset <= ScoreManager.PERFECT_WINDOW:
				result = "Perfect"
				base_points = 300
				_trigger_particles(chord_keys_required[0])
				_flash_arrow(chord_keys_required[0])
			elif offset <= ScoreManager.GOOD_WINDOW:
				result = "Good"
				base_points = 100
			else:
				result = "Miss"
				base_points = 0
			
			apply_score_with_multiplier(result, base_points)
			_show_feedback(result)
		
		# Clean up
		clear_active_arrows()
		active = false
		hit_registered = true
		chord_keys_required.clear()
		chord_keys_pressed.clear()


func handle_convergence_input():
	"""Handle input for convergence notes (Single or Double)"""
	var pressed_corners = []
	
	if Input.is_action_just_pressed("convergence_upper_left"): pressed_corners.append("upper_left")
	if Input.is_action_just_pressed("convergence_upper_right"): pressed_corners.append("upper_right")
	if Input.is_action_just_pressed("convergence_lower_left"): pressed_corners.append("lower_left")
	if Input.is_action_just_pressed("convergence_lower_right"): pressed_corners.append("lower_right")
	
	if pressed_corners.is_empty():
		return

	for corner_key in pressed_corners:
		# Check if this pressed key is one of the ones we need right now
		if corner_key in convergence_corners_active:
			# CORRECT HIT for this specific corner
			_trigger_corner_effects(corner_key) # Trigger particles immediately
			
			# Remove this corner from the required list
			convergence_corners_active.erase(corner_key)
			
			# If we have hit ALL required corners, calculate score
			if convergence_corners_active.is_empty():
				var current_time = Time.get_ticks_msec() / 1000.0
				var offset = abs(current_time - target_reach_time)
				
				var result = ""
				var base_points = 0
				
				if offset <= ScoreManager.PERFECT_WINDOW:
					result = "Perfect"
					base_points = 300
					
					# --- VISUAL FIX: Flash ALL corners involved in this note ---
					for c in convergence_corners_original:
						_flash_corner(c)
					# -----------------------------------------------------------
					
				elif offset <= ScoreManager.GOOD_WINDOW:
					result = "Good"
					base_points = 100
				else:
					result = "Miss"
					base_points = 0
				
				apply_score_with_multiplier(result, base_points)
				_show_feedback(result + " Convergence!")
				
				clear_active_arrows()
				active = false
				hit_registered = true
				
		elif corner_key in convergence_corners_original:
			# --- SAFETY FIX: ALREADY HIT ---
			# The player pressed a key that was required, but they already hit it 
			# (maybe a double press or bouncing keyboard).
			# IGNORE this input. Do NOT trigger a Miss.
			pass
			
		else:
			# WRONG KEY -> MISS
			# The player pressed a corner that was NEVER part of this note.
			apply_score_with_multiplier("Miss", 0)
			_show_feedback("Miss")
			clear_active_arrows()
			active = false
			hit_registered = true
			convergence_corners_active.clear()
			return

func _trigger_corner_effects(corner: String):
	"""Trigger particles and lights at the corner"""
	print("🎆 TRIGGERING CORNER EFFECTS FOR: ", corner)  # ADD THIS
	
	var particles = null
	var light = null
	
	match corner:
		"upper_left":
			particles = upper_left_particles
			light = upper_left_light
		"upper_right":
			particles = upper_right_particles
			light = upper_right_light
		"lower_left":
			particles = lower_left_particles
			light = lower_left_light
		"lower_right":
			particles = lower_right_particles
			light = lower_right_light
	
	print("Particles found: ", particles)  # ADD THIS
	print("Light found: ", light)  # ADD THIS
	
	if particles:
		print("Restarting particles!")  # ADD THIS
		particles.restart()
		particles.emitting = true
	
	if light:
			light.enabled = true
			light.energy = flash_intensity * 0.5 # Start at half brightness
			
			# Calculate timing
			var flash_in = flash_duration * 0.1
			var fade_out = flash_duration * 0.9
			
			var light_tween = create_tween()
			# USE THE INSPECTOR VARIABLE HERE
			light_tween.tween_property(light, "energy", flash_intensity, flash_in)
			light_tween.tween_property(light, "energy", 0.0, fade_out)
			light_tween.tween_callback(func(): light.enabled = false)

func _flash_corner(corner: String):
	"""Flash the corner node on Perfect convergence"""
	var corner_node = null
	
	match corner:
		"upper_left":
			corner_node = corner_upper_left
		"upper_right":
			corner_node = corner_upper_right
		"lower_left":
			corner_node = corner_lower_left
		"lower_right":
			corner_node = corner_lower_right
	
	if corner_node:
			# USE THE INSPECTOR VARIABLE HERE
			var flash_color = flash_color_tint 
			var fade_color = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
			
			# Calculate split timing based on total duration
			var flash_in = flash_duration * 0.1  # 10% of time to pop in
			var fade_out = flash_duration * 0.9  # 90% of time to fade out
			
			corner_node.modulate.a = 1.0
			var tween = create_tween()
			tween.tween_property(corner_node, "modulate", flash_color, flash_in)\
				.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			tween.tween_property(corner_node, "modulate", fade_color, fade_out)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _show_feedback(result: String):
	feedback_label.text = result
	score_label.text = "Score: " + str(ScoreManager.score)
	feedback_label.modulate = Color(1, 1, 1, 1)
	feedback_label.scale = Vector2(1.2, 1.2)
	feedback_label.create_tween().tween_property(feedback_label, "modulate:a", 0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _flash_arrow(arrow_name: String):
	print("🚨 _flash_arrow() CALLED FOR: ", arrow_name)  # ADD THIS LINE
	var arrow = null
	match arrow_name:
		"Up": arrow = arrow_up
		"Down": arrow = arrow_down
		"Left": arrow = arrow_left
		"Right": arrow = arrow_right
	if arrow:
		var flash_color = Color(0.3, 0.8, 1.0, 1.0)
		var bright_flash = Color(1.5, 2.0, 2.5, 1.0)
		
		var tween = create_tween()
		tween.tween_property(arrow, "modulate", bright_flash, 0.05)
		tween.tween_property(arrow, "modulate", flash_color, 0.15)
		tween.tween_property(arrow, "modulate", Color(1, 1, 1, 0.3), 0.3)

func _trigger_light(arrow_name: String):
	var light = null
	match arrow_name:
		"Up": light = up_light
		"Down": light = down_light
		"Left": light = left_light
		"Right": light = right_light
	
	if light:
		light.enabled = true
		light.energy = 2.0
		var light_tween = create_tween()
		light_tween.tween_property(light, "energy", 4.0, 0.05)
		light_tween.tween_property(light, "energy", 0.0, 0.4)
		light_tween.tween_callback(func(): light.enabled = false)


func _trigger_particles(arrow_name: String):
	var particles = null
	match arrow_name:
		"Up": particles = up_particles
		"Down": particles = down_particles
		"Left": particles = left_particles
		"Right": particles = right_particles
	
	if particles:
		particles.restart()
		particles.emitting = true


func _reset_center():
	clear_active_arrows()
	active = false
	chord_keys_required.clear()
	chord_keys_pressed.clear()
	convergence_corners_active.clear()
	convergence_corners_original.clear()


func _on_hit_result(result: String, score: int, combo: int) -> void:
	if score_label:
		score_label.text = "Score: %d   Combo: %d   %dx" % [score, combo, combo_multiplier]

	if feedback_label:
		var points = 0
		match result:
			"Perfect":
				points = 300 * combo_multiplier
			"Good":
				points = 100 * combo_multiplier
			"Miss":
				points = 0
		feedback_label.text = "%s  +%d" % [result, points]
		feedback_label.modulate = Color.WHITE
		feedback_label.show()
		await get_tree().create_timer(0.5).timeout
		feedback_label.hide()


func trigger_game_over():
	song_playing = false
	
	var total_notes = stats.perfect + stats.good + stats.miss
	var accuracy = 0.0
	if total_notes > 0:
		accuracy = float(stats.perfect + stats.good) / float(total_notes) * 100.0
	
	save_high_score(accuracy)
	
	get_tree().change_scene_to_file("res://scenes/ResultsScreen.tscn")


func save_high_score(accuracy: float):
	var save_data = {
		"song": chart_data.get("title", "Unknown"),
		"song_id": GameSettings.selected_song,
		"difficulty": GameSettings.difficulty,
		"score": ScoreManager.score,
		"accuracy": accuracy,
		"max_combo": stats.max_combo,
		"perfect": stats.perfect,
		"good": stats.good,
		"miss": stats.miss,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	GameSettings.last_game_stats = save_data
	
	var save_file = FileAccess.open("user://highscores.save", FileAccess.READ_WRITE)
	var high_scores = {}
	
	if save_file:
		var json_string = save_file.get_as_text()
		if json_string != "":
			var json = JSON.new()
			if json.parse(json_string) == OK:
				high_scores = json.data
		save_file.close()
	
	var key = "%s_%s" % [save_data.song_id, save_data.difficulty]
	
	if not high_scores.has(key):
		high_scores[key] = []
	
	high_scores[key].append(save_data)
	
	high_scores[key].sort_custom(func(a, b): return a.score > b.score)
	if high_scores[key].size() > 10:
		high_scores[key] = high_scores[key].slice(0, 10)
	
	save_file = FileAccess.open("user://highscores.save", FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify(high_scores))
		save_file.close()
		print("High score saved!")

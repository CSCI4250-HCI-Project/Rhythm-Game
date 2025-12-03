extends Control

# UI Elements
@onready var character_face = $CharacterFace
@onready var score_label = $ScoreLabel
@onready var timer_label = $TimerLabel
@onready var attack_container = $AttackContainer

# ComboLabel is optional - check if it exists
var combo_label = null

# Attack spawn positions (where limbs start)
@onready var upper_left_marker = $AttackPositions/UpperLeft
@onready var upper_right_marker = $AttackPositions/UpperRight
@onready var lower_left_marker = $AttackPositions/LowerLeft
@onready var lower_right_marker = $AttackPositions/LowerRight

# Center position (where limbs move toward)
var screen_center: Vector2

# ADJUSTABLE POSITIONS - Change these values to position elements where you want them!
# Center target (where limbs disappear) - adjust these percentages
var center_x_percent = 0.48  # 0.5 = middle of screen, 0.4 = more left, 0.6 = more right
var center_y_percent = 0.45  # 0.5 = middle of screen, 0.3 = higher up, 0.7 = lower down

# Punch prompt positions - adjust these pixel values
var punch_left_x = 1350  # Distance from left edge
var punch_right_x_offset = 1650  # Distance from right edge
var punch_y_percent = 0.4  # 0.5 = middle height

# Individual limb image settings - adjust each separately!
var right_arm_size = 200  # Size for right arm (upper left)
var right_arm_rotation = -45  # Rotation for right arm

var left_arm_size = 200  # Size for left arm (upper right)
var left_arm_rotation = 45  # Rotation for left arm

var right_leg_size = 200  # Size for right leg (lower left)
var right_leg_rotation = -135  # Rotation for right leg

var left_leg_size = 200  # Size for left leg (lower right)
var left_leg_rotation = 135  # Rotation for left leg

var punch_left_size = 300  # Size for "PUNCH LEFT" circle
var punch_right_size = 300  # Size for "PUNCH RIGHT" circle

# Preload images
var fighter_face_texture = preload("res://assets/visuals/karate_reflexes/FighterFace.png")
var left_fist_texture = preload("res://assets/visuals/karate_reflexes/LeftFist.png")
var right_fist_texture = preload("res://assets/visuals/karate_reflexes/RightFist.png")
var left_leg_texture = preload("res://assets/visuals/karate_reflexes/LeftLeg.png")
var right_leg_texture = preload("res://assets/visuals/karate_reflexes/RightLeg.png")

# Preload audio
var blocked_audio = preload("res://assets/audio/karate_reflexes/blocked.wav")
var punch_connected_audio = preload("res://assets/audio/karate_reflexes/punch_connected.wav")
var missed_block_audio = preload("res://assets/audio/karate_reflexes/missed_block.wav")
var missed_punch_audio = preload("res://assets/audio/karate_reflexes/missed_punch.wav")

# Audio player
var audio_player = null

# Game variables
var score = 0
var combo = 0
var current_attack = null
var current_attack_node = null
var attack_start_time = 0.0
var attack_elapsed = 0.0
var max_reaction_time = 1.0  # Will be set based on difficulty
var is_attack_active = false
var time_between_attacks = 0.8  # Time to wait between attacks
var waiting_for_next_attack = false
var wait_timer = 0.0

# Statistics tracking
var total_blocks = 0
var total_punches = 0
var total_misses = 0

# Feedback label for showing BLOCKED, PUNCH CONNECTED, etc.
var feedback_label = null

# Game timer
var game_time_limit = 10.0  # 30 seconds total
var game_time_remaining = 10.0

# Countdown at start
var countdown_active = true
var countdown_time = 4.0  # Start at 4 to allow time for "GO!"
var countdown_label = null

# Pause system
var is_paused = false
var pause_menu = null

# Gesture Receiver
var gesture_receiver = null

# Attack types
enum AttackType {
	RIGHT_ARM_PUNCH,   # Appears upper left (opponent's right)
	LEFT_ARM_PUNCH,    # Appears upper right (opponent's left)
	RIGHT_LEG_KICK,    # Appears lower left (opponent's right)
	LEFT_LEG_KICK,     # Appears lower right (opponent's left)
	COUNTER_PUNCH_LEFT,   # Player punches left
	COUNTER_PUNCH_RIGHT   # Player punches right
}

func _ready():
	# Set the fighter face
	if character_face and fighter_face_texture:
		character_face.texture = fighter_face_texture
	
	# Check if ComboLabel exists
	if has_node("ComboLabel"):
		combo_label = $ComboLabel
	
	# Get difficulty time limit
	max_reaction_time = GameSettings.get_karate_time_limit()
	print("Karate game starting with difficulty: " + GameSettings.difficulty)
	print("Time limit: " + str(max_reaction_time) + " seconds")
	
	# Calculate screen center using adjustable percentages
	var viewport_size = get_viewport_rect().size
	screen_center = Vector2(viewport_size.x * center_x_percent, viewport_size.y * center_y_percent)
	
	# Initialize UI
	score_label.text = "Score: 0"
	if combo_label:
		combo_label.text = ""
	timer_label.text = "Time: 30"  # Show game countdown timer
	
	# Initialize Gesture Receiver
	var receiver_script = load("res://KarateGestureReceiver.gd") # Make sure path matches where you save it
	if receiver_script:
		gesture_receiver = receiver_script.new()
		add_child(gesture_receiver)
		# Connect the signal from the receiver to a new function in this script
		gesture_receiver.move_received.connect(_on_phone_input_received)
		print("Karate Gesture Receiver connected!")
	
	# Create feedback label for showing BLOCKED, PUNCH CONNECTED, etc.
	_create_feedback_label()
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	# Create countdown label
	_create_countdown_label()
	
	# Start the first attack after countdown finishes
	waiting_for_next_attack = false

func _process(delta):
	# Handle countdown at start
	if countdown_active:
		countdown_time -= delta
		
		if countdown_time > 1.0:
			# Show 3, 2, 1
			var count_num = int(ceil(countdown_time - 1.0))
			if countdown_label:
				countdown_label.text = str(count_num)
		elif countdown_time > 0:
			# Show GO!
			if countdown_label:
				countdown_label.text = "GO!"
		else:
			# Countdown finished, start game
			countdown_active = false
			if countdown_label:
				countdown_label.queue_free()
				countdown_label = null
			# Start first attack
			waiting_for_next_attack = true
			wait_timer = 0.0
		return  # Don't process game logic during countdown
	
	# Don't process if paused
	if is_paused:
		return
	
	# Update game countdown timer
	game_time_remaining -= delta
	timer_label.text = "Time: %d" % int(ceil(game_time_remaining))
	
	# Check if game time is up
	if game_time_remaining <= 0:
		_game_over()
		return
	
	# Wait between attacks
	if waiting_for_next_attack:
		wait_timer += delta
		if wait_timer >= time_between_attacks:
			_spawn_random_attack()
			waiting_for_next_attack = false
			wait_timer = 0.0
	
	# Handle active attack
	if is_attack_active:
		attack_elapsed += delta
		
		# Animate limb moving toward center (but NOT punch prompts)
		if current_attack_node and current_attack_node.has_meta("is_limb"):
			var progress = attack_elapsed / max_reaction_time
			var start_pos = current_attack_node.get_meta("start_pos")
			current_attack_node.position = start_pos.lerp(screen_center, progress)
		
		# Check if time ran out
		if attack_elapsed >= max_reaction_time:
			_miss_attack()

func _input(event):
	# Handle SPACEBAR for pause (only during active gameplay, not countdown)
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE and not countdown_active:
		if not is_paused:
			_pause_game()
		return
	
	# Don't process game input if paused or during countdown
	if is_paused or countdown_active:
		return
	
	if not is_attack_active or current_attack == null:
		return
	
	# Keyboard input for testing (temporary until smartphone control is added)
	if event is InputEventKey and event.pressed:
		var move = ""
		
		# Map Keys to Moves
		if event.keycode == KEY_Q or event.keycode == KEY_W:
			move = "upper_left"
		elif event.keycode == KEY_E or event.keycode == KEY_R:
			move = "upper_right"
		elif event.keycode == KEY_A or event.keycode == KEY_S:
			move = "lower_left"
		elif event.keycode == KEY_D or event.keycode == KEY_F:
			move = "lower_right"
		elif event.keycode == KEY_H:
			move = "counter_left"
		elif event.keycode == KEY_K:
			move = "counter_right"
		
		# Process it if a valid key was pressed
		if move != "":
			_process_attempt(move)


func _spawn_random_attack():
	# Pick a random attack type (70% limb attacks, 30% counter punches)
	var rand_val = randf()
	var attack_types_limbs = [
		AttackType.RIGHT_ARM_PUNCH,
		AttackType.LEFT_ARM_PUNCH,
		AttackType.RIGHT_LEG_KICK,
		AttackType.LEFT_LEG_KICK
	]
	var attack_types_counter = [
		AttackType.COUNTER_PUNCH_LEFT,
		AttackType.COUNTER_PUNCH_RIGHT
	]
	
	if rand_val < 0.7:  # 70% chance of limb attack
		current_attack = attack_types_limbs[randi() % attack_types_limbs.size()]
	else:  # 30% chance of counter punch
		current_attack = attack_types_counter[randi() % attack_types_counter.size()]
	
	is_attack_active = true
	attack_elapsed = 0.0
	attack_start_time = Time.get_ticks_msec() / 1000.0
	
	# Show the attack visual
	_display_attack(current_attack)

func _display_attack(attack_type: AttackType):
	# Clear any existing attack visuals
	for child in attack_container.get_children():
		child.queue_free()
	
	# Determine what to display and where
	match attack_type:
		AttackType.RIGHT_ARM_PUNCH:
			_create_limb_sprite(right_fist_texture, upper_left_marker.position, right_arm_size, right_arm_rotation)
		
		AttackType.LEFT_ARM_PUNCH:
			_create_limb_sprite(left_fist_texture, upper_right_marker.position, left_arm_size, left_arm_rotation)
		
		AttackType.RIGHT_LEG_KICK:
			_create_limb_sprite(right_leg_texture, lower_left_marker.position, right_leg_size, right_leg_rotation)
		
		AttackType.LEFT_LEG_KICK:
			_create_limb_sprite(left_leg_texture, lower_right_marker.position, left_leg_size, left_leg_rotation)
		
		AttackType.COUNTER_PUNCH_LEFT:
			# Appear on left side of screen using adjustable position
			var viewport_size = get_viewport_rect().size
			var left_punch_pos = Vector2(punch_left_x, viewport_size.y * punch_y_percent)
			_create_punch_prompt("PUNCH LEFT", left_punch_pos, punch_left_size)
		
		AttackType.COUNTER_PUNCH_RIGHT:
			# Appear on right side of screen using adjustable position
			var viewport_size = get_viewport_rect().size
			var right_punch_pos = Vector2(viewport_size.x - punch_right_x_offset, viewport_size.y * punch_y_percent)
			_create_punch_prompt("PUNCH RIGHT", right_punch_pos, punch_right_size)

func _create_limb_sprite(texture: Texture2D, start_position: Vector2, size: float, rotation: float):
	var sprite = TextureRect.new()
	sprite.texture = texture
	sprite.position = start_position
	sprite.set_meta("start_pos", start_position)
	sprite.set_meta("is_limb", true)  # Mark as limb so it animates
	
	# Use the specified size
	sprite.custom_minimum_size = Vector2(size, size)
	sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	
	# Apply the specified rotation
	sprite.rotation_degrees = rotation
	
	# Adjust pivot point to center for better rotation
	sprite.pivot_offset = Vector2(size / 2, size / 2)
	
	attack_container.add_child(sprite)
	current_attack_node = sprite

func _create_punch_prompt(text: String, start_position: Vector2, size: float):
	# Create a container for the green circle and text
	var panel = Panel.new()
	panel.position = start_position
	panel.custom_minimum_size = Vector2(size, size)
	
	# Style as green circle (we'll use a ColorRect for simplicity)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0.8, 0, 0.7)  # Green with transparency
	style.corner_radius_top_left = int(size / 2)
	style.corner_radius_top_right = int(size / 2)
	style.corner_radius_bottom_left = int(size / 2)
	style.corner_radius_bottom_right = int(size / 2)
	panel.add_theme_stylebox_override("panel", style)
	
	# Add text label
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(size / 6))  # Font size scales with circle size
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(size, size)
	
	panel.add_child(label)
	attack_container.add_child(panel)
	current_attack_node = panel
	panel.set_meta("start_pos", start_position)

func _successful_block():
	# Calculate points based on reaction time
	var reaction_time = attack_elapsed
	var base_points = 0
	
	# Points based on speed (scaled to max_reaction_time)
	var speed_ratio = reaction_time / max_reaction_time
	
	if speed_ratio < 0.3:
		base_points = 100  # Lightning fast! (blocked in first 30%)
	elif speed_ratio < 0.5:
		base_points = 80   # Very fast (blocked in first 50%)
	elif speed_ratio < 0.7:
		base_points = 60   # Fast (blocked in first 70%)
	elif speed_ratio < 0.9:
		base_points = 40   # Good (blocked in first 90%)
	else:
		base_points = 20   # Just made it
	
	# Combo bonus
	combo += 1
	var combo_multiplier = 1.0 + (combo * 0.1)  # +10% per combo
	var final_points = int(base_points * combo_multiplier)
	
	score += final_points
	score_label.text = "Score: %d (+%d)" % [score, final_points]
	if combo_label:
		combo_label.text = "Combo: x%d" % combo
	
	# Determine if it was a block or punch
	var is_punch = (current_attack == AttackType.COUNTER_PUNCH_LEFT or current_attack == AttackType.COUNTER_PUNCH_RIGHT)
	
	if is_punch:
		total_punches += 1
		_show_feedback("PUNCH CONNECTED!", Color.GREEN)
		_play_audio("punch_connected")
	else:
		total_blocks += 1
		_show_feedback("BLOCKED!", Color.CYAN)
		_play_audio("blocked")
	
	_clear_attack()
	_prepare_next_attack()

func _miss_attack():
	# Reset combo on miss
	combo = 0
	total_misses += 1
	
	# Determine if it was a missed block or punch
	var is_punch = (current_attack == AttackType.COUNTER_PUNCH_LEFT or current_attack == AttackType.COUNTER_PUNCH_RIGHT)
	
	if is_punch:
		_show_feedback("MISSED PUNCH!", Color.RED)
		_play_audio("missed_punch")
	else:
		_show_feedback("MISSED BLOCK!", Color.ORANGE_RED)
		_play_audio("missed_block")
	
	if combo_label:
		combo_label.text = "MISS! Combo broken"
	score_label.text = "Score: %d" % score
	
	_clear_attack()
	_prepare_next_attack()

func _clear_attack():
	is_attack_active = false
	current_attack = null
	current_attack_node = null
	
	# Clear attack visuals
	for child in attack_container.get_children():
		child.queue_free()

func _prepare_next_attack():
	waiting_for_next_attack = true
	wait_timer = 0.0
	
# New function to handle phone inputs
func _on_phone_input_received(move_type: String):
	if is_paused or countdown_active or not is_attack_active:
		return
		
	# Pass the move string to the logic handler
	_process_attempt(move_type)

# This replaces the logic that was inside _input
func _process_attempt(input_move: String):
	if current_attack == null:
		return

	var blocked = false
	var wrong_input = false
	
	# Match the input against the current attack requirement
	match current_attack:
		AttackType.RIGHT_ARM_PUNCH:  # Needs "upper_left"
			if input_move == "upper_left": blocked = true
			else: wrong_input = true
			
		AttackType.LEFT_ARM_PUNCH:   # Needs "upper_right"
			if input_move == "upper_right": blocked = true
			else: wrong_input = true
			
		AttackType.RIGHT_LEG_KICK:   # Needs "lower_left"
			if input_move == "lower_left": blocked = true
			else: wrong_input = true
			
		AttackType.LEFT_LEG_KICK:    # Needs "lower_right"
			if input_move == "lower_right": blocked = true
			else: wrong_input = true
			
		AttackType.COUNTER_PUNCH_LEFT: # Needs "counter_left"
			if input_move == "counter_left": blocked = true
			else: wrong_input = true
			
		AttackType.COUNTER_PUNCH_RIGHT: # Needs "counter_right"
			if input_move == "counter_right": blocked = true
			else: wrong_input = true

	# Apply results
	if blocked:
		_successful_block()
	elif wrong_input:
		_miss_attack()

func _game_over():
	# Stop the game
	set_process(false)
	is_attack_active = false
	
	# Clear any active attacks
	for child in attack_container.get_children():
		child.queue_free()
	
	# Check for new high score
	var high_score = 0
	if FileAccess.file_exists("user://karate_high_score.save"):
		var file = FileAccess.open("user://karate_high_score.save", FileAccess.READ)
		high_score = file.get_32()
		file.close()
	
	var is_new_high_score = score > high_score
	
	# Save new high score if achieved
	if is_new_high_score:
		var file = FileAccess.open("user://karate_high_score.save", FileAccess.WRITE)
		file.store_32(score)
		file.close()
	
	# Create game over screen
	_create_game_over_screen(is_new_high_score, high_score)

func _create_countdown_label():
	# Create a large centered label for countdown
	countdown_label = Label.new()
	countdown_label.text = "3"
	countdown_label.add_theme_font_size_override("font_size", 120)
	countdown_label.add_theme_color_override("font_color", Color.YELLOW)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.anchor_left = 0.0
	countdown_label.anchor_top = 0.0
	countdown_label.anchor_right = 1.0
	countdown_label.anchor_bottom = 1.0
	add_child(countdown_label)

func _pause_game():
	is_paused = true
	_create_pause_menu()

func _create_pause_menu():
	# Create semi-transparent overlay
	pause_menu = Panel.new()
	pause_menu.anchor_left = 0.0
	pause_menu.anchor_top = 0.0
	pause_menu.anchor_right = 1.0
	pause_menu.anchor_bottom = 1.0
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)  # Dark semi-transparent
	pause_menu.add_theme_stylebox_override("panel", style)
	
	# Create vertical box for buttons
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.4
	vbox.anchor_top = 0.3
	vbox.anchor_right = 0.6
	vbox.anchor_bottom = 0.7
	vbox.add_theme_constant_override("separation", 20)
	
	# Paused label
	var paused_label = Label.new()
	paused_label.text = "PAUSED"
	paused_label.add_theme_font_size_override("font_size", 90)  # Increased from 48
	paused_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(paused_label)
	
	# Resume button
	var resume_btn = Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(300, 80)  # Made bigger
	resume_btn.add_theme_font_size_override("font_size", 80)  # Added font size
	resume_btn.pressed.connect(_resume_game)
	vbox.add_child(resume_btn)
	
	# Restart button
	var restart_btn = Button.new()
	restart_btn.text = "Restart Game"
	restart_btn.custom_minimum_size = Vector2(300, 90)  # Made bigger
	restart_btn.add_theme_font_size_override("font_size", 80)  # Added font size
	restart_btn.pressed.connect(_restart_game)
	vbox.add_child(restart_btn)
	
	# Quit button
	var quit_btn = Button.new()
	quit_btn.text = "Quit to Menu"
	quit_btn.custom_minimum_size = Vector2(300, 90)  # Made bigger
	quit_btn.add_theme_font_size_override("font_size", 80)  # Added font size
	quit_btn.pressed.connect(_quit_to_menu)
	vbox.add_child(quit_btn)
	
	pause_menu.add_child(vbox)
	add_child(pause_menu)

func _resume_game():
	is_paused = false
	if pause_menu:
		pause_menu.queue_free()
		pause_menu = null

func _restart_game():
	get_tree().reload_current_scene()

func _quit_to_menu():
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

func _create_feedback_label():
	# Create a large centered label for feedback (BLOCKED, PUNCH CONNECTED, etc.)
	feedback_label = Label.new()
	feedback_label.text = ""
	feedback_label.add_theme_font_size_override("font_size", 80)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_label.anchor_left = 0.0
	feedback_label.anchor_top = 0.3
	feedback_label.anchor_right = 1.0
	feedback_label.anchor_bottom = 0.5
	feedback_label.modulate.a = 0.0  # Start invisible
	add_child(feedback_label)

func _show_feedback(text: String, color: Color):
	if not feedback_label:
		return
	
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", color)
	feedback_label.modulate.a = 1.0
	
	# Fade out the feedback after a short time
	var tween = create_tween()
	tween.tween_property(feedback_label, "modulate:a", 0.0, 0.5).set_delay(0.3)

func _play_audio(audio_type: String):
	if not audio_player:
		return
	
	# Select the appropriate audio stream
	match audio_type:
		"blocked":
			audio_player.stream = blocked_audio
		"punch_connected":
			audio_player.stream = punch_connected_audio
		"missed_block":
			audio_player.stream = missed_block_audio
		"missed_punch":
			audio_player.stream = missed_punch_audio
	
	# Play the sound
	audio_player.play()

func _create_game_over_screen(is_new_high_score: bool, previous_high_score: int):
	# Create semi-transparent overlay
	var game_over_panel = Panel.new()
	game_over_panel.anchor_left = 0.0
	game_over_panel.anchor_top = 0.0
	game_over_panel.anchor_right = 1.0
	game_over_panel.anchor_bottom = 1.0
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85) # Slightly darker background for better contrast
	game_over_panel.add_theme_stylebox_override("panel", style)
	
	# Create vertical box for content
	var vbox = VBoxContainer.new()
	# Adjusted margins to keep content centered but give it more room
	vbox.anchor_left = 0.15
	vbox.anchor_top = 0.1
	vbox.anchor_right = 0.85
	vbox.anchor_bottom = 0.9
	vbox.add_theme_constant_override("separation", 25) # Increased separation
	
	# Game Over title
	var title_label = Label.new()
	title_label.text = "GAME OVER!"
	title_label.add_theme_font_size_override("font_size", 140) 
	title_label.add_theme_color_override("font_color", Color.RED)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# New High Score notification (if applicable)
	if is_new_high_score:
		var new_high_score_label = Label.new()
		new_high_score_label.text = "★ NEW HIGH SCORE! ★"
		new_high_score_label.add_theme_font_size_override("font_size", 80)
		new_high_score_label.add_theme_color_override("font_color", Color.GOLD)
		new_high_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(new_high_score_label)
	
	# Final Score
	var score_label_final = Label.new()
	score_label_final.text = "Final Score: %d" % score
	score_label_final.add_theme_font_size_override("font_size", 80)
	score_label_final.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_label_final)
	
	# High Score (show previous if not beaten)
	if not is_new_high_score and previous_high_score > 0:
		var high_score_label = Label.new()
		high_score_label.text = "High Score: %d" % previous_high_score
		high_score_label.add_theme_font_size_override("font_size", 75)
		high_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(high_score_label)
	
	# Statistics Header
	var stats_label = Label.new()
	stats_label.text = "━━━━━━ STATISTICS ━━━━━━"
	stats_label.add_theme_font_size_override("font_size", 75)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_label)
	
	# Stats Lines
	var blocks_label = Label.new()
	blocks_label.text = "Successful Blocks: %d" % total_blocks
	blocks_label.add_theme_font_size_override("font_size", 75)
	blocks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(blocks_label)
	
	var punches_label = Label.new()
	punches_label.text = "Successful Punches: %d" % total_punches
	punches_label.add_theme_font_size_override("font_size", 75)
	punches_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(punches_label)
	
	var misses_label = Label.new()
	misses_label.text = "Missed Attacks: %d" % total_misses
	misses_label.add_theme_font_size_override("font_size", 75)
	misses_label.add_theme_color_override("font_color", Color.ORANGE_RED)
	misses_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(misses_label)
	
	var total_label = Label.new()
	total_label.text = "Total Actions: %d" % (total_blocks + total_punches + total_misses)
	total_label.add_theme_font_size_override("font_size", 75)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(total_label)
	
	# Accuracy percentage
	var total_actions = total_blocks + total_punches + total_misses
	var accuracy = 0.0
	if total_actions > 0:
		accuracy = float(total_blocks + total_punches) / float(total_actions) * 100.0
	
	var accuracy_label = Label.new()
	accuracy_label.text = "Accuracy: %.1f%%" % accuracy
	accuracy_label.add_theme_font_size_override("font_size", 75)
	accuracy_label.add_theme_color_override("font_color", Color.CYAN)
	accuracy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(accuracy_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40) # Increased space before buttons
	vbox.add_child(spacer)
	
	# Play Again button
	var play_again_btn = Button.new()
	play_again_btn.text = "Play Again"
	play_again_btn.custom_minimum_size = Vector2(600, 160)
	play_again_btn.add_theme_font_size_override("font_size", 90)
	play_again_btn.pressed.connect(_restart_game)
	
	# Center the button in VBox
	var btn_center_container = CenterContainer.new()
	btn_center_container.add_child(play_again_btn)
	vbox.add_child(btn_center_container)
	
	# Quit to Menu button
	var quit_btn = Button.new()
	quit_btn.text = "Quit to Menu"
	quit_btn.custom_minimum_size = Vector2(600, 160)
	quit_btn.add_theme_font_size_override("font_size", 90)
	quit_btn.pressed.connect(_quit_to_menu)
	
	# Center the button in VBox
	var quit_center_container = CenterContainer.new()
	quit_center_container.add_child(quit_btn)
	vbox.add_child(quit_center_container)
	
	game_over_panel.add_child(vbox)
	add_child(game_over_panel)

# Arrow.gd
# Individual arrow that moves from center to target OR convergence movement
# Used for single notes, chord notes, and convergence notes
extends TextureRect

# Arrow properties
var target_position: Vector2
var start_position: Vector2
var center_position: Vector2
var speed: float = 400.0
var direction: String = ""
var active: bool = false
var overshooting: bool = false
var overshoot_distance: float = 80.0  # CHANGED from 30 to 80

# Movement mode
var is_convergence: bool = false

# Timing
var arrow_start_time: float = 0.0
var travel_time: float = 0.0
var target_reach_time: float = 0.0

# Pause handling
var pause_start_time: float = 0.0
var total_pause_time: float = 0.0
var was_paused: bool = false

# Preload arrow textures
var arrow_textures = {
	"Up": preload("res://assets/visuals/up_arrow.png"),
	"Down": preload("res://assets/visuals/down_arrow.png"),
	"Left": preload("res://assets/visuals/left_arrow.png"),
	"Right": preload("res://assets/visuals/right_arrow.png")
}

func _ready():
	pass

func setup(dir: String, target_pos: Vector2, center_pos: Vector2, arrow_speed: float):
	"""Initialize a regular arrow (from center to directional arrow)"""
	direction = dir
	target_position = target_pos
	center_position = center_pos
	start_position = center_pos
	speed = arrow_speed
	is_convergence = false
	
	# Set the texture based on direction
	if direction in arrow_textures:
		texture = arrow_textures[direction]
	
	# Position at center
	global_position = center_position
	
	# Calculate timing
	arrow_start_time = Time.get_ticks_msec() / 1000.0
	travel_time = (target_position - center_position).length() / speed
	target_reach_time = arrow_start_time + travel_time
	
	active = true
	overshooting = false

func setup_convergence(dir: String, corner_pos: Vector2, spawn_pos: Vector2, arrow_speed: float):
	"""Initialize a convergence arrow (from directional arrow to corner)"""
	direction = dir
	target_position = corner_pos
	start_position = spawn_pos
	speed = arrow_speed
	is_convergence = true
	
	# Set the texture based on direction (direction arrow is facing)
	if direction in arrow_textures:
		texture = arrow_textures[direction]
	
	# Position at spawn location
	global_position = spawn_pos
	
	# Calculate timing
	arrow_start_time = Time.get_ticks_msec() / 1000.0
	travel_time = (target_position - start_position).length() / speed
	target_reach_time = arrow_start_time + travel_time
	
	active = true
	overshooting = false
	
	print("Convergence arrow setup: dir=", dir, " from=", spawn_pos, " to=", corner_pos, " distance=", (target_position - start_position).length())

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
			
			arrow_start_time += pause_duration
			target_reach_time += pause_duration
			
			was_paused = false
	
	if not active:
		return
	
	var to_target = target_position - global_position
	var distance_to_target = to_target.length()
	
	if not overshooting:
		# Moving toward target
		if distance_to_target > speed * delta:
			global_position += to_target.normalized() * speed * delta
		else:
			global_position = target_position
			overshooting = true
	else:
		# BUG FIX: Continue moving past target during overshoot
		var dir = (target_position - start_position).normalized()
		var overshoot_target = target_position + dir * overshoot_distance
		var to_overshoot = overshoot_target - global_position
		
		# Keep moving toward overshoot point
		if to_overshoot.length() > speed * delta:
			global_position += to_overshoot.normalized() * speed * delta
		else:
			# Reached overshoot limit - arrow will be cleaned up by Center.gd
			# based on Good window timing
			global_position = overshoot_target

func is_active() -> bool:
	return active

func get_target_reach_time() -> float:
	return target_reach_time

func get_direction() -> String:
	return direction

func deactivate():
	"""Deactivate this arrow"""
	active = false
	queue_free()

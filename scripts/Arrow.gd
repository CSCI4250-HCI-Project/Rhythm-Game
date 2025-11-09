# Arrow.gd
# Individual arrow that moves from center to target
# Used for both single notes and chord notes

extends TextureRect

# Arrow properties
var target_position: Vector2
var center_position: Vector2
var speed: float = 400.0
var direction: String = ""
var active: bool = false
var overshooting: bool = false
var overshoot_distance: float = 30.0

# Timing
var arrow_start_time: float = 0.0
var travel_time: float = 0.0
var target_reach_time: float = 0.0

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
    """Initialize the arrow with its properties"""
    direction = dir
    target_position = target_pos
    center_position = center_pos
    speed = arrow_speed
    
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

func _process(delta):
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
            target_reach_time = Time.get_ticks_msec() / 1000.0
    else:
        # Overshooting past target
        var dir = (target_position - center_position).normalized()
        var overshoot_target = target_position + dir * overshoot_distance
        var to_overshoot = overshoot_target - global_position
        
        if to_overshoot.length() > speed * delta:
            global_position += to_overshoot.normalized() * speed * delta
        else:
            global_position = overshoot_target
            # Arrow has completed its journey
            active = false

func is_active() -> bool:
    return active

func get_target_reach_time() -> float:
    return target_reach_time

func get_direction() -> String:
    return direction

func deactivate():
    """Deactivate this arrow"""
    active = false
    queue_free()  # Remove from scene

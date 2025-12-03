extends Node

# SIMPLIFIED Touch Input Handler for Rhythm Game
# - Detects swipes ANYWHERE on screen (no center restriction)
# - Fires input immediately when finger lifts (swipe ends)
# - Properly handles multi-touch for chords
# - Includes on-screen debug display

# Touch tracking - simplified!
var active_swipes = {}  # touch_id -> {start_pos, start_time}
var completed_swipes = []  # Swipes that just finished in this frame

# Swipe detection parameters
const MIN_SWIPE_DISTANCE = 100.0  # Minimum distance to register as a swipe
const SWIPE_DIRECTION_THRESHOLD = 0.3  # Lower = more forgiving (accepts more diagonal swipes)
const MULTI_TOUCH_WINDOW_MS = 50  # Short window to detect simultaneous releases for chords

# Debug display
var debug_label: Label
var last_swipe_time = 0

func _ready():
    var screen_size = get_viewport().get_visible_rect().size
    print("=== SIMPLIFIED TouchInput Ready ===")
    print("Screen size: ", screen_size)
    print("Swipes detected ANYWHERE on screen")
    print("Min swipe distance: ", MIN_SWIPE_DISTANCE, "px")
    print("===================================")
    
    # Create debug label
    setup_debug_label()

func setup_debug_label():
    # Create a label to show debug info on screen
    debug_label = Label.new()
    debug_label.position = Vector2(50, 50)
    debug_label.add_theme_font_size_override("font_size", 40)  # Large font for phone
    debug_label.modulate = Color.GREEN
    debug_label.z_index = 1000  # Draw on top of everything
    add_child(debug_label)
    update_debug_text("Ready to swipe!")

func update_debug_text(text: String):
    if debug_label:
        debug_label.text = text

func _input(event):
    if event is InputEventScreenTouch:
        handle_touch(event)
    elif event is InputEventScreenDrag:
        handle_drag(event)

func handle_touch(event: InputEventScreenTouch):
    var touch_id = event.index
    
    if event.pressed:
        # Touch started - record it
        active_swipes[touch_id] = {
            "start_pos": event.position,
            "start_time": Time.get_ticks_msec(),
            "current_pos": event.position
        }
        update_debug_text("Touch " + str(touch_id) + " started\nActive: " + str(active_swipes.size()))
        print("Touch ", touch_id, " started at ", event.position)
    else:
        # Touch ended - CHECK IF IT'S A VALID SWIPE
        if touch_id in active_swipes:
            var swipe_data = active_swipes[touch_id]
            var swipe_vector = swipe_data.current_pos - swipe_data.start_pos
            var swipe_distance = swipe_vector.length()
            
            print("Touch ", touch_id, " ended. Distance: ", int(swipe_distance), "px")
            
            if swipe_distance >= MIN_SWIPE_DISTANCE:
                # Valid swipe! Determine direction
                var direction = get_swipe_direction(swipe_vector)
                if direction != "":
                    completed_swipes.append(direction)
                    print("✓ SWIPE DETECTED: ", direction)
                    update_debug_text("Swipe: " + direction + "\nTotal: " + str(completed_swipes.size()))
            else:
                print("✗ Swipe too short (", int(swipe_distance), "px < ", MIN_SWIPE_DISTANCE, "px)")
                update_debug_text("Swipe too short!")
            
            # Remove from active swipes
            active_swipes.erase(touch_id)
            
            # Process the swipes (with short delay for multi-touch detection)
            call_deferred("process_completed_swipes")

func handle_drag(event: InputEventScreenDrag):
    var touch_id = event.index
    
    if touch_id in active_swipes:
        # Update current position
        active_swipes[touch_id].current_pos = event.position

func get_swipe_direction(swipe_vector: Vector2) -> String:
    var normalized = swipe_vector.normalized()
    var abs_x = abs(normalized.x)
    var abs_y = abs(normalized.y)
    
    # Determine primary direction
    if abs_x > abs_y:
        # More horizontal than vertical
        if abs_x >= SWIPE_DIRECTION_THRESHOLD:
            return "Right" if normalized.x > 0 else "Left"
    else:
        # More vertical than horizontal
        if abs_y >= SWIPE_DIRECTION_THRESHOLD:
            return "Down" if normalized.y > 0 else "Up"
    
    return ""

func process_completed_swipes():
    if completed_swipes.is_empty():
        return
    
    var current_time = Time.get_ticks_msec()
    
    # If there are still active touches OR we just processed swipes recently, wait a bit
    if not active_swipes.is_empty() and (current_time - last_swipe_time) < MULTI_TOUCH_WINDOW_MS:
        # Wait for potential additional swipes
        return
    
    # Fire all completed swipes!
    if completed_swipes.size() > 1:
        print("🎵 CHORD: ", completed_swipes)
        update_debug_text("CHORD!\n" + str(completed_swipes))
    else:
        print("🎵 Single: ", completed_swipes[0])
        update_debug_text("Hit: " + completed_swipes[0])
    
    # Remove duplicates and fire inputs
    var unique_directions = []
    for direction in completed_swipes:
        if direction not in unique_directions:
            unique_directions.append(direction)
    
    for direction in unique_directions:
        fire_input(direction)
    
    # Clear completed swipes
    completed_swipes.clear()
    last_swipe_time = current_time

func fire_input(direction: String):
    var action = ""
    match direction:
        "Up":
            action = "ui_up"
        "Down":
            action = "ui_down"
        "Left":
            action = "ui_left"
        "Right":
            action = "ui_right"
    
    if action != "":
        # Create and inject input event
        var key_event = InputEventAction.new()
        key_event.action = action
        key_event.pressed = true
        Input.parse_input_event(key_event)
        print("  → Input fired: ", action)

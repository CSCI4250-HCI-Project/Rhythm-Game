# GestureReceiver.gd
# Receives gesture commands from Python script via UDP and converts them to game input
# Attach this to a Node in your ArrowGame scene

extends Node

# UDP Configuration
const PORT = 9999
var udp_server = PacketPeerUDP.new()
var is_listening = false

# Input mode
enum InputMode { KEYBOARD, GESTURE, BOTH }
var current_input_mode = InputMode.BOTH

# Gesture to action mapping
var gesture_to_action = {
    "UP": "ui_up",
    "DOWN": "ui_down",
    "LEFT": "ui_left",
    "RIGHT": "ui_right",
    "DOUBLE_UP": "double_up",
    "DOUBLE_DOWN": "double_down",
    "DOUBLE_LEFT": "double_left",
    "DOUBLE_RIGHT": "double_right",
    "LEFT_RIGHT": "left_right",
    "UP_DOWN": "up_down"
}

# Signal for gesture detection (optional - for visual feedback)
signal gesture_detected(gesture_name)

# Debug tracking
var gestures_received = 0
var gestures_processed = 0

func _ready():
    _start_listening()
    print("GestureReceiver: Ready to receive gestures on port ", PORT)
    print("GestureReceiver: Input mode = ", InputMode.keys()[current_input_mode])

func _start_listening():
    var result = udp_server.bind(PORT)
    if result == OK:
        is_listening = true
        print("GestureReceiver: Successfully listening on port ", PORT)
    else:
        is_listening = false
        print("GestureReceiver: Failed to bind to port ", PORT)
        push_error("Failed to start UDP server on port %d" % PORT)

func _process(_delta):
    if not is_listening:
        return
    
    # Check for incoming packets
    while udp_server.get_available_packet_count() > 0:
        var packet = udp_server.get_packet()
        var gesture_command = packet.get_string_from_utf8()
        gestures_received += 1
        _handle_gesture(gesture_command)

func _handle_gesture(gesture_command: String):
    """Process received gesture and trigger corresponding game action."""
    gesture_command = gesture_command.strip_edges()
    
    if gesture_command.is_empty():
        return
    
    print("GestureReceiver: [#%d] Received gesture - %s" % [gestures_received, gesture_command])
    
    # Emit signal for visual feedback (optional)
    emit_signal("gesture_detected", gesture_command)
    
    # Handle double arrow gestures
    if gesture_command in ["DOUBLE_UP", "DOUBLE_DOWN", "DOUBLE_LEFT", "DOUBLE_RIGHT"]:
        _handle_double_arrow(gesture_command)
        gestures_processed += 1
    # Handle combination gestures (two different directions)
    elif gesture_command == "LEFT_RIGHT":
        _trigger_action("ui_left")
        _trigger_action("ui_right")
        gestures_processed += 1
    elif gesture_command == "UP_DOWN":
        _trigger_action("ui_up")
        _trigger_action("ui_down")
        gestures_processed += 1
    # Handle single direction gestures
    elif gesture_command in gesture_to_action:
        var action = gesture_to_action[gesture_command]
        _trigger_action(action)
        gestures_processed += 1
        print("  → Triggered action: %s" % action)
    else:
        print("  → Unknown gesture command: %s" % gesture_command)

func _handle_double_arrow(gesture_command: String):
    """Handle double arrow of the same direction."""
    var base_action = ""
    
    match gesture_command:
        "DOUBLE_UP":
            base_action = "ui_up"
        "DOUBLE_DOWN":
            base_action = "ui_down"
        "DOUBLE_LEFT":
            base_action = "ui_left"
        "DOUBLE_RIGHT":
            base_action = "ui_right"
    
    if base_action:
        # Trigger the action (for chord notes)
        _trigger_action(base_action)
        print("  → Triggered double arrow: %s" % base_action)

func _trigger_action(action: String):
    """Simulate an input action being pressed and released."""
    # Press event
    var press_event = InputEventAction.new()
    press_event.action = action
    press_event.pressed = true
    Input.parse_input_event(press_event)
    
    # Immediate release event (rhythm games need quick tap)
    var release_event = InputEventAction.new()
    release_event.action = action
    release_event.pressed = false
    Input.parse_input_event(release_event)
    
    print("  → Input action fired: %s (press + release)" % action)

func set_input_mode(mode: InputMode):
    """Change input mode (keyboard, gesture, or both)."""
    current_input_mode = mode
    match mode:
        InputMode.KEYBOARD:
            print("GestureReceiver: Input mode set to KEYBOARD only")
        InputMode.GESTURE:
            print("GestureReceiver: Input mode set to GESTURE only")
        InputMode.BOTH:
            print("GestureReceiver: Input mode set to BOTH (keyboard and gesture)")

func get_stats() -> Dictionary:
    """Get statistics about gesture processing."""
    return {
        "received": gestures_received,
        "processed": gestures_processed,
        "is_listening": is_listening
    }

func _exit_tree():
    if is_listening:
        udp_server.close()
        print("GestureReceiver: UDP server closed")
        print("GestureReceiver: Total gestures - Received: %d, Processed: %d" % [gestures_received, gestures_processed])

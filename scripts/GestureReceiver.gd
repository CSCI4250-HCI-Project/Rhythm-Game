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

func _ready():
    _start_listening()
    print("GestureReceiver: Ready to receive gestures on port ", PORT)

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
    if udp_server.get_available_packet_count() > 0:
        var packet = udp_server.get_packet()
        var gesture_command = packet.get_string_from_utf8()
        _handle_gesture(gesture_command)

func _handle_gesture(gesture_command: String):
    """Process received gesture and trigger corresponding game action."""
    gesture_command = gesture_command.strip_edges()
    
    if gesture_command.is_empty():
        return
    
    print("GestureReceiver: Received gesture - ", gesture_command)
    
    # Emit signal for visual feedback (optional)
    emit_signal("gesture_detected", gesture_command)
    
    # Handle double arrow gestures
    if gesture_command in ["DOUBLE_UP", "DOUBLE_DOWN", "DOUBLE_LEFT", "DOUBLE_RIGHT"]:
        _handle_double_arrow(gesture_command)
    # Handle combination gestures (two different directions)
    elif gesture_command == "LEFT_RIGHT":
        _trigger_action("ui_left")
        _trigger_action("ui_right")
    elif gesture_command == "UP_DOWN":
        _trigger_action("ui_up")
        _trigger_action("ui_down")
    # Handle single direction gestures
    elif gesture_command in gesture_to_action:
        var action = gesture_to_action[gesture_command]
        _trigger_action(action)

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
        # Trigger the action twice (for two arrows)
        _trigger_action(base_action)

func _trigger_action(action: String):
    """Simulate an input action being pressed."""
    # Create an InputEventAction
    var event = InputEventAction.new()
    event.action = action
    event.pressed = true
    
    # Parse the event through the input system
    Input.parse_input_event(event)
    
    # Schedule the release after a short delay
    get_tree().create_timer(0.1).timeout.connect(func(): _release_action(action))

func _release_action(action: String):
    """Simulate an input action being released."""
    var event = InputEventAction.new()
    event.action = action
    event.pressed = false
    Input.parse_input_event(event)

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

func _exit_tree():
    if is_listening:
        udp_server.close()
        print("GestureReceiver: UDP server closed")

extends Node

# UDP RECEIVER for PC Game
# Receives swipe commands from phone controller and simulates keyboard input
# Add this as a child node to your main game scene

const LISTEN_PORT = 5005

var udp_socket: PacketPeerUDP
var is_listening = false

func _ready():
    print("=== UDP Receiver Starting ===")
    setup_udp()

func setup_udp():
    udp_socket = PacketPeerUDP.new()
    var result = udp_socket.bind(LISTEN_PORT)
    
    if result == OK:
        is_listening = true
        print("✓ UDP Receiver listening on port ", LISTEN_PORT)
        print("Waiting for phone controller...")
    else:
        print("✗ ERROR: Could not bind to port ", LISTEN_PORT)
        print("Error code: ", result)

func _process(_delta):
    if not is_listening:
        return
    
    # Check for incoming packets
    if udp_socket.get_available_packet_count() > 0:
        var packet = udp_socket.get_packet()
        var message = packet.get_string_from_utf8()
        handle_message(message)

func handle_message(message: String):
    message = message.strip_edges()
    
    if message == "HELLO":
        print("✓ Phone controller connected!")
        return
    
    # Convert direction to input action
    var action = ""
    match message:
        "UP":
            action = "ui_up"
        "DOWN":
            action = "ui_down"
        "LEFT":
            action = "ui_left"
        "RIGHT":
            action = "ui_right"
    
    if action != "":
        print("Phone input received: ", message, " → ", action)
        simulate_key_press(action)

func simulate_key_press(action: String):
    # Create and inject the input event
    var key_event = InputEventAction.new()
    key_event.action = action
    key_event.pressed = true
    Input.parse_input_event(key_event)
    
    # Optional: Also trigger release after a short delay to fully simulate a key press
    # This might help with detection
    await get_tree().create_timer(0.05).timeout
    var release_event = InputEventAction.new()
    release_event.action = action
    release_event.pressed = false
    Input.parse_input_event(release_event)

func _exit_tree():
    if udp_socket:
        udp_socket.close()
        print("UDP Receiver closed")

extends Node
# UDPReceiver.gd (For Rhythm Game)

const LISTEN_PORT = 5005
var udp_socket = PacketPeerUDP.new()
var is_listening = false

func _ready():
	if udp_socket.bind(LISTEN_PORT) == OK:
		is_listening = true
		print("Rhythm Receiver Listening on ", LISTEN_PORT)

func _process(_delta):
	if not is_listening: return
	while udp_socket.get_available_packet_count() > 0:
		var pkt = udp_socket.get_packet()
		var msg = pkt.get_string_from_utf8().strip_edges()
		_handle_message(msg)

func _handle_message(msg: String):
	# The phone sends different codes depending on mode.
	# We only listen to the RHYTHM codes here.
	
	match msg:
		# Standard Arrows
		"UP": _press("ui_up")
		"DOWN": _press("ui_down")
		"LEFT": _press("ui_left")
		"RIGHT": _press("ui_right")
		
		# Convergence Corners (From Rhythm Mode on Phone)
		"TAP_UL": _press("convergence_upper_left")
		"TAP_UR": _press("convergence_upper_right")
		"TAP_DL": _press("convergence_lower_left")
		"TAP_DR": _press("convergence_lower_right")

func _press(action_name: String):
	if InputMap.has_action(action_name):
		var ev = InputEventAction.new()
		ev.action = action_name
		ev.pressed = true
		Input.parse_input_event(ev)
		
		# Short delay then release
		await get_tree().process_frame 
		var rel = InputEventAction.new()
		rel.action = action_name
		rel.pressed = false
		Input.parse_input_event(rel)

func _exit_tree():
	if is_listening: udp_socket.close()

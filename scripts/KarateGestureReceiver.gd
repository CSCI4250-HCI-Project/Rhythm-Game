extends Node

# Signal to send to the main game
signal move_received(move_type)

# UDP Configuration
const PORT = 5005
var udp_server = PacketPeerUDP.new()
var is_listening = false

# --- COMMAND CONSTANTS ---
# These must match EXACTLY what PhoneController.gd sends
const CMD_SWIPE_UP_LEFT    = "SWIPE_UL"
const CMD_SWIPE_UP_RIGHT   = "SWIPE_UR"
const CMD_SWIPE_DOWN_LEFT  = "SWIPE_DL"
const CMD_SWIPE_DOWN_RIGHT = "SWIPE_DR"

# Note: The phone sends "SIDE" commands in Karate Mode
const CMD_TAP_LEFT         = "TAP_LEFT_SIDE"   
const CMD_TAP_RIGHT        = "TAP_RIGHT_SIDE"

func _ready():
	var result = udp_server.bind(PORT)
	if result == OK:
		is_listening = true
		print("KarateReceiver: Listening on port ", PORT)
	else:
		print("KarateReceiver: Failed to bind port ", PORT)

func _process(_delta):
	if not is_listening:
		return
	
	while udp_server.get_available_packet_count() > 0:
		var packet = udp_server.get_packet()
		var command = packet.get_string_from_utf8().strip_edges()
		_handle_command(command)

func _handle_command(command: String):
	# Match the command string to the game signal
	match command:
		CMD_SWIPE_UP_LEFT:
			emit_signal("move_received", "upper_left")
		CMD_SWIPE_UP_RIGHT:
			emit_signal("move_received", "upper_right")
		CMD_SWIPE_DOWN_LEFT:
			emit_signal("move_received", "lower_left")
		CMD_SWIPE_DOWN_RIGHT:
			emit_signal("move_received", "lower_right")
		CMD_TAP_LEFT:
			emit_signal("move_received", "counter_left")
		CMD_TAP_RIGHT:
			emit_signal("move_received", "counter_right")

func _exit_tree():
	if is_listening:
		udp_server.close()

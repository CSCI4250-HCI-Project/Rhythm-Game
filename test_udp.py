"""
Simple Gesture Test Script
Tests UDP communication with Godot by sending test gestures

Press number keys to send test gestures:
1 = UP
2 = DOWN  
3 = LEFT
4 = RIGHT
Q = Quit
"""

import socket
import time

# UDP Configuration
GODOT_IP = "127.0.0.1"
GODOT_PORT = 9999

# Initialize UDP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

print("=" * 60)
print("GESTURE TEST - UDP Communication Test")
print("=" * 60)
print(f"Sending to: {GODOT_IP}:{GODOT_PORT}")
print("\nPress keys to send test gestures:")
print("  1 = UP")
print("  2 = DOWN")
print("  3 = LEFT")
print("  4 = RIGHT")
print("  5 = UP (rapid fire - 5 times)")
print("  Q = Quit")
print("=" * 60)

def send_gesture(gesture):
    """Send gesture to Godot via UDP."""
    try:
        sock.sendto(gesture.encode(), (GODOT_IP, GODOT_PORT))
        print(f"✓ Sent: {gesture}")
        return True
    except Exception as e:
        print(f"✗ Error: {e}")
        return False

# Test with keyboard input
try:
    import msvcrt  # Windows only
    print("\nReady! Press keys to test...")
    
    while True:
        if msvcrt.kbhit():
            key = msvcrt.getch().decode('utf-8').lower()
            
            if key == 'q':
                print("\nQuitting...")
                break
            elif key == '1':
                send_gesture("UP")
            elif key == '2':
                send_gesture("DOWN")
            elif key == '3':
                send_gesture("LEFT")
            elif key == '4':
                send_gesture("RIGHT")
            elif key == '5':
                print("Rapid fire test - sending 5 UP gestures...")
                for i in range(5):
                    send_gesture("UP")
                    time.sleep(0.2)
            
        time.sleep(0.01)

except ImportError:
    # Fallback for non-Windows systems
    print("\nType gesture name and press Enter:")
    print("Options: UP, DOWN, LEFT, RIGHT, QUIT")
    
    while True:
        gesture = input("> ").strip().upper()
        
        if gesture == "QUIT":
            print("Quitting...")
            break
        elif gesture in ["UP", "DOWN", "LEFT", "RIGHT"]:
            send_gesture(gesture)
        else:
            print("Invalid gesture. Use: UP, DOWN, LEFT, RIGHT, or QUIT")

except KeyboardInterrupt:
    print("\nInterrupted by user")

finally:
    sock.close()
    print("Test script stopped.")
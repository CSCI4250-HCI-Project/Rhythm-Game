"""
Rhythm Game - Position-Based Controller
Simply hold your hand in UP/DOWN/LEFT/RIGHT zones to trigger those directions

Much more reliable than swipe detection!

Author: Claude & Greg
For: CSCI 4250 Human Computer Interaction Project
"""

import cv2
import mediapipe as mp
import socket
import time
import numpy as np

# ==================== CONFIGURATION ====================

# UDP Configuration
GODOT_IP = "127.0.0.1"
GODOT_PORT = 9999

# Zone boundaries (normalized 0-1 coordinates)
# Screen is divided into regions
CENTER_ZONE = 0.25  # Center zone radius (no input)

# How long hand must be in zone before triggering (seconds)
ZONE_HOLD_TIME = 0.15  # Quick but deliberate

# Cooldown between inputs (seconds)
INPUT_COOLDOWN = 0.2

# ==================== INITIALIZATION ====================

mp_hands = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils
hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=2,
    min_detection_confidence=0.7,
    min_tracking_confidence=0.7
)

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

# ==================== ZONE DETECTOR ====================

class ZoneDetector:
    """Detects which zone the hand is in."""
    
    def __init__(self, hand_label):
        self.hand_label = hand_label
        self.current_zone = None
        self.zone_enter_time = None
        self.last_input_time = 0
        self.input_count = 0
        
    def update(self, hand_landmarks, frame_time):
        """Check which zone hand is in."""
        palm = hand_landmarks.landmark[0]
        x, y = palm.x, palm.y
        
        # Determine zone based on position
        # Center of screen is (0.5, 0.5)
        dx = x - 0.5
        dy = y - 0.5
        distance_from_center = np.sqrt(dx*dx + dy*dy)
        
        # Determine current zone
        new_zone = None
        
        if distance_from_center < CENTER_ZONE:
            # In center, no input
            new_zone = "CENTER"
        else:
            # Outside center - which direction is dominant?
            if abs(dx) > abs(dy):
                # Horizontal
                new_zone = "RIGHT" if dx > 0 else "LEFT"
            else:
                # Vertical
                new_zone = "DOWN" if dy > 0 else "UP"
        
        # Check if zone changed
        if new_zone != self.current_zone:
            self.current_zone = new_zone
            self.zone_enter_time = frame_time
            return None
        
        # Check if we've been in this zone long enough
        if self.current_zone != "CENTER" and self.zone_enter_time is not None:
            time_in_zone = frame_time - self.zone_enter_time
            
            # Check cooldown
            if frame_time - self.last_input_time < INPUT_COOLDOWN:
                return None
            
            # Held in zone long enough?
            if time_in_zone >= ZONE_HOLD_TIME:
                self.last_input_time = frame_time
                self.zone_enter_time = None  # Reset so we don't trigger again
                self.input_count += 1
                print(f"  [{self.hand_label}] #{self.input_count} ZONE: {self.current_zone} | "
                      f"Position: ({x:.2f}, {y:.2f})")
                return self.current_zone
        
        return None
    
    def get_position_info(self, hand_landmarks):
        """Get current position for visualization."""
        palm = hand_landmarks.landmark[0]
        x, y = palm.x, palm.y
        dx = x - 0.5
        dy = y - 0.5
        distance = np.sqrt(dx*dx + dy*dy)
        return x, y, self.current_zone, distance

# ==================== VISUALIZATION ====================

def draw_zones(frame, width, height):
    """Draw the zone boundaries."""
    center_x = width // 2
    center_y = height // 2
    
    # Draw center "dead zone"
    center_radius = int(CENTER_ZONE * width)
    cv2.circle(frame, (center_x, center_y), center_radius, (100, 100, 100), 2)
    cv2.putText(frame, "CENTER", (center_x - 40, center_y),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (100, 100, 100), 2)
    
    # Draw zone labels
    label_distance = int(CENTER_ZONE * width) + 60
    
    # UP
    cv2.putText(frame, "UP", (center_x - 20, center_y - label_distance),
                cv2.FONT_HERSHEY_SIMPLEX, 1.0, (255, 255, 255), 2)
    
    # DOWN
    cv2.putText(frame, "DOWN", (center_x - 35, center_y + label_distance),
                cv2.FONT_HERSHEY_SIMPLEX, 1.0, (255, 255, 255), 2)
    
    # LEFT
    cv2.putText(frame, "LEFT", (center_x - label_distance - 50, center_y),
                cv2.FONT_HERSHEY_SIMPLEX, 1.0, (255, 255, 255), 2)
    
    # RIGHT
    cv2.putText(frame, "RIGHT", (center_x + label_distance - 50, center_y),
                cv2.FONT_HERSHEY_SIMPLEX, 1.0, (255, 255, 255), 2)
    
    # Draw crosshairs
    cv2.line(frame, (center_x, 0), (center_x, height), (50, 50, 50), 1)
    cv2.line(frame, (0, center_y), (width, center_y), (50, 50, 50), 1)

def draw_hand_info(frame, detector, hand_landmarks, width, height):
    """Show hand position and zone."""
    x_norm, y_norm, zone, distance = detector.get_position_info(hand_landmarks)
    
    px = int(x_norm * width)
    py = int(y_norm * height)
    
    # Color based on zone
    if zone == "CENTER":
        color = (100, 100, 100)
        status = "NEUTRAL"
    elif zone == "UP":
        color = (0, 255, 255)
        status = "UP ZONE"
    elif zone == "DOWN":
        color = (255, 255, 0)
        status = "DOWN ZONE"
    elif zone == "LEFT":
        color = (255, 0, 255)
        status = "LEFT ZONE"
    elif zone == "RIGHT":
        color = (0, 255, 0)
        status = "RIGHT ZONE"
    else:
        color = (255, 255, 255)
        status = "?"
    
    # Draw line from center to hand
    center_x = width // 2
    center_y = height // 2
    cv2.line(frame, (center_x, center_y), (px, py), color, 3)
    
    # Draw circle at hand
    cv2.circle(frame, (px, py), 20, color, -1)
    
    # Show status
    cv2.putText(frame, status, (px + 30, py),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)

def draw_ui(frame, width, height, left_detector, right_detector):
    """Draw UI elements."""
    cv2.putText(frame, "POSITION MODE", (10, 40),
                cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2)
    cv2.putText(frame, "Move hand to zone when arrow reaches target", (10, 80),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
    
    total = left_detector.input_count + right_detector.input_count
    cv2.putText(frame, f"Inputs sent: {total}", (10, 120),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
    
    cv2.putText(frame, f"Hold time: {ZONE_HOLD_TIME:.2f}s | Cooldown: {INPUT_COOLDOWN:.2f}s",
                (10, height - 50), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 0), 1)
    cv2.putText(frame, "Q=Quit | +/- = Adjust hold time",
                (10, height - 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

# ==================== MAIN LOOP ====================

left_detector = ZoneDetector("Left")
right_detector = ZoneDetector("Right")

print("=" * 60)
print("POSITION MODE - Zone-Based Control")
print("=" * 60)
print(f"UDP: {GODOT_IP}:{GODOT_PORT}")
print("\nHOW IT WORKS:")
print("  - Screen divided into 5 zones: CENTER, UP, DOWN, LEFT, RIGHT")
print("  - Move hand to a zone and HOLD there briefly")
print("  - Input triggers when you've been in zone for", ZONE_HOLD_TIME, "seconds")
print("\nGAMEPLAY:")
print("  1. Start with hand in CENTER (neutral)")
print("  2. When arrow approaches target, move hand to that zone")
print("  3. Hold position until input triggers")
print("  4. Return to CENTER or move to next zone")
print("\nADJUST:")
print("  + key = Increase hold time (more deliberate)")
print("  - key = Decrease hold time (more responsive)")
print("=" * 60)
print()

def send_input(direction):
    """Send input to Godot."""
    try:
        # Send 3 times for reliability
        for _ in range(3):
            sock.sendto(direction.encode(), (GODOT_IP, GODOT_PORT))
        print(f"✓ SENT: {direction}")
        return True
    except Exception as e:
        print(f"✗ ERROR: {e}")
        return False

# Track recent inputs for simultaneous detection
recent_inputs = []
SIMULTANEOUS_WINDOW = 0.15

def check_simultaneous(current_time):
    """Check for two-hand inputs."""
    global recent_inputs
    recent_inputs = [
        (t, hand, inp) for t, hand, inp in recent_inputs
        if current_time - t <= SIMULTANEOUS_WINDOW
    ]
    
    if len(recent_inputs) >= 2:
        inputs_only = [inp for _, _, inp in recent_inputs[-2:]]
        input_set = set(inputs_only)
        
        if input_set == {"UP"}:
            return "DOUBLE_UP"
        elif input_set == {"DOWN"}:
            return "DOUBLE_DOWN"
        elif input_set == {"LEFT"}:
            return "DOUBLE_LEFT"
        elif input_set == {"RIGHT"}:
            return "DOUBLE_RIGHT"
        elif input_set == {"LEFT", "RIGHT"}:
            return "LEFT_RIGHT"
        elif input_set == {"UP", "DOWN"}:
            return "UP_DOWN"
    
    return None

# Main loop
try:
    while cap.isOpened():
        success, frame = cap.read()
        if not success:
            continue
        
        frame = cv2.flip(frame, 1)
        height, width = frame.shape[:2]
        
        draw_zones(frame, width, height)
        draw_ui(frame, width, height, left_detector, right_detector)
        
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = hands.process(rgb_frame)
        
        current_time = time.time()
        detected_inputs = []
        
        if results.multi_hand_landmarks and results.multi_handedness:
            for hand_landmarks, handedness in zip(results.multi_hand_landmarks, results.multi_handedness):
                mp_drawing.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)
                
                hand_label = handedness.classification[0].label
                detector = left_detector if hand_label == "Left" else right_detector
                
                direction = detector.update(hand_landmarks, current_time)
                draw_hand_info(frame, detector, hand_landmarks, width, height)
                
                if direction:
                    detected_inputs.append(direction)
                    recent_inputs.append((current_time, hand_label, direction))
        
        # Send inputs
        simultaneous = check_simultaneous(current_time)
        if simultaneous:
            send_input(simultaneous)
            recent_inputs.clear()
        elif len(detected_inputs) == 1:
            send_input(detected_inputs[0])
        
        cv2.imshow('Position Mode Controller', frame)
        
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q') or key == ord('Q'):
            print("\nShutting down...")
            break
        elif key == ord('+') or key == ord('='):
            ZONE_HOLD_TIME += 0.05
            print(f"\n→ Hold time: {ZONE_HOLD_TIME:.2f}s (more deliberate)")
        elif key == ord('-') or key == ord('_'):
            ZONE_HOLD_TIME = max(0.05, ZONE_HOLD_TIME - 0.05)
            print(f"\n→ Hold time: {ZONE_HOLD_TIME:.2f}s (more responsive)")

except KeyboardInterrupt:
    print("\nInterrupted")

finally:
    cap.release()
    cv2.destroyAllWindows()
    hands.close()
    sock.close()
    print(f"\nSession stats:")
    print(f"  Left hand inputs: {left_detector.input_count}")
    print(f"  Right hand inputs: {right_detector.input_count}")
    print(f"  Total: {left_detector.input_count + right_detector.input_count}")
    print("Controller stopped.")
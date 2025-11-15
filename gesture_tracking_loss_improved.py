"""
Rhythm Game - Improved Tracking Loss Controller
- Prioritizes single raised hand for single arrows
- Uses both hands for chord notes (two arrows)
- Better cooldown for repositioning
- Reduced lag

Author: Claude & Greg
For: CSCI 4250 Human Computer Interaction Project
"""

import cv2
import mediapipe as mp
import socket
import time
import numpy as np
from collections import deque

# ==================== CONFIGURATION ====================

# UDP Configuration
GODOT_IP = "127.0.0.1"
GODOT_PORT = 9999

# Tracking settings
POSITION_HISTORY_SIZE = 8
DIRECTION_DETECTION_FRAMES = 4

# Timing - ADJUSTED FOR BETTER GAMEPLAY
COOLDOWN_TIME = 0.5             # Longer cooldown for repositioning (was 0.3)
SIMULTANEOUS_WINDOW = 0.20      # Slightly longer for chord detection

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

# ==================== TRACKING LOSS DETECTOR ====================

class TrackingLossDetector:
    """Detects when hand disappears and sends the direction it was moving."""
    
    def __init__(self, hand_label):
        self.hand_label = hand_label
        self.position_history = deque(maxlen=POSITION_HISTORY_SIZE)
        self.was_visible = False
        self.last_hit_time = 0
        self.hit_count = 0
        self.last_y_position = 1.0  # Start at bottom (for prioritization)
        
    def update(self, is_visible, hand_landmarks, frame_time):
        """Update tracking state."""
        
        # If hand is visible, record its position
        if is_visible and hand_landmarks:
            palm = hand_landmarks.landmark[0]
            position = np.array([palm.x, palm.y])
            self.last_y_position = palm.y  # Track vertical position
            self.position_history.append((frame_time, position))
            self.was_visible = True
            return None
        
        # Hand just disappeared!
        if not is_visible and self.was_visible:
            self.was_visible = False
            
            # Check cooldown
            if frame_time - self.last_hit_time < COOLDOWN_TIME:
                return None
            
            # Determine direction from recent movement
            direction = self._determine_direction()
            
            if direction:
                self.last_hit_time = frame_time
                self.hit_count += 1
                print(f"  [{self.hand_label}] #{self.hit_count} SWIPE {direction}")
                return direction
        
        return None
    
    def _determine_direction(self):
        """Determine which direction the hand was moving before it disappeared."""
        if len(self.position_history) < 2:
            return None
        
        # Look at recent positions
        recent = list(self.position_history)[-DIRECTION_DETECTION_FRAMES:]
        
        if len(recent) < 2:
            return None
        
        # Calculate overall movement vector
        start_pos = recent[0][1]
        end_pos = recent[-1][1]
        movement = end_pos - start_pos
        
        dx = movement[0]
        dy = movement[1]
        
        # Determine dominant direction
        if abs(dx) < 0.05 and abs(dy) < 0.05:
            # Barely moved, use last known position relative to center
            last_pos = recent[-1][1]
            dx = last_pos[0] - 0.5
            dy = last_pos[1] - 0.5
        
        # Which direction is strongest?
        if abs(dx) > abs(dy):
            direction = "RIGHT" if dx > 0 else "LEFT"
        else:
            direction = "DOWN" if dy > 0 else "UP"
        
        return direction
    
    def get_current_direction(self):
        """Get the direction hand is currently moving (for display)."""
        if len(self.position_history) < 2:
            return None, None
        
        recent = list(self.position_history)[-3:]
        start_pos = recent[0][1]
        end_pos = recent[-1][1]
        movement = end_pos - start_pos
        
        dx = movement[0]
        dy = movement[1]
        
        if abs(dx) > abs(dy):
            direction = "RIGHT" if dx > 0 else "LEFT"
        else:
            direction = "DOWN" if dy > 0 else "UP"
        
        return direction, end_pos
    
    def clear_history(self):
        """Clear position history."""
        self.position_history.clear()
        self.was_visible = False
    
    def is_in_cooldown(self, current_time):
        """Check if hand is in cooldown period."""
        return current_time - self.last_hit_time < COOLDOWN_TIME

# ==================== VISUALIZATION ====================

def draw_ui(frame, width, height, left_detector, right_detector):
    """Draw instructions and stats."""
    cv2.putText(frame, "TRACKING LOSS MODE - IMPROVED", (10, 40),
                cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)
    cv2.putText(frame, "Single arrow: Raise ONE hand | Two arrows: Raise BOTH hands", (10, 80),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
    
    total_hits = left_detector.hit_count + right_detector.hit_count
    cv2.putText(frame, f"Hits: {total_hits}", (10, 120),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
    
    # Instructions
    cv2.putText(frame, "1. Raise hand(s) based on # of arrows", (10, height - 110),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    cv2.putText(frame, "2. Move slowly toward target direction", (10, height - 80),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    cv2.putText(frame, "3. SWIPE FAST when arrow reaches target", (10, height - 50),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    cv2.putText(frame, "Q=Quit | C=Clear", (10, height - 20),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

def draw_hand_tracking(frame, detector, hand_landmarks, width, height, current_time):
    """Show hand tracking and current direction."""
    direction, position = detector.get_current_direction()
    
    # Check if in cooldown
    in_cooldown = detector.is_in_cooldown(current_time)
    
    if position is not None:
        px = int(position[0] * width)
        py = int(position[1] * height)
        
        if in_cooldown:
            # Show cooldown state
            cv2.putText(frame, "COOLDOWN", (px - 60, py - 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (100, 100, 100), 2)
            cv2.circle(frame, (px, py), 15, (100, 100, 100), 3)
            return
        
        # Direction indicator
        arrow_color = {
            "UP": (0, 255, 255),
            "DOWN": (255, 255, 0),
            "LEFT": (255, 0, 255),
            "RIGHT": (0, 255, 0)
        }.get(direction, (255, 255, 255))
        
        # Draw direction arrow
        arrow_length = 60
        if direction == "UP":
            end_point = (px, py - arrow_length)
        elif direction == "DOWN":
            end_point = (px, py + arrow_length)
        elif direction == "LEFT":
            end_point = (px - arrow_length, py)
        else:  # RIGHT
            end_point = (px + arrow_length, py)
        
        cv2.arrowedLine(frame, (px, py), end_point, arrow_color, 4, tipLength=0.3)
        
        # Show direction label
        cv2.putText(frame, f"→ {direction}", (px + 25, py - 25),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, arrow_color, 2)

# ==================== MAIN LOOP ====================

left_detector = TrackingLossDetector("Left")
right_detector = TrackingLossDetector("Right")

print("=" * 60)
print("TRACKING LOSS MODE - IMPROVED VERSION")
print("=" * 60)
print(f"UDP: {GODOT_IP}:{GODOT_PORT}")
print("\nKEY IMPROVEMENTS:")
print("  ✓ Single hand tracking for single arrows")
print("  ✓ Both hands for chord notes (two arrows)")
print("  ✓ Longer cooldown (0.5s) for better repositioning")
print("  ✓ Reduced network lag (send once, not 3x)")
print("\nGAMEPLAY:")
print("  - ONE arrow coming? Raise ONE hand")
print("  - TWO arrows coming? Raise BOTH hands")
print("  - Move hand(s) slowly toward target(s)")
print("  - When arrow(s) reach target: SWIPE FAST!")
print("  - Bring hand(s) back to center during cooldown")
print("=" * 60)
print()

def send_input(direction):
    """Send input to Godot (single send for less lag)."""
    try:
        sock.sendto(direction.encode(), (GODOT_IP, GODOT_PORT))
        print(f"✓ SENT: {direction}")
        return True
    except Exception as e:
        print(f"✗ ERROR: {e}")
        return False

# Track recent inputs for simultaneous detection
recent_inputs = []

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
        
        draw_ui(frame, width, height, left_detector, right_detector)
        
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = hands.process(rgb_frame)
        
        current_time = time.time()
        detected_inputs = []
        
        # Track which hands are visible
        left_visible = False
        right_visible = False
        left_landmarks = None
        right_landmarks = None
        left_y_pos = 1.0
        right_y_pos = 1.0
        
        if results.multi_hand_landmarks and results.multi_handedness:
            for hand_landmarks, handedness in zip(results.multi_hand_landmarks, results.multi_handedness):
                mp_drawing.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)
                
                hand_label = handedness.classification[0].label
                palm_y = hand_landmarks.landmark[0].y
                
                if hand_label == "Left":
                    left_visible = True
                    left_landmarks = hand_landmarks
                    left_y_pos = palm_y
                    draw_hand_tracking(frame, left_detector, hand_landmarks, width, height, current_time)
                else:
                    right_visible = True
                    right_landmarks = hand_landmarks
                    right_y_pos = palm_y
                    draw_hand_tracking(frame, right_detector, hand_landmarks, width, height, current_time)
        
        # SMART HAND SELECTION
        # If both hands visible: use both (chord mode)
        # If one hand visible: use that one (single arrow mode)
        # If both visible but one is higher: prioritize the higher one for single arrows
        
        hands_to_process = []
        
        if left_visible and right_visible:
            # Both hands up - check for chords OR pick the higher one
            # For now, let's use both (chord detection will handle it)
            hands_to_process.append(("Left", left_landmarks))
            hands_to_process.append(("Right", right_landmarks))
        elif left_visible:
            # Only left hand up
            hands_to_process.append(("Left", left_landmarks))
        elif right_visible:
            # Only right hand up
            hands_to_process.append(("Right", right_landmarks))
        
        # Update detectors
        left_input = left_detector.update(left_visible, left_landmarks, current_time)
        right_input = right_detector.update(right_visible, right_landmarks, current_time)
        
        if left_input:
            detected_inputs.append(left_input)
            recent_inputs.append((current_time, "Left", left_input))
        
        if right_input:
            detected_inputs.append(right_input)
            recent_inputs.append((current_time, "Right", right_input))
        
        # Send inputs
        simultaneous = check_simultaneous(current_time)
        if simultaneous:
            send_input(simultaneous)
            recent_inputs.clear()
        elif len(detected_inputs) == 1:
            send_input(detected_inputs[0])
        
        cv2.imshow('Tracking Loss Controller - Improved', frame)
        
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q') or key == ord('Q'):
            print("\nShutting down...")
            break
        elif key == ord('c') or key == ord('C'):
            print("\n→ Cleared history")
            left_detector.clear_history()
            right_detector.clear_history()
            recent_inputs.clear()

except KeyboardInterrupt:
    print("\nInterrupted")

finally:
    cap.release()
    cv2.destroyAllWindows()
    hands.close()
    sock.close()
    print(f"\nSession stats:")
    print(f"  Left hand hits: {left_detector.hit_count}")
    print(f"  Right hand hits: {right_detector.hit_count}")
    print(f"  Total: {left_detector.hit_count + right_detector.hit_count}")
    print("Controller stopped.")
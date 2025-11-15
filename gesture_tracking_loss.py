"""
Rhythm Game - Tracking Loss Controller
Track the arrow with your hand, then SWIPE FAST to make your hand disappear!
The moment tracking is lost = perfect timing signal!

This is brilliant - uses "losing the hand" as the actual input!

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
POSITION_HISTORY_SIZE = 10
DIRECTION_DETECTION_FRAMES = 5  # Look at last N frames to determine direction

# Timing
COOLDOWN_TIME = 0.3  # Prevent spam after a hit

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
        
    def update(self, is_visible, hand_landmarks, frame_time):
        """
        Update tracking state.
        
        Args:
            is_visible: True if hand is currently detected
            hand_landmarks: MediaPipe hand landmarks (None if not visible)
            frame_time: Current timestamp
        """
        
        # If hand is visible, record its position
        if is_visible and hand_landmarks:
            palm = hand_landmarks.landmark[0]
            position = np.array([palm.x, palm.y])
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
                print(f"  [{self.hand_label}] #{self.hit_count} HAND DISAPPEARED! "
                      f"Direction: {direction}")
                return direction
        
        return None
    
    def _determine_direction(self):
        """Determine which direction the hand was moving before it disappeared."""
        if len(self.position_history) < 3:
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
            return None, (0, 0)
        
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

# ==================== VISUALIZATION ====================

def draw_ui(frame, width, height, left_detector, right_detector):
    """Draw instructions and stats."""
    cv2.putText(frame, "TRACKING LOSS MODE", (10, 40),
                cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2)
    cv2.putText(frame, "Track arrow with hand, then SWIPE FAST!", (10, 80),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
    cv2.putText(frame, "When hand disappears = HIT registered!", (10, 120),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
    
    total_hits = left_detector.hit_count + right_detector.hit_count
    cv2.putText(frame, f"Hits: {total_hits}", (10, 160),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
    
    # Instructions
    cv2.putText(frame, "1. Follow arrow slowly with your hand", (10, height - 110),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    cv2.putText(frame, "2. When arrow reaches target, SWIPE FAST", (10, height - 80),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    cv2.putText(frame, "3. Your hand should leave the camera view", (10, height - 50),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    cv2.putText(frame, "Q=Quit | C=Clear", (10, height - 20),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

def draw_hand_tracking(frame, detector, hand_landmarks, width, height):
    """Show hand tracking and current direction."""
    direction, position = detector.get_current_direction()
    
    if direction and position is not None:
        px = int(position[0] * width)
        py = int(position[1] * height)
        
        # Direction indicator
        arrow_color = {
            "UP": (0, 255, 255),
            "DOWN": (255, 255, 0),
            "LEFT": (255, 0, 255),
            "RIGHT": (0, 255, 0)
        }.get(direction, (255, 255, 255))
        
        # Draw direction arrow
        arrow_length = 80
        if direction == "UP":
            end_point = (px, py - arrow_length)
        elif direction == "DOWN":
            end_point = (px, py + arrow_length)
        elif direction == "LEFT":
            end_point = (px - arrow_length, py)
        else:  # RIGHT
            end_point = (px + arrow_length, py)
        
        cv2.arrowedLine(frame, (px, py), end_point, arrow_color, 5, tipLength=0.3)
        
        # Show direction label
        cv2.putText(frame, f"→ {direction}", (px + 30, py - 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, arrow_color, 2)

def draw_tracking_lost(frame, width, height, message):
    """Flash a big indicator when tracking is lost."""
    overlay = frame.copy()
    cv2.rectangle(overlay, (width//4, height//3), (3*width//4, 2*height//3), (0, 255, 0), -1)
    cv2.addWeighted(overlay, 0.3, frame, 0.7, 0, frame)
    
    cv2.putText(frame, "HIT!", (width//2 - 70, height//2),
                cv2.FONT_HERSHEY_SIMPLEX, 2.0, (255, 255, 255), 4)
    cv2.putText(frame, message, (width//2 - 100, height//2 + 60),
                cv2.FONT_HERSHEY_SIMPLEX, 1.0, (255, 255, 255), 2)

# ==================== MAIN LOOP ====================

left_detector = TrackingLossDetector("Left")
right_detector = TrackingLossDetector("Right")

# For visual feedback
last_hit_time = 0
last_hit_message = ""

print("=" * 60)
print("TRACKING LOSS MODE - Disappearing Hand Detection")
print("=" * 60)
print(f"UDP: {GODOT_IP}:{GODOT_PORT}")
print("\nCONCEPT:")
print("  - Your hand position indicates DIRECTION")
print("  - Your hand DISAPPEARING indicates TIMING")
print("  - Swipe fast enough to lose tracking = perfect hit!")
print("\nGAMEPLAY:")
print("  1. See arrow moving toward a target")
print("  2. Slowly move your hand in that same direction")
print("  3. When arrow REACHES target, SWIPE FAST out of view")
print("  4. The system detects which way you were going and registers hit")
print("\nTIPS:")
print("  - Start in frame, follow slowly, then FAST swipe")
print("  - The faster you swipe, the more reliably it loses tracking")
print("  - For two arrows, use both hands!")
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
SIMULTANEOUS_WINDOW = 0.2

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
        
        if results.multi_hand_landmarks and results.multi_handedness:
            for hand_landmarks, handedness in zip(results.multi_hand_landmarks, results.multi_handedness):
                mp_drawing.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)
                
                hand_label = handedness.classification[0].label
                
                if hand_label == "Left":
                    left_visible = True
                    left_landmarks = hand_landmarks
                    draw_hand_tracking(frame, left_detector, hand_landmarks, width, height)
                else:
                    right_visible = True
                    right_landmarks = hand_landmarks
                    draw_hand_tracking(frame, right_detector, hand_landmarks, width, height)
        
        # Update detectors (they trigger on visibility loss)
        left_input = left_detector.update(left_visible, left_landmarks, current_time)
        right_input = right_detector.update(right_visible, right_landmarks, current_time)
        
        if left_input:
            detected_inputs.append(left_input)
            recent_inputs.append((current_time, "Left", left_input))
            last_hit_time = current_time
            last_hit_message = f"LEFT HAND: {left_input}"
        
        if right_input:
            detected_inputs.append(right_input)
            recent_inputs.append((current_time, "Right", right_input))
            last_hit_time = current_time
            last_hit_message = f"RIGHT HAND: {right_input}"
        
        # Send inputs
        simultaneous = check_simultaneous(current_time)
        if simultaneous:
            send_input(simultaneous)
            recent_inputs.clear()
            last_hit_message = f"BOTH HANDS: {simultaneous}"
        elif len(detected_inputs) == 1:
            send_input(detected_inputs[0])
        
        # Show hit feedback
        if current_time - last_hit_time < 0.5:
            draw_tracking_lost(frame, width, height, last_hit_message)
        
        cv2.imshow('Tracking Loss Controller', frame)
        
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
"""
Rhythm Game Gesture Controller - More Reliable Version
Uses stricter detection and adds visual countdown to help with timing

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

# MUCH STRICTER DETECTION
MIN_SWIPE_DISTANCE = 0.25       # Need bigger swipes (increased from 0.15)
MIN_SWIPE_SPEED = 1.5           # Need faster swipes (increased from 1.0)
SWIPE_TIME_WINDOW = 0.20        # Shorter detection window
COOLDOWN_TIME = 0.5             # Prevent spam

# Make it MORE deliberate
POSITION_HISTORY_SIZE = 8

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

# ==================== SWIPE DETECTOR ====================

class StrictSwipeDetector:
    """Only detects VERY deliberate swipes."""
    
    def __init__(self, hand_label):
        self.hand_label = hand_label
        self.position_history = deque(maxlen=POSITION_HISTORY_SIZE)
        self.last_swipe_time = 0
        self.gesture_count = 0
        
    def update(self, hand_landmarks, frame_time):
        palm = hand_landmarks.landmark[0]
        current_pos = np.array([palm.x, palm.y])
        
        self.position_history.append((frame_time, current_pos))
        
        if frame_time - self.last_swipe_time < COOLDOWN_TIME:
            return None
        
        return self._detect_swipe(frame_time)
    
    def _detect_swipe(self, current_time):
        if len(self.position_history) < 4:
            return None
        
        # Get recent movement
        recent = list(self.position_history)
        start_pos = recent[0][1]
        end_pos = recent[-1][1]
        movement = end_pos - start_pos
        
        distance = np.linalg.norm(movement)
        time_elapsed = recent[-1][0] - recent[0][0]
        
        if time_elapsed <= 0:
            return None
        
        speed = distance / time_elapsed
        
        # STRICT requirements
        if distance < MIN_SWIPE_DISTANCE:
            return None
        
        if speed < MIN_SWIPE_SPEED:
            return None
        
        # Determine direction - require CLEAR directional intent
        dx = movement[0]
        dy = movement[1]
        
        # Require dominant direction to be much stronger
        gesture = None
        if abs(dx) > abs(dy) * 1.5:  # Horizontal must be 1.5x stronger
            gesture = "RIGHT" if dx > 0 else "LEFT"
        elif abs(dy) > abs(dx) * 1.5:  # Vertical must be 1.5x stronger
            gesture = "DOWN" if dy > 0 else "UP"
        else:
            return None  # Too diagonal, reject it
        
        self.last_swipe_time = current_time
        self.gesture_count += 1
        print(f"  [{self.hand_label}] #{self.gesture_count} SWIPE {gesture} | Dist: {distance:.3f} | Speed: {speed:.2f}")
        
        return gesture
    
    def get_info(self):
        if len(self.position_history) < 2:
            return None, 0.0, 0.0
        
        recent = list(self.position_history)
        current_pos = recent[-1][1]
        
        # Calculate recent speed
        if len(recent) >= 3:
            total_dist = 0
            for i in range(1, len(recent)):
                total_dist += np.linalg.norm(recent[i][1] - recent[i-1][1])
            time_span = recent[-1][0] - recent[0][0]
            speed = total_dist / time_span if time_span > 0 else 0
        else:
            speed = 0
        
        # Calculate recent distance
        if len(recent) >= 2:
            distance = np.linalg.norm(recent[-1][1] - recent[0][1])
        else:
            distance = 0
        
        return current_pos, distance, speed

# ==================== VISUALIZATION ====================

def draw_ui(frame, width, height, left_detector, right_detector):
    """Draw instructions and feedback."""
    # Title
    cv2.putText(frame, "STRICT SWIPE MODE", (10, 40),
                cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2)
    cv2.putText(frame, "Make BIG, FAST, CLEAR swipes!", (10, 80),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
    
    # Gesture counts
    total_gestures = left_detector.gesture_count + right_detector.gesture_count
    cv2.putText(frame, f"Gestures sent: {total_gestures}", (10, 120),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
    
    # Requirements
    cv2.putText(frame, f"Need: Distance >{MIN_SWIPE_DISTANCE:.2f} | Speed >{MIN_SWIPE_SPEED:.1f}", 
                (10, height - 80), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 0), 1)
    cv2.putText(frame, "Swipe must be clearly horizontal OR vertical (not diagonal)", 
                (10, height - 50), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 0), 1)
    cv2.putText(frame, "Q=Quit | C=Clear | +/- = Adjust speed", 
                (10, height - 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

def draw_hand_meter(frame, detector, hand_landmarks, width, height):
    """Show if swipe is strong enough."""
    palm = hand_landmarks.landmark[0]
    px = int(palm.x * width)
    py = int(palm.y * height)
    
    pos, distance, speed = detector.get_info()
    if pos is None:
        return
    
    # Distance meter
    dist_percent = min(distance / MIN_SWIPE_DISTANCE, 1.0)
    dist_bar_length = int(dist_percent * 100)
    dist_color = (0, 255, 0) if distance >= MIN_SWIPE_DISTANCE else (0, 0, 255)
    
    # Speed meter  
    speed_percent = min(speed / MIN_SWIPE_SPEED, 1.0)
    speed_bar_length = int(speed_percent * 100)
    speed_color = (0, 255, 0) if speed >= MIN_SWIPE_SPEED else (0, 0, 255)
    
    # Draw meters
    # Distance
    cv2.rectangle(frame, (px - 50, py - 60), (px - 50 + dist_bar_length, py - 50), dist_color, -1)
    cv2.rectangle(frame, (px - 50, py - 60), (px + 50, py - 50), (100, 100, 100), 2)
    cv2.putText(frame, "DIST", (px - 90, py - 50), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255, 255, 255), 1)
    
    # Speed
    cv2.rectangle(frame, (px - 50, py - 40), (px - 50 + speed_bar_length, py - 30), speed_color, -1)
    cv2.rectangle(frame, (px - 50, py - 40), (px + 50, py - 30), (100, 100, 100), 2)
    cv2.putText(frame, "SPEED", (px - 90, py - 30), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255, 255, 255), 1)
    
    # Status
    if distance >= MIN_SWIPE_DISTANCE and speed >= MIN_SWIPE_SPEED:
        cv2.putText(frame, "READY!", (px - 40, py - 70),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)

# ==================== MAIN LOOP ====================

left_detector = StrictSwipeDetector("Left")
right_detector = StrictSwipeDetector("Right")

print("=" * 60)
print("STRICT SWIPE MODE - Reduced False Positives")
print("=" * 60)
print(f"UDP: {GODOT_IP}:{GODOT_PORT}")
print("\nREQUIREMENTS:")
print(f"  - Swipe distance: >{MIN_SWIPE_DISTANCE:.2f} (bigger than before)")
print(f"  - Swipe speed: >{MIN_SWIPE_SPEED:.1f} (faster than before)")
print("  - Direction must be clearly horizontal OR vertical")
print("\nTIPS:")
print("  - Make BIG, exaggerated swipes")
print("  - Swipe FAST, not slow")
print("  - Keep swipes straight (not diagonal)")
print("  - Watch the meters under your hand - both must be GREEN")
print("=" * 60)
print()

def send_gesture(gesture):
    try:
        # Send 3 times to reduce packet loss
        for _ in range(3):
            sock.sendto(gesture.encode(), (GODOT_IP, GODOT_PORT))
        print(f"✓ SENT: {gesture} (x3 for reliability)")
        return True
    except Exception as e:
        print(f"✗ ERROR: {e}")
        return False

# Simultaneous gesture tracking
recent_gestures = []
SIMULTANEOUS_WINDOW = 0.15

def check_simultaneous(current_time):
    global recent_gestures
    recent_gestures = [
        (t, hand, gest) for t, hand, gest in recent_gestures
        if current_time - t <= SIMULTANEOUS_WINDOW
    ]
    
    if len(recent_gestures) >= 2:
        gestures_only = [gest for _, _, gest in recent_gestures[-2:]]
        gesture_set = set(gestures_only)
        
        if gesture_set == {"UP"}:
            return "DOUBLE_UP"
        elif gesture_set == {"DOWN"}:
            return "DOUBLE_DOWN"
        elif gesture_set == {"LEFT"}:
            return "DOUBLE_LEFT"
        elif gesture_set == {"RIGHT"}:
            return "DOUBLE_RIGHT"
        elif gesture_set == {"LEFT", "RIGHT"}:
            return "LEFT_RIGHT"
        elif gesture_set == {"UP", "DOWN"}:
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
        detected_gestures = []
        
        if results.multi_hand_landmarks and results.multi_handedness:
            for hand_landmarks, handedness in zip(results.multi_hand_landmarks, results.multi_handedness):
                mp_drawing.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)
                
                hand_label = handedness.classification[0].label
                detector = left_detector if hand_label == "Left" else right_detector
                
                gesture = detector.update(hand_landmarks, current_time)
                draw_hand_meter(frame, detector, hand_landmarks, width, height)
                
                if gesture:
                    detected_gestures.append(gesture)
                    recent_gestures.append((current_time, hand_label, gesture))
        
        # Send gestures
        simultaneous = check_simultaneous(current_time)
        if simultaneous:
            send_gesture(simultaneous)
            recent_gestures.clear()
        elif len(detected_gestures) == 1:
            send_gesture(detected_gestures[0])
        
        cv2.imshow('Strict Swipe Detector', frame)
        
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q') or key == ord('Q'):
            print("\nShutting down...")
            break
        elif key == ord('c') or key == ord('C'):
            print("\n→ Cleared history")
            left_detector.position_history.clear()
            right_detector.position_history.clear()
            recent_gestures.clear()
        elif key == ord('+') or key == ord('='):
            MIN_SWIPE_SPEED += 0.2
            print(f"\n→ Speed threshold: {MIN_SWIPE_SPEED:.1f}")
        elif key == ord('-') or key == ord('_'):
            MIN_SWIPE_SPEED = max(0.5, MIN_SWIPE_SPEED - 0.2)
            print(f"\n→ Speed threshold: {MIN_SWIPE_SPEED:.1f}")

except KeyboardInterrupt:
    print("\nInterrupted")

finally:
    cap.release()
    cv2.destroyAllWindows()
    hands.close()
    sock.close()
    print(f"\nSession stats:")
    print(f"  Left hand gestures: {left_detector.gesture_count}")
    print(f"  Right hand gestures: {right_detector.gesture_count}")
    print(f"  Total: {left_detector.gesture_count + right_detector.gesture_count}")
    print("Detector stopped.")
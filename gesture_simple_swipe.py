"""
Simple Swipe Detector for Rhythm Game
Just detects fast directional swipes - no position requirements!

Hold your hand up, swipe when arrow hits target.
That's it!

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

# Swipe Detection (SIMPLIFIED)
MIN_SWIPE_DISTANCE = 0.15       # How far you need to swipe (0-1 scale) - ADJUST THIS
MIN_SWIPE_SPEED = 1.0           # How fast you need to swipe - ADJUST THIS
SWIPE_TIME_WINDOW = 0.25        # Time to complete swipe (seconds)
COOLDOWN_TIME = 0.3             # Time between swipes (seconds)

# Hand tracking
POSITION_HISTORY_SIZE = 10

# Visual feedback
SHOW_DEBUG_INFO = True

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

# ==================== SIMPLE SWIPE DETECTOR ====================

class SimpleSwipeDetector:
    """Detects fast directional swipes - that's it!"""
    
    def __init__(self, hand_label):
        self.hand_label = hand_label
        self.position_history = deque(maxlen=POSITION_HISTORY_SIZE)
        self.last_swipe_time = 0
        
    def update(self, hand_landmarks, frame_time):
        """Update position and check for swipe."""
        # Track palm center
        palm = hand_landmarks.landmark[0]
        current_pos = np.array([palm.x, palm.y])
        
        self.position_history.append((frame_time, current_pos))
        
        # Need cooldown between swipes
        if frame_time - self.last_swipe_time < COOLDOWN_TIME:
            return None
        
        # Detect swipe
        return self._detect_swipe(frame_time)
    
    def _detect_swipe(self, current_time):
        """Detect if hand just swiped in a direction."""
        if len(self.position_history) < 5:
            return None
        
        # Get recent positions within time window
        recent = [
            (t, pos) for t, pos in self.position_history
            if current_time - t <= SWIPE_TIME_WINDOW
        ]
        
        if len(recent) < 3:
            return None
        
        # Calculate movement from oldest to newest in window
        start_pos = recent[0][1]
        end_pos = recent[-1][1]
        movement = end_pos - start_pos
        
        # Calculate distance and speed
        distance = np.linalg.norm(movement)
        time_elapsed = recent[-1][0] - recent[0][0]
        
        if time_elapsed <= 0:
            return None
        
        speed = distance / time_elapsed
        
        # Check if it's a significant swipe
        if distance < MIN_SWIPE_DISTANCE:
            return None
        
        if speed < MIN_SWIPE_SPEED:
            return None
        
        # Determine direction based on largest component
        dx = movement[0]
        dy = movement[1]
        
        gesture = None
        if abs(dx) > abs(dy):
            # Horizontal swipe
            if dx > 0:
                gesture = "RIGHT"
            else:
                gesture = "LEFT"
        else:
            # Vertical swipe
            if dy > 0:
                gesture = "DOWN"
            else:
                gesture = "UP"
        
        # Record the swipe
        self.last_swipe_time = current_time
        print(f"  [{self.hand_label}] SWIPE {gesture} | Distance: {distance:.3f} | Speed: {speed:.2f}")
        
        return gesture
    
    def get_current_pos(self):
        """Get current hand position for display."""
        if self.position_history:
            return self.position_history[-1][1]
        return None
    
    def get_recent_speed(self):
        """Get recent movement speed for display."""
        if len(self.position_history) < 2:
            return 0.0
        
        recent = list(self.position_history)[-5:]
        if len(recent) < 2:
            return 0.0
        
        total_distance = 0
        for i in range(1, len(recent)):
            total_distance += np.linalg.norm(recent[i][1] - recent[i-1][1])
        
        time_span = recent[-1][0] - recent[0][0]
        if time_span > 0:
            return total_distance / time_span
        return 0.0

# ==================== VISUALIZATION ====================

def draw_ui(frame, width, height):
    """Draw instructions and threshold info."""
    cv2.putText(frame, "SIMPLE SWIPE MODE", (10, 40),
                cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2)
    cv2.putText(frame, "Hold hand up, SWIPE when arrow hits!", (10, 80),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
    
    # Show current thresholds
    cv2.putText(frame, f"Min Distance: {MIN_SWIPE_DISTANCE:.2f}", (10, height - 80),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 0), 1)
    cv2.putText(frame, f"Min Speed: {MIN_SWIPE_SPEED:.1f}", (10, height - 50),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 0), 1)
    cv2.putText(frame, "Q=Quit | C=Clear | +/- = Speed threshold", (10, height - 20),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

def draw_hand_feedback(frame, detector, hand_landmarks, width, height):
    """Draw speed meter for hand."""
    palm = hand_landmarks.landmark[0]
    px = int(palm.x * width)
    py = int(palm.y * height)
    
    speed = detector.get_recent_speed()
    
    # Speed bar (shows if you're swiping fast enough)
    bar_length = int(min(speed / MIN_SWIPE_SPEED, 2.0) * 150)
    
    # Color based on speed
    if speed >= MIN_SWIPE_SPEED:
        color = (0, 255, 0)  # Green - fast enough!
        status = "FAST!"
    elif speed >= MIN_SWIPE_SPEED * 0.5:
        color = (0, 255, 255)  # Yellow - getting there
        status = "FASTER"
    else:
        color = (0, 0, 255)  # Red - too slow
        status = "READY"
    
    # Draw speed bar
    cv2.rectangle(frame, (px - 75, py - 40), (px - 75 + bar_length, py - 25), color, -1)
    cv2.rectangle(frame, (px - 75, py - 40), (px + 75, py - 25), (100, 100, 100), 2)
    
    # Show status
    cv2.putText(frame, status, (px - 50, py - 50),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
    
    # Show speed value
    cv2.putText(frame, f"Speed: {speed:.2f}", (px + 20, py),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

# ==================== MAIN LOOP ====================

left_detector = SimpleSwipeDetector("Left")
right_detector = SimpleSwipeDetector("Right")

print("=" * 60)
print("SIMPLE SWIPE MODE - Rhythm Game")
print("=" * 60)
print(f"UDP: {GODOT_IP}:{GODOT_PORT}")
print("\nHOW TO USE:")
print("1. Hold your hand(s) up in view of webcam")
print("2. When arrow reaches target → SWIPE QUICKLY in that direction")
print("3. The system detects fast directional movements")
print("\nADJUST IF NEEDED:")
print("  + key = Increase speed threshold (need faster swipes)")
print("  - key = Decrease speed threshold (easier to trigger)")
print("=" * 60)
print()

def send_gesture(gesture):
    """Send gesture to Godot."""
    try:
        sock.sendto(gesture.encode(), (GODOT_IP, GODOT_PORT))
        print(f"✓ SENT: {gesture}")
        return True
    except Exception as e:
        print(f"✗ ERROR: {e}")
        return False

# Track recent gestures for simultaneous detection
recent_gestures = []
SIMULTANEOUS_WINDOW = 0.15

def check_simultaneous(current_time):
    """Check for two-hand gestures."""
    global recent_gestures
    
    # Keep only recent gestures
    recent_gestures = [
        (t, hand, gest) for t, hand, gest in recent_gestures
        if current_time - t <= SIMULTANEOUS_WINDOW
    ]
    
    if len(recent_gestures) >= 2:
        gestures_only = [gest for _, _, gest in recent_gestures[-2:]]
        gesture_set = set(gestures_only)
        
        # Check for doubles
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
        
        draw_ui(frame, width, height)
        
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = hands.process(rgb_frame)
        
        current_time = time.time()
        detected_gestures = []
        
        if results.multi_hand_landmarks and results.multi_handedness:
            for hand_landmarks, handedness in zip(results.multi_hand_landmarks, results.multi_handedness):
                # Draw hand skeleton
                mp_drawing.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)
                
                hand_label = handedness.classification[0].label
                
                # Update detector
                if hand_label == "Left":
                    detector = left_detector
                else:
                    detector = right_detector
                
                gesture = detector.update(hand_landmarks, current_time)
                
                # Draw feedback
                if SHOW_DEBUG_INFO:
                    draw_hand_feedback(frame, detector, hand_landmarks, width, height)
                
                if gesture:
                    detected_gestures.append(gesture)
                    recent_gestures.append((current_time, hand_label, gesture))
        
        # Check for simultaneous gestures
        simultaneous = check_simultaneous(current_time)
        if simultaneous:
            send_gesture(simultaneous)
            recent_gestures.clear()
        elif len(detected_gestures) == 1:
            send_gesture(detected_gestures[0])
        
        cv2.imshow('Simple Swipe Detector', frame)
        
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
            print(f"\n→ Speed threshold: {MIN_SWIPE_SPEED:.1f} (need faster swipes)")
        elif key == ord('-') or key == ord('_'):
            MIN_SWIPE_SPEED = max(0.3, MIN_SWIPE_SPEED - 0.2)
            print(f"\n→ Speed threshold: {MIN_SWIPE_SPEED:.1f} (easier to trigger)")

except KeyboardInterrupt:
    print("\nInterrupted")

finally:
    cap.release()
    cv2.destroyAllWindows()
    hands.close()
    sock.close()
    print("Swipe detector stopped.")
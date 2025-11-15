"""
Rhythm Game Gesture Controller - Calibration Version
This version helps you understand what the system is detecting

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

# SIMPLIFIED DETECTION - Just detect quick movements in any direction
VELOCITY_THRESHOLD = 0.8        # How fast you need to move (lower = easier)
POSITION_TOLERANCE = 0.25       # How close to target (higher = easier)
COOLDOWN_TIME = 0.4             # Time between detections

# Target positions (adjusted for typical webcam view)
# These are mirrored for the flipped webcam display
TARGET_POSITIONS = {
    "UP": (0.5, 0.20),      # Top center
    "DOWN": (0.5, 0.80),    # Bottom center  
    "LEFT": (0.20, 0.5),    # Left side (on your RIGHT since mirrored)
    "RIGHT": (0.80, 0.5)    # Right side (on your LEFT since mirrored)
}

POSITION_HISTORY_SIZE = 15

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

# ==================== HAND TRACKING ====================

class HandTracker:
    def __init__(self, hand_label):
        self.hand_label = hand_label
        self.position_history = deque(maxlen=POSITION_HISTORY_SIZE)
        self.last_gesture_time = 0
        self.current_velocity = 0
        
    def update(self, hand_landmarks, frame_time):
        palm_center = hand_landmarks.landmark[0]
        current_pos = np.array([palm_center.x, palm_center.y])
        
        self.position_history.append((frame_time, current_pos))
        self._update_velocity(frame_time)
        
        if frame_time - self.last_gesture_time < COOLDOWN_TIME:
            return None
        
        return self._detect_gesture(current_pos, frame_time)
    
    def _update_velocity(self, current_time):
        if len(self.position_history) < 5:
            self.current_velocity = 0
            return
        
        recent = list(self.position_history)[-5:]
        total_distance = 0
        
        for i in range(1, len(recent)):
            distance = np.linalg.norm(recent[i][1] - recent[i-1][1])
            total_distance += distance
        
        time_span = recent[-1][0] - recent[0][0]
        if time_span > 0:
            self.current_velocity = total_distance / time_span
    
    def _detect_gesture(self, current_pos, current_time):
        # Check if moving fast enough
        if self.current_velocity < VELOCITY_THRESHOLD:
            return None
        
        # Find which target is closest
        closest_dir = None
        min_distance = float('inf')
        
        for direction, target_pos in TARGET_POSITIONS.items():
            distance = np.linalg.norm(current_pos - np.array(target_pos))
            if distance < min_distance:
                min_distance = distance
                closest_dir = direction
        
        # Only trigger if close enough to a target
        if min_distance <= POSITION_TOLERANCE:
            self.last_gesture_time = current_time
            print(f"  [{self.hand_label}] {closest_dir} | Pos: ({current_pos[0]:.2f}, {current_pos[1]:.2f}) | "
                  f"Dist: {min_distance:.3f} | Vel: {self.current_velocity:.2f}")
            return closest_dir
        
        return None
    
    def get_status(self, current_pos):
        """Get current hand status for display."""
        closest_dir = None
        min_distance = float('inf')
        
        for direction, target_pos in TARGET_POSITIONS.items():
            distance = np.linalg.norm(current_pos - np.array(target_pos))
            if distance < min_distance:
                min_distance = distance
                closest_dir = direction
        
        return closest_dir, min_distance, self.current_velocity

# ==================== VISUALIZATION ====================

def draw_ui(frame, width, height):
    """Draw target zones and instructions."""
    # Draw target zones
    for direction, (tx, ty) in TARGET_POSITIONS.items():
        px = int(tx * width)
        py = int(ty * height)
        
        # Tolerance circle
        tolerance_radius = int(POSITION_TOLERANCE * width)
        cv2.circle(frame, (px, py), tolerance_radius, (100, 100, 100), 2)
        
        # Center dot
        cv2.circle(frame, (px, py), 15, (255, 255, 255), -1)
        
        # Label
        cv2.putText(frame, direction, (px - 30, py + tolerance_radius + 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
    
    # Instructions
    cv2.putText(frame, "CALIBRATION MODE", (10, 30),
                cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)
    cv2.putText(frame, "Move hand to target, then SWIPE FAST", (10, 65),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
    cv2.putText(frame, f"Velocity needed: {VELOCITY_THRESHOLD:.1f}", (10, height - 80),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 0), 1)
    cv2.putText(frame, f"Distance needed: {POSITION_TOLERANCE:.2f}", (10, height - 50),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 0), 1)
    cv2.putText(frame, "Q=Quit | C=Clear | +/- = Adjust velocity", (10, height - 20),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

def draw_hand_info(frame, tracker, hand_landmarks, width, height):
    """Draw info about hand position and velocity."""
    palm = hand_landmarks.landmark[0]
    palm_pos = np.array([palm.x, palm.y])
    px = int(palm.x * width)
    py = int(palm.y * height)
    
    closest_dir, distance, velocity = tracker.get_status(palm_pos)
    
    # Draw line to closest target
    target_x = int(TARGET_POSITIONS[closest_dir][0] * width)
    target_y = int(TARGET_POSITIONS[closest_dir][1] * height)
    
    # Color based on readiness
    in_position = distance <= POSITION_TOLERANCE
    fast_enough = velocity >= VELOCITY_THRESHOLD
    
    if in_position and fast_enough:
        color = (0, 255, 0)  # GREEN - ready to hit!
        status = "HIT!"
    elif in_position:
        color = (0, 255, 255)  # YELLOW - in position, need speed
        status = "SWIPE!"
    else:
        color = (0, 0, 255)  # RED - move to target
        status = "MOVE"
    
    cv2.line(frame, (px, py), (target_x, target_y), color, 3)
    
    # Draw velocity bar
    bar_length = int(min(velocity / VELOCITY_THRESHOLD, 2.0) * 100)
    cv2.rectangle(frame, (px - 50, py - 30), (px - 50 + bar_length, py - 20), (0, 255, 255), -1)
    
    # Show status
    cv2.putText(frame, status, (px - 40, py - 40),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2)
    
    # Show metrics
    info_text = f"→{closest_dir} D:{distance:.2f} V:{velocity:.2f}"
    cv2.putText(frame, info_text, (px + 20, py),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

# ==================== MAIN LOOP ====================

left_hand_tracker = HandTracker("Left")
right_hand_tracker = HandTracker("Right")

print("=" * 60)
print("CALIBRATION MODE - Rhythm Game Gesture Controller")
print("=" * 60)
print(f"UDP: {GODOT_IP}:{GODOT_PORT}")
print("\nTEST YOUR GESTURES:")
print("1. Move hand SLOWLY to a target zone")
print("2. When close, SWIPE QUICKLY in that direction")
print("3. Watch the velocity bar - it should fill up when swiping")
print("4. Green = gesture detected, Yellow = too slow, Red = wrong position")
print("\nADJUST SENSITIVITY:")
print("  + key = Increase velocity threshold (harder)")
print("  - key = Decrease velocity threshold (easier)")
print("=" * 60)
print()

def send_gesture(gesture):
    try:
        sock.sendto(gesture.encode(), (GODOT_IP, GODOT_PORT))
        print(f"✓ SENT: {gesture}")
    except Exception as e:
        print(f"✗ Error: {e}")

try:
    while cap.isOpened():
        success, frame = cap.read()
        if not success:
            continue
        
        frame = cv2.flip(frame, 1)  # Mirror for natural interaction
        height, width = frame.shape[:2]
        
        draw_ui(frame, width, height)
        
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = hands.process(rgb_frame)
        
        current_time = time.time()
        
        if results.multi_hand_landmarks and results.multi_handedness:
            for hand_landmarks, handedness in zip(results.multi_hand_landmarks, results.multi_handedness):
                mp_drawing.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)
                
                hand_label = handedness.classification[0].label
                
                if hand_label == "Left":
                    tracker = left_hand_tracker
                else:
                    tracker = right_hand_tracker
                
                gesture = tracker.update(hand_landmarks, current_time)
                
                draw_hand_info(frame, tracker, hand_landmarks, width, height)
                
                if gesture:
                    send_gesture(gesture)
        
        cv2.imshow('Calibration Mode', frame)
        
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q') or key == ord('Q'):
            break
        elif key == ord('c') or key == ord('C'):
            print("\n→ Cleared history")
            left_hand_tracker.position_history.clear()
            right_hand_tracker.position_history.clear()
        elif key == ord('+') or key == ord('='):
            VELOCITY_THRESHOLD += 0.1
            print(f"\n→ Velocity threshold: {VELOCITY_THRESHOLD:.1f} (harder)")
        elif key == ord('-') or key == ord('_'):
            VELOCITY_THRESHOLD = max(0.1, VELOCITY_THRESHOLD - 0.1)
            print(f"\n→ Velocity threshold: {VELOCITY_THRESHOLD:.1f} (easier)")

except KeyboardInterrupt:
    print("\nInterrupted")

finally:
    cap.release()
    cv2.destroyAllWindows()
    hands.close()
    sock.close()
    print("Calibration stopped.")
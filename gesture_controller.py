"""
Rhythm Game Gesture Controller
Tracks hand movements via webcam and sends gesture commands to Godot game via UDP.

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
GODOT_IP = "127.0.0.1"  # localhost
GODOT_PORT = 9999       # Port Godot will listen on

# Gesture Detection Parameters
SWIPE_THRESHOLD = 0.20          # Minimum distance for swipe (0-1 normalized) - INCREASED
SWIPE_TIME_WINDOW = 0.4         # Time window to complete swipe (seconds) - DECREASED for faster swipes
COOLDOWN_TIME = 0.8             # Time before detecting another gesture (seconds) - INCREASED to prevent spam
SIMULTANEOUS_WINDOW = 0.2       # Time window for simultaneous two-hand gestures
MIN_VELOCITY = 0.4              # Minimum velocity to count as intentional swipe (NEW)

# Predictive Detection (Option B)
EARLY_DETECTION_RATIO = 0.7     # Detect at 70% of swipe completion - INCREASED to require more commitment

# Hand tracking history
POSITION_HISTORY_SIZE = 30      # Number of frames to keep for velocity calculation

# ==================== INITIALIZATION ====================

# Initialize MediaPipe Hands
mp_hands = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils
hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=2,
    min_detection_confidence=0.7,
    min_tracking_confidence=0.7
)

# Initialize UDP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

# Initialize webcam
cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

# ==================== GESTURE TRACKING ====================

class HandTracker:
    """Tracks a single hand's position and detects swipe gestures."""
    
    def __init__(self, hand_label):
        self.hand_label = hand_label  # "Left" or "Right"
        self.position_history = deque(maxlen=POSITION_HISTORY_SIZE)
        self.last_gesture_time = 0
        self.current_gesture = None
        self.gesture_start_pos = None
        self.gesture_start_time = None
        
    def update(self, hand_landmarks, frame_time):
        """Update hand position and check for gestures."""
        # Use palm center (landmark 0) for tracking
        palm_center = hand_landmarks.landmark[0]
        current_pos = np.array([palm_center.x, palm_center.y])
        
        # Add to history
        self.position_history.append((frame_time, current_pos))
        
        # Check if we're in cooldown
        if frame_time - self.last_gesture_time < COOLDOWN_TIME:
            return None
        
        # Detect swipe gesture
        return self._detect_swipe(frame_time)
    
    def _detect_swipe(self, current_time):
        """Detect swipe direction based on hand movement."""
        if len(self.position_history) < 10:
            return None
        
        # Get positions from the time window
        recent_positions = [
            (t, pos) for t, pos in self.position_history
            if current_time - t <= SWIPE_TIME_WINDOW
        ]
        
        if len(recent_positions) < 10:
            return None
        
        # Calculate movement vector
        start_pos = recent_positions[0][1]
        end_pos = recent_positions[-1][1]
        movement = end_pos - start_pos
        
        dx, dy = movement[0], movement[1]
        distance = np.linalg.norm(movement)
        
        # Check if movement is significant enough
        if distance < SWIPE_THRESHOLD:
            return None
        
        # Calculate velocity (distance over time)
        time_elapsed = current_time - recent_positions[0][0]
        if time_elapsed == 0:
            return None
        velocity = distance / time_elapsed
        
        # Require minimum velocity for deliberate swipes (NEW)
        if velocity < MIN_VELOCITY:
            return None
        
        # Predictive detection: trigger earlier in the swipe
        if distance < SWIPE_THRESHOLD * EARLY_DETECTION_RATIO:
            return None
        
        # Determine direction (prioritize the dominant axis)
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
        
        # Mark gesture as detected
        self.last_gesture_time = current_time
        self.position_history.clear()  # Clear history after gesture
        
        return gesture

# ==================== MAIN LOOP ====================

left_hand_tracker = HandTracker("Left")
right_hand_tracker = HandTracker("Right")

# Store recent gestures for simultaneous detection
recent_gestures = []  # List of (time, hand, gesture) tuples

print("=" * 60)
print("RHYTHM GAME GESTURE CONTROLLER")
print("=" * 60)
print(f"Sending gestures to Godot at {GODOT_IP}:{GODOT_PORT}")
print("\nControls:")
print("  - Swipe UP/DOWN/LEFT/RIGHT with one hand")
print("  - Use both hands for double arrows")
print("  - Press 'Q' to quit")
print("  - Press 'C' to calibrate (clear gesture history)")
print("=" * 60)
print("\nStarting webcam...\n")

def send_gesture_to_godot(gesture_command):
    """Send gesture command to Godot via UDP."""
    try:
        sock.sendto(gesture_command.encode(), (GODOT_IP, GODOT_PORT))
        print(f"Sent: {gesture_command}")
    except Exception as e:
        print(f"Error sending gesture: {e}")

def check_simultaneous_gestures(current_time):
    """Check if two gestures happened simultaneously."""
    global recent_gestures
    
    # Filter to gestures within the simultaneous window
    recent_gestures = [
        (t, hand, gest) for t, hand, gest in recent_gestures
        if current_time - t <= SIMULTANEOUS_WINDOW
    ]
    
    if len(recent_gestures) >= 2:
        # Get the two most recent gestures
        gestures_only = [gest for _, _, gest in recent_gestures[-2:]]
        
        # Check for double arrow combinations
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
            print("Failed to capture frame. Retrying...")
            continue
        
        # Flip frame horizontally for mirror view
        frame = cv2.flip(frame, 1)
        
        # Convert to RGB for MediaPipe
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = hands.process(rgb_frame)
        
        current_time = time.time()
        detected_gestures = []
        
        # Process detected hands
        if results.multi_hand_landmarks and results.multi_handedness:
            for hand_landmarks, handedness in zip(results.multi_hand_landmarks, results.multi_handedness):
                # Draw hand landmarks
                mp_drawing.draw_landmarks(
                    frame, hand_landmarks, mp_hands.HAND_CONNECTIONS
                )
                
                # Determine which hand
                hand_label = handedness.classification[0].label
                
                # Update appropriate tracker
                gesture = None
                if hand_label == "Left":
                    gesture = left_hand_tracker.update(hand_landmarks, current_time)
                else:
                    gesture = right_hand_tracker.update(hand_landmarks, current_time)
                
                # Store detected gesture
                if gesture:
                    detected_gestures.append(gesture)
                    recent_gestures.append((current_time, hand_label, gesture))
        
        # Check for simultaneous gestures first
        simultaneous = check_simultaneous_gestures(current_time)
        if simultaneous:
            send_gesture_to_godot(simultaneous)
            recent_gestures.clear()  # Clear after sending simultaneous
        elif len(detected_gestures) == 1:
            # Single gesture detected
            send_gesture_to_godot(detected_gestures[0])
        
        # Display instructions on frame
        cv2.putText(frame, "Rhythm Game Gesture Controller", (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        cv2.putText(frame, "Press 'Q' to quit | 'C' to calibrate", (10, 60),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
        
        # Show the frame
        cv2.imshow('Gesture Controller', frame)
        
        # Handle key presses
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q') or key == ord('Q'):
            print("\nShutting down...")
            break
        elif key == ord('c') or key == ord('C'):
            print("\nCalibrating... Clearing gesture history")
            left_hand_tracker.position_history.clear()
            right_hand_tracker.position_history.clear()
            recent_gestures.clear()

except KeyboardInterrupt:
    print("\nInterrupted by user")

finally:
    # Cleanup
    cap.release()
    cv2.destroyAllWindows()
    hands.close()
    sock.close()
    print("Gesture controller stopped.")
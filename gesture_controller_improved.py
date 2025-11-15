"""
Rhythm Game Gesture Controller - Improved Version
Tracks hand position and detects acceleration for precise timing hits.

The player tracks the moving arrow with their hand, then accelerates/swipes
when the arrow reaches the target for perfect timing.

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
ACCELERATION_THRESHOLD = 2.5    # Minimum acceleration spike to register hit
POSITION_TOLERANCE = 0.18       # How close hand must be to target position (0-1 normalized)
COOLDOWN_TIME = 0.5             # Time before detecting another gesture (seconds)
SIMULTANEOUS_WINDOW = 0.15      # Time window for simultaneous two-hand gestures
VELOCITY_WINDOW = 0.12          # Time window for calculating acceleration (seconds)

# Target positions for each direction (normalized 0-1, where 0.5 is center)
TARGET_POSITIONS = {
    "UP": (0.5, 0.25),      # Center-top
    "DOWN": (0.5, 0.75),    # Center-bottom
    "LEFT": (0.25, 0.5),    # Left-center
    "RIGHT": (0.75, 0.5)    # Right-center
}

# Hand tracking history
POSITION_HISTORY_SIZE = 20      # Number of frames to keep for velocity calculation

# Visual feedback settings
SHOW_TARGET_ZONES = True        # Draw target zones on screen
SHOW_VELOCITY_METER = True      # Show velocity indicator

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
    """Tracks a single hand's position and detects acceleration-based hits."""
    
    def __init__(self, hand_label):
        self.hand_label = hand_label  # "Left" or "Right"
        self.position_history = deque(maxlen=POSITION_HISTORY_SIZE)
        self.last_gesture_time = 0
        self.current_velocity = 0
        self.current_acceleration = 0
        
    def update(self, hand_landmarks, frame_time):
        """Update hand position and check for acceleration spike."""
        # Use palm center (landmark 0) for tracking
        palm_center = hand_landmarks.landmark[0]
        current_pos = np.array([palm_center.x, palm_center.y])
        
        # Add to history
        self.position_history.append((frame_time, current_pos))
        
        # Calculate current velocity and acceleration
        self._update_motion_metrics(frame_time)
        
        # Check if we're in cooldown
        if frame_time - self.last_gesture_time < COOLDOWN_TIME:
            return None
        
        # Detect acceleration spike at correct position
        return self._detect_acceleration_hit(current_pos, frame_time)
    
    def _update_motion_metrics(self, current_time):
        """Calculate current velocity and acceleration."""
        if len(self.position_history) < 5:
            self.current_velocity = 0
            self.current_acceleration = 0
            return
        
        # Get recent positions within velocity window
        recent = [
            (t, pos) for t, pos in self.position_history
            if current_time - t <= VELOCITY_WINDOW
        ]
        
        if len(recent) < 3:
            return
        
        # Calculate velocities between consecutive frames
        velocities = []
        for i in range(1, len(recent)):
            dt = recent[i][0] - recent[i-1][0]
            if dt > 0:
                displacement = np.linalg.norm(recent[i][1] - recent[i-1][1])
                velocities.append(displacement / dt)
        
        if velocities:
            # Current velocity is the most recent
            self.current_velocity = velocities[-1]
            
            # Acceleration is change in velocity
            if len(velocities) >= 2:
                # Compare recent velocity to earlier velocity
                recent_avg = np.mean(velocities[-2:])
                earlier_avg = np.mean(velocities[:2]) if len(velocities) > 2 else velocities[0]
                time_diff = recent[-1][0] - recent[0][0]
                if time_diff > 0:
                    self.current_acceleration = abs(recent_avg - earlier_avg) / time_diff
    
    def _detect_acceleration_hit(self, current_pos, current_time):
        """Detect if hand is at target position with acceleration spike."""
        if len(self.position_history) < 5:
            return None
        
        # Check each direction to see if hand is near target
        for direction, target_pos in TARGET_POSITIONS.items():
            distance = np.linalg.norm(current_pos - np.array(target_pos))
            
            # Is hand close enough to target?
            if distance <= POSITION_TOLERANCE:
                # Is there an acceleration spike?
                if self.current_acceleration >= ACCELERATION_THRESHOLD:
                    # Hit detected!
                    self.last_gesture_time = current_time
                    print(f"  [{self.hand_label} hand] Position: {current_pos}, "
                          f"Distance: {distance:.3f}, "
                          f"Velocity: {self.current_velocity:.2f}, "
                          f"Acceleration: {self.current_acceleration:.2f}")
                    return direction
        
        return None
    
    def get_closest_target(self, current_pos):
        """Return which target the hand is closest to (for visual feedback)."""
        min_dist = float('inf')
        closest = None
        
        for direction, target_pos in TARGET_POSITIONS.items():
            distance = np.linalg.norm(current_pos - np.array(target_pos))
            if distance < min_dist:
                min_dist = distance
                closest = direction
        
        return closest, min_dist

# ==================== VISUAL FEEDBACK ====================

def draw_target_zones(frame, width, height):
    """Draw the target zones for each direction."""
    for direction, (tx, ty) in TARGET_POSITIONS.items():
        # Convert normalized to pixel coordinates
        px = int(tx * width)
        py = int(ty * height)
        
        # Draw outer circle (tolerance zone)
        tolerance_radius = int(POSITION_TOLERANCE * width)
        cv2.circle(frame, (px, py), tolerance_radius, (100, 100, 100), 2)
        
        # Draw inner circle (center)
        cv2.circle(frame, (px, py), 10, (255, 255, 255), -1)
        
        # Draw direction label
        label_offset = tolerance_radius + 20
        label_pos = (px, py - label_offset)
        cv2.putText(frame, direction, label_pos,
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)

def draw_hand_feedback(frame, tracker, hand_landmarks, width, height):
    """Draw visual feedback for hand tracking."""
    palm = hand_landmarks.landmark[0]
    palm_pos = np.array([palm.x, palm.y])
    px = int(palm.x * width)
    py = int(palm.y * height)
    
    # Get closest target
    closest_dir, distance = tracker.get_closest_target(palm_pos)
    
    # Draw line from hand to closest target
    target_x = int(TARGET_POSITIONS[closest_dir][0] * width)
    target_y = int(TARGET_POSITIONS[closest_dir][1] * height)
    
    # Color based on distance (green when close, red when far)
    color_ratio = min(distance / POSITION_TOLERANCE, 1.0)
    color = (
        int(255 * color_ratio),        # Red increases with distance
        int(255 * (1 - color_ratio)),  # Green decreases with distance
        0
    )
    cv2.line(frame, (px, py), (target_x, target_y), color, 2)
    
    # Draw velocity meter
    if SHOW_VELOCITY_METER:
        vel_length = int(tracker.current_velocity * 100)
        accel_indicator = "!" * int(tracker.current_acceleration)
        
        # Draw velocity bar
        bar_x = px + 20
        bar_y = py
        cv2.rectangle(frame, (bar_x, bar_y - 5), (bar_x + vel_length, bar_y + 5), (0, 255, 255), -1)
        
        # Show acceleration spikes
        if tracker.current_acceleration >= ACCELERATION_THRESHOLD:
            cv2.putText(frame, "HIT!", (px - 30, py - 20),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)

# ==================== MAIN LOOP ====================

left_hand_tracker = HandTracker("Left")
right_hand_tracker = HandTracker("Right")

# Store recent gestures for simultaneous detection
recent_gestures = []  # List of (time, hand, gesture) tuples

print("=" * 60)
print("RHYTHM GAME GESTURE CONTROLLER - ACCELERATION MODE")
print("=" * 60)
print(f"Sending gestures to Godot at {GODOT_IP}:{GODOT_PORT}")
print("\nHow to play:")
print("  1. Move your hand toward the target zone (follow the arrow)")
print("  2. When the arrow reaches the target, SWIPE/ACCELERATE quickly")
print("  3. The system detects the acceleration spike for perfect timing")
print("\nControls:")
print("  - Press 'Q' to quit")
print("  - Press 'C' to calibrate (clear gesture history)")
print("  - Press 'T' to toggle target zones")
print("  - Press 'V' to toggle velocity meter")
print("=" * 60)
print("\nStarting webcam...\n")

def send_gesture_to_godot(gesture_command):
    """Send gesture command to Godot via UDP."""
    try:
        sock.sendto(gesture_command.encode(), (GODOT_IP, GODOT_PORT))
        print(f"✓ Sent: {gesture_command}")
    except Exception as e:
        print(f"✗ Error sending gesture: {e}")

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
        height, width = frame.shape[:2]
        
        # Draw target zones
        if SHOW_TARGET_ZONES:
            draw_target_zones(frame, width, height)
        
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
                tracker = None
                if hand_label == "Left":
                    tracker = left_hand_tracker
                    gesture = tracker.update(hand_landmarks, current_time)
                else:
                    tracker = right_hand_tracker
                    gesture = tracker.update(hand_landmarks, current_time)
                
                # Draw visual feedback
                draw_hand_feedback(frame, tracker, hand_landmarks, width, height)
                
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
        cv2.putText(frame, "Rhythm Game - Acceleration Mode", (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        cv2.putText(frame, "Track arrow, then SWIPE when it hits target", (10, 60),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
        cv2.putText(frame, "Q=Quit | C=Calibrate | T=Targets | V=Velocity", (10, height - 20),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
        
        # Show the frame
        cv2.imshow('Gesture Controller', frame)
        
        # Handle key presses
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q') or key == ord('Q'):
            print("\nShutting down...")
            break
        elif key == ord('c') or key == ord('C'):
            print("\n→ Calibrating... Clearing gesture history")
            left_hand_tracker.position_history.clear()
            right_hand_tracker.position_history.clear()
            recent_gestures.clear()
        elif key == ord('t') or key == ord('T'):
            SHOW_TARGET_ZONES = not SHOW_TARGET_ZONES
            print(f"→ Target zones: {'ON' if SHOW_TARGET_ZONES else 'OFF'}")
        elif key == ord('v') or key == ord('V'):
            SHOW_VELOCITY_METER = not SHOW_VELOCITY_METER
            print(f"→ Velocity meter: {'ON' if SHOW_VELOCITY_METER else 'OFF'}")

except KeyboardInterrupt:
    print("\nInterrupted by user")

finally:
    # Cleanup
    cap.release()
    cv2.destroyAllWindows()
    hands.close()
    sock.close()
    print("Gesture controller stopped.")
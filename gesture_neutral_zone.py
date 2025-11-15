"""
Rhythm Game - Tracking Loss with Neutral Zone
Player must start in NEUTRAL, move to direction, then swipe to trigger hit.
Hand must return to NEUTRAL before next input can be registered.

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

# Zone settings
NEUTRAL_ZONE_RADIUS = 0.12  # SMALLER neutral zone (easier to exit and enter)

# Tracking settings
POSITION_HISTORY_SIZE = 8
DIRECTION_DETECTION_FRAMES = 4

# Timing
SIMULTANEOUS_WINDOW = 0.20

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

# ==================== STATE MACHINE DETECTOR ====================

class NeutralZoneDetector:
    """
    State machine:
    1. WAITING_FOR_NEUTRAL - hand must return to neutral zone
    2. IN_NEUTRAL - hand is in neutral, ready to track
    3. TRACKING - hand left neutral, tracking movement
    4. After swipe (hand disappears), back to WAITING_FOR_NEUTRAL
    """
    
    def __init__(self, hand_label):
        self.hand_label = hand_label
        self.state = "WAITING_FOR_NEUTRAL"
        self.position_history = deque(maxlen=POSITION_HISTORY_SIZE)
        self.was_visible = False
        self.hit_count = 0
        
    def is_in_neutral(self, hand_landmarks):
        """Check if hand is in neutral zone."""
        palm = hand_landmarks.landmark[0]
        dx = palm.x - 0.5
        dy = palm.y - 0.5
        distance = np.sqrt(dx*dx + dy*dy)
        return distance < NEUTRAL_ZONE_RADIUS
    
    def get_zone(self, hand_landmarks):
        """Get current zone of hand."""
        palm = hand_landmarks.landmark[0]
        
        if self.is_in_neutral(hand_landmarks):
            return "NEUTRAL"
        
        dx = palm.x - 0.5
        dy = palm.y - 0.5
        
        if abs(dx) > abs(dy):
            return "RIGHT" if dx > 0 else "LEFT"
        else:
            return "DOWN" if dy > 0 else "UP"
    
    def update(self, is_visible, hand_landmarks, frame_time):
        """
        Update state machine.
        Returns (direction, state) where direction is None unless hit detected.
        """
        
        # STATE 1: WAITING_FOR_NEUTRAL
        if self.state == "WAITING_FOR_NEUTRAL":
            if is_visible and hand_landmarks:
                if self.is_in_neutral(hand_landmarks):
                    self.state = "IN_NEUTRAL"
                    self.position_history.clear()
                    print(f"  [{self.hand_label}] Entered NEUTRAL - ready!")
            return None, self.state
        
        # STATE 2: IN_NEUTRAL
        if self.state == "IN_NEUTRAL":
            if is_visible and hand_landmarks:
                palm = hand_landmarks.landmark[0]
                position = np.array([palm.x, palm.y])
                self.position_history.append((frame_time, position))
                
                # Check if left neutral zone
                if not self.is_in_neutral(hand_landmarks):
                    self.state = "TRACKING"
                    print(f"  [{self.hand_label}] Left NEUTRAL - now TRACKING")
                
                self.was_visible = True
            return None, self.state
        
        # STATE 3: TRACKING
        if self.state == "TRACKING":
            if is_visible and hand_landmarks:
                # Still tracking, add to history
                palm = hand_landmarks.landmark[0]
                position = np.array([palm.x, palm.y])
                self.position_history.append((frame_time, position))
                self.was_visible = True
            else:
                # Hand disappeared! This is a HIT!
                if self.was_visible:
                    direction = self._determine_direction()
                    if direction:
                        self.hit_count += 1
                        self.state = "WAITING_FOR_NEUTRAL"
                        self.was_visible = False
                        self.position_history.clear()
                        print(f"  [{self.hand_label}] #{self.hit_count} HIT! Direction: {direction} → Must return to NEUTRAL")
                        return direction, self.state
                
                self.was_visible = False
            
            return None, self.state
        
        return None, self.state
    
    def _determine_direction(self):
        """Determine direction from movement history."""
        if len(self.position_history) < 2:
            return None
        
        recent = list(self.position_history)[-DIRECTION_DETECTION_FRAMES:]
        if len(recent) < 2:
            return None
        
        start_pos = recent[0][1]
        end_pos = recent[-1][1]
        movement = end_pos - start_pos
        
        dx = movement[0]
        dy = movement[1]
        
        # If minimal movement, use last position relative to center
        if abs(dx) < 0.05 and abs(dy) < 0.05:
            last_pos = recent[-1][1]
            dx = last_pos[0] - 0.5
            dy = last_pos[1] - 0.5
        
        # Determine direction
        if abs(dx) > abs(dy):
            return "RIGHT" if dx > 0 else "LEFT"
        else:
            return "DOWN" if dy > 0 else "UP"
    
    def get_current_info(self, hand_landmarks):
        """Get display info about hand."""
        if hand_landmarks is None:
            return None, None
        
        zone = self.get_zone(hand_landmarks)
        palm = hand_landmarks.landmark[0]
        return zone, (palm.x, palm.y)

# ==================== VISUALIZATION ====================

def draw_neutral_zone(frame, width, height):
    """Draw the neutral zone."""
    center_x = width // 2
    center_y = height // 2
    radius = int(NEUTRAL_ZONE_RADIUS * width)
    
    # Neutral zone circle
    cv2.circle(frame, (center_x, center_y), radius, (0, 255, 0), 3)
    cv2.putText(frame, "NEUTRAL", (center_x - 50, center_y),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
    
    # Zone labels (far from center)
    label_dist = int(width * 0.35)
    
    cv2.putText(frame, "UP", (center_x - 25, center_y - label_dist),
                cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 255, 255), 3)
    cv2.putText(frame, "DOWN", (center_x - 45, center_y + label_dist),
                cv2.FONT_HERSHEY_SIMPLEX, 1.2, (255, 255, 0), 3)
    cv2.putText(frame, "LEFT", (center_x - label_dist - 70, center_y + 10),
                cv2.FONT_HERSHEY_SIMPLEX, 1.2, (255, 0, 255), 3)
    cv2.putText(frame, "RIGHT", (center_x + label_dist - 70, center_y + 10),
                cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 255, 0), 3)
    
    # Crosshairs
    cv2.line(frame, (center_x, 0), (center_x, height), (50, 50, 50), 1)
    cv2.line(frame, (0, center_y), (width, center_y), (50, 50, 50), 1)

def draw_hand_state(frame, detector, hand_landmarks, width, height):
    """Draw hand position and state."""
    if hand_landmarks is None:
        return
    
    zone, position = detector.get_current_info(hand_landmarks)
    if position is None:
        return
    
    px = int(position[0] * width)
    py = int(position[1] * height)
    
    # State colors
    state_colors = {
        "WAITING_FOR_NEUTRAL": (100, 100, 100),  # Gray - inactive
        "IN_NEUTRAL": (0, 255, 0),                # Green - ready
        "TRACKING": (0, 165, 255)                 # Orange - tracking
    }
    
    zone_colors = {
        "NEUTRAL": (0, 255, 0),
        "UP": (0, 255, 255),
        "DOWN": (255, 255, 0),
        "LEFT": (255, 0, 255),
        "RIGHT": (0, 255, 0)
    }
    
    state_color = state_colors.get(detector.state, (255, 255, 255))
    zone_color = zone_colors.get(zone, (255, 255, 255))
    
    # Draw hand indicator
    if detector.state == "WAITING_FOR_NEUTRAL":
        # Gray X - not active
        cv2.line(frame, (px - 20, py - 20), (px + 20, py + 20), state_color, 3)
        cv2.line(frame, (px + 20, py - 20), (px - 20, py + 20), state_color, 3)
        cv2.putText(frame, "RETURN TO NEUTRAL!", (px - 100, py - 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, state_color, 2)
    elif detector.state == "IN_NEUTRAL":
        # Green circle - ready
        cv2.circle(frame, (px, py), 25, state_color, 4)
        cv2.putText(frame, "READY", (px + 30, py),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, state_color, 2)
    elif detector.state == "TRACKING":
        # Orange arrow - tracking
        cv2.circle(frame, (px, py), 20, state_color, -1)
        cv2.putText(frame, f"TRACKING: {zone}", (px + 30, py),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, zone_color, 2)

def draw_ui(frame, width, height, left_detector, right_detector):
    """Draw UI."""
    cv2.putText(frame, "NEUTRAL ZONE MODE", (10, 40),
                cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2)
    cv2.putText(frame, "Start in NEUTRAL, move to zone, SWIPE to hit!", (10, 80),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
    
    total = left_detector.hit_count + right_detector.hit_count
    cv2.putText(frame, f"Hits: {total}", (10, 120),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
    
    # State indicators
    left_state_text = f"Left: {left_detector.state}"
    right_state_text = f"Right: {right_detector.state}"
    cv2.putText(frame, left_state_text, (10, 160),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    cv2.putText(frame, right_state_text, (10, 185),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    
    # Instructions
    cv2.putText(frame, "1. Start with hand in green NEUTRAL circle", (10, height - 110),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    cv2.putText(frame, "2. Move to direction zone (UP/DOWN/LEFT/RIGHT)", (10, height - 80),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    cv2.putText(frame, "3. When arrow reaches target: SWIPE FAST (hand disappears)", (10, height - 50),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    cv2.putText(frame, "4. Return to NEUTRAL before next arrow", (10, height - 20),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)

# ==================== MAIN LOOP ====================

left_detector = NeutralZoneDetector("Left")
right_detector = NeutralZoneDetector("Right")

print("=" * 60)
print("NEUTRAL ZONE MODE - Final Attempt")
print("=" * 60)
print(f"UDP: {GODOT_IP}:{GODOT_PORT}")
print("\nSTATE MACHINE:")
print("  1. WAITING_FOR_NEUTRAL → Hand must be in neutral zone")
print("  2. IN_NEUTRAL → Hand ready, can start tracking")
print("  3. TRACKING → Hand moved to direction, tracking for swipe")
print("  4. Hand disappears → HIT! Back to WAITING_FOR_NEUTRAL")
print("\nGAMEPLAY:")
print("  - Start with hand in NEUTRAL (green circle)")
print("  - Arrow appears → move hand toward that direction")
print("  - When arrow reaches target → SWIPE FAST")
print("  - Hand disappears = HIT registered")
print("  - Return to NEUTRAL for next arrow")
print("\nFOR TWO ARROWS:")
print("  - Both hands start in NEUTRAL")
print("  - Move each to its direction")
print("  - Swipe both when arrows reach targets")
print("=" * 60)
print()

def send_input(direction):
    """Send input to Godot."""
    try:
        sock.sendto(direction.encode(), (GODOT_IP, GODOT_PORT))
        print(f"✓ SENT: {direction}")
        return True
    except Exception as e:
        print(f"✗ ERROR: {e}")
        return False

# Track recent inputs
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
        
        draw_neutral_zone(frame, width, height)
        draw_ui(frame, width, height, left_detector, right_detector)
        
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = hands.process(rgb_frame)
        
        current_time = time.time()
        detected_inputs = []
        
        # Track visible hands
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
                else:
                    right_visible = True
                    right_landmarks = hand_landmarks
        
        # Update detectors
        left_direction, left_state = left_detector.update(left_visible, left_landmarks, current_time)
        right_direction, right_state = right_detector.update(right_visible, right_landmarks, current_time)
        
        # Draw hand states
        draw_hand_state(frame, left_detector, left_landmarks, width, height)
        draw_hand_state(frame, right_detector, right_landmarks, width, height)
        
        # Collect inputs
        if left_direction:
            detected_inputs.append(left_direction)
            recent_inputs.append((current_time, "Left", left_direction))
        
        if right_direction:
            detected_inputs.append(right_direction)
            recent_inputs.append((current_time, "Right", right_direction))
        
        # Send inputs
        simultaneous = check_simultaneous(current_time)
        if simultaneous:
            send_input(simultaneous)
            recent_inputs.clear()
        elif len(detected_inputs) == 1:
            send_input(detected_inputs[0])
        
        cv2.imshow('Neutral Zone Controller', frame)
        
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q') or key == ord('Q'):
            print("\nShutting down...")
            break

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


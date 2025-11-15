"""
Rhythm Game - Final Velocity Spike Controller
Detects FAST movements (acceleration spikes) rather than tracking loss
Ignores hand repositioning after swipes

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

# Velocity spike detection
VELOCITY_SPIKE_THRESHOLD = 2.5  # How fast the hand needs to move (adjust this!)
VELOCITY_WINDOW = 0.1           # Time window to measure velocity (seconds)
COOLDOWN_TIME = 0.4             # Ignore hand for this long after a hit (prevents repositioning triggers)

# Position history
POSITION_HISTORY_SIZE = 10

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

# ==================== VELOCITY SPIKE DETECTOR ====================

class VelocitySpikeDetector:
    """Detects sudden fast movements (velocity spikes) to trigger inputs."""
    
    def __init__(self, hand_label):
        self.hand_label = hand_label
        self.position_history = deque(maxlen=POSITION_HISTORY_SIZE)
        self.last_hit_time = 0
        self.hit_count = 0
        self.in_cooldown = False
        
    def update(self, hand_landmarks, frame_time):
        """Update position and check for velocity spike."""
        palm = hand_landmarks.landmark[0]
        current_pos = np.array([palm.x, palm.y])
        
        self.position_history.append((frame_time, current_pos))
        
        # Check if we're in cooldown (ignoring hand during repositioning)
        if self.in_cooldown:
            if frame_time - self.last_hit_time >= COOLDOWN_TIME:
                self.in_cooldown = False
                self.position_history.clear()  # Clear history when exiting cooldown
            return None
        
        # Detect velocity spike
        return self._detect_velocity_spike(frame_time)
    
    def _detect_velocity_spike(self, current_time):
        """Detect if hand suddenly moved fast."""
        if len(self.position_history) < 3:
            return None
        
        # Get recent positions within velocity window
        recent = [
            (t, pos) for t, pos in self.position_history
            if current_time - t <= VELOCITY_WINDOW
        ]
        
        if len(recent) < 3:
            return None
        
        # Calculate velocity (distance / time)
        start_time, start_pos = recent[0]
        end_time, end_pos = recent[-1]
        
        time_elapsed = end_time - start_time
        if time_elapsed <= 0:
            return None
        
        distance = np.linalg.norm(end_pos - start_pos)
        velocity = distance / time_elapsed
        
        # Check if velocity exceeds threshold (FAST movement detected!)
        if velocity >= VELOCITY_SPIKE_THRESHOLD:
            # Determine direction from the movement
            movement = end_pos - start_pos
            direction = self._get_direction(movement)
            
            # Register hit and enter cooldown
            self.last_hit_time = current_time
            self.in_cooldown = True
            self.hit_count += 1
            
            print(f"  [{self.hand_label}] #{self.hit_count} SPIKE! {direction} | "
                  f"Velocity: {velocity:.2f} | Now in cooldown for {COOLDOWN_TIME}s")
            
            return direction
        
        return None
    
    def _get_direction(self, movement):
        """Determine direction from movement vector."""
        dx = movement[0]
        dy = movement[1]
        
        # If barely any movement, use last known position
        if abs(dx) < 0.02 and abs(dy) < 0.02:
            if len(self.position_history) >= 2:
                recent_pos = self.position_history[-1][1]
                dx = recent_pos[0] - 0.5
                dy = recent_pos[1] - 0.5
        
        # Determine dominant direction
        if abs(dx) > abs(dy):
            return "RIGHT" if dx > 0 else "LEFT"
        else:
            return "DOWN" if dy > 0 else "UP"
    
    def get_status(self):
        """Get current velocity for display."""
        if len(self.position_history) < 2:
            return 0.0, self.in_cooldown
        
        recent = list(self.position_history)[-3:]
        if len(recent) < 2:
            return 0.0, self.in_cooldown
        
        total_distance = 0
        for i in range(1, len(recent)):
            total_distance += np.linalg.norm(recent[i][1] - recent[i-1][1])
        
        time_span = recent[-1][0] - recent[0][0]
        velocity = total_distance / time_span if time_span > 0 else 0
        
        return velocity, self.in_cooldown

# ==================== VISUALIZATION ====================

def draw_ui(frame, width, height, left_detector, right_detector):
    """Draw UI with instructions and stats."""
    cv2.putText(frame, "VELOCITY SPIKE MODE", (10, 40),
                cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2)
    cv2.putText(frame, "Move hand toward target, then SWIPE FAST!", (10, 80),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
    
    total = left_detector.hit_count + right_detector.hit_count
    cv2.putText(frame, f"Hits: {total}", (10, 120),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
    
    cv2.putText(frame, f"Spike threshold: {VELOCITY_SPIKE_THRESHOLD:.1f}", 
                (10, height - 80), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 0), 1)
    cv2.putText(frame, f"Cooldown: {COOLDOWN_TIME:.1f}s (ignores repositioning)", 
                (10, height - 50), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 0), 1)
    cv2.putText(frame, "Q=Quit | +/- = Adjust threshold", 
                (10, height - 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

def draw_hand_meter(frame, detector, hand_landmarks, width, height):
    """Show velocity meter for each hand."""
    palm = hand_landmarks.landmark[0]
    px = int(palm.x * width)
    py = int(palm.y * height)
    
    velocity, in_cooldown = detector.get_status()
    
    # Show cooldown state
    if in_cooldown:
        cv2.putText(frame, "COOLDOWN", (px - 60, py - 40),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (100, 100, 100), 2)
        return
    
    # Velocity bar
    velocity_ratio = min(velocity / VELOCITY_SPIKE_THRESHOLD, 1.0)
    bar_length = int(velocity_ratio * 100)
    
    # Color based on velocity
    if velocity >= VELOCITY_SPIKE_THRESHOLD:
        color = (0, 255, 0)  # Green - HIT!
        status = "SPIKE!"
    elif velocity >= VELOCITY_SPIKE_THRESHOLD * 0.7:
        color = (0, 255, 255)  # Yellow - almost there
        status = "FASTER"
    else:
        color = (0, 0, 255)  # Red - too slow
        status = "READY"
    
    # Draw bar
    cv2.rectangle(frame, (px - 50, py - 50), (px - 50 + bar_length, py - 40), color, -1)
    cv2.rectangle(frame, (px - 50, py - 50), (px + 50, py - 40), (100, 100, 100), 2)
    
    # Status text
    cv2.putText(frame, status, (px - 40, py - 60),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
    
    # Velocity value
    cv2.putText(frame, f"V:{velocity:.2f}", (px + 20, py - 30),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

# ==================== MAIN LOOP ====================

left_detector = VelocitySpikeDetector("Left")
right_detector = VelocitySpikeDetector("Right")

print("=" * 60)
print("VELOCITY SPIKE MODE - Final Version")
print("=" * 60)
print(f"UDP: {GODOT_IP}:{GODOT_PORT}")
print("\nHOW IT WORKS:")
print("  1. Hand position determines DIRECTION")
print("  2. FAST movement (velocity spike) triggers HIT")
print("  3. After hit, hand ignored for", COOLDOWN_TIME, "seconds")
print("  4. This prevents repositioning from triggering false hits")
print("\nGAMEPLAY:")
print("  - See arrow move toward target")
print("  - Move hand slowly in that direction")
print("  - When arrow reaches target: SWIPE FAST!")
print("  - System detects velocity spike and sends direction")
print("  - Bring hand back to center during cooldown")
print("\nADJUST SENSITIVITY:")
print("  + = Higher threshold (harder, need faster swipes)")
print("  - = Lower threshold (easier, slower swipes work)")
print("=" * 60)
print()

def send_input(direction):
    """Send input to Godot (3x for reliability)."""
    try:
        for _ in range(3):
            sock.sendto(direction.encode(), (GODOT_IP, GODOT_PORT))
        print(f"✓ SENT: {direction}")
        return True
    except Exception as e:
        print(f"✗ ERROR: {e}")
        return False

# Simultaneous gesture tracking
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
                draw_hand_meter(frame, detector, hand_landmarks, width, height)
                
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
        
        cv2.imshow('Velocity Spike Controller', frame)
        
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q') or key == ord('Q'):
            print("\nShutting down...")
            break
        elif key == ord('+') or key == ord('='):
            VELOCITY_SPIKE_THRESHOLD += 0.2
            print(f"\n→ Threshold: {VELOCITY_SPIKE_THRESHOLD:.1f} (harder)")
        elif key == ord('-') or key == ord('_'):
            VELOCITY_SPIKE_THRESHOLD = max(0.5, VELOCITY_SPIKE_THRESHOLD - 0.2)
            print(f"\n→ Threshold: {VELOCITY_SPIKE_THRESHOLD:.1f} (easier)")

except KeyboardInterrupt:
    print("\nInterrupted")

finally:
    cap.release()
    cv2.destroyAllWindows()
    hands.close()
    sock.close()
    print(f"\nSession stats:")
    print(f"  Left hand: {left_detector.hit_count}")
    print(f"  Right hand: {right_detector.hit_count}")
    print(f"  Total: {left_detector.hit_count + right_detector.hit_count}")
    print("Controller stopped.")
"""
Rhythm Game - Fist Detection Controller
Position your hand in a direction, close fist to HIT!

This is a fundamentally different approach:
- Hand POSITION = which direction
- FIST CLOSURE = when to hit

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
CENTER_ZONE_RADIUS = 0.25  # Center "neutral" zone

# Fist detection threshold
FIST_THRESHOLD = 0.3  # How closed fingers need to be (0=fully open, 1=fully closed)

# Timing
HIT_COOLDOWN = 0.3  # Time between hits (prevents double-triggering)

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

# ==================== FIST DETECTOR ====================

class FistDetector:
    """Detects hand position and fist closure."""
    
    def __init__(self, hand_label):
        self.hand_label = hand_label
        self.last_hit_time = 0
        self.hit_count = 0
        self.was_fist = False
        
    def get_fist_level(self, hand_landmarks):
        """
        Calculate how closed the fist is (0=open, 1=closed).
        Measures distance from fingertips to palm.
        """
        # Palm center (landmark 0)
        palm = hand_landmarks.landmark[0]
        
        # Fingertip landmarks: thumb=4, index=8, middle=12, ring=16, pinky=20
        fingertips = [4, 8, 12, 16, 20]
        
        # Calculate average distance from fingertips to palm
        total_distance = 0
        for tip_idx in fingertips:
            tip = hand_landmarks.landmark[tip_idx]
            distance = np.sqrt((tip.x - palm.x)**2 + (tip.y - palm.y)**2)
            total_distance += distance
        
        avg_distance = total_distance / len(fingertips)
        
        # Normalize: typical open hand ~0.3-0.4, closed fist ~0.1-0.15
        # Invert so 1=closed, 0=open
        fist_level = max(0, 1 - (avg_distance / 0.35))
        
        return fist_level
    
    def get_zone(self, hand_landmarks):
        """Determine which zone the hand is in."""
        palm = hand_landmarks.landmark[0]
        x, y = palm.x, palm.y
        
        # Distance from center
        dx = x - 0.5
        dy = y - 0.5
        distance_from_center = np.sqrt(dx*dx + dy*dy)
        
        # In center zone?
        if distance_from_center < CENTER_ZONE_RADIUS:
            return "CENTER"
        
        # Outside center - which direction?
        if abs(dx) > abs(dy):
            return "RIGHT" if dx > 0 else "LEFT"
        else:
            return "DOWN" if dy > 0 else "UP"
    
    def update(self, hand_landmarks, frame_time):
        """
        Check for fist closure in a directional zone.
        Returns direction if fist detected, None otherwise.
        """
        # Get current state
        fist_level = self.get_fist_level(hand_landmarks)
        current_zone = self.get_zone(hand_landmarks)
        is_fist = fist_level >= FIST_THRESHOLD
        
        # Check cooldown
        if frame_time - self.last_hit_time < HIT_COOLDOWN:
            return None, current_zone, fist_level
        
        # Detect fist closure (transition from open to closed)
        if is_fist and not self.was_fist:
            # Only register if outside center zone
            if current_zone != "CENTER":
                self.last_hit_time = frame_time
                self.hit_count += 1
                self.was_fist = True
                print(f"  [{self.hand_label}] #{self.hit_count} FIST! Zone: {current_zone} | Fist level: {fist_level:.2f}")
                return current_zone, current_zone, fist_level
        
        # Update state
        self.was_fist = is_fist
        
        return None, current_zone, fist_level

# ==================== VISUALIZATION ====================

def draw_zones(frame, width, height):
    """Draw the zone boundaries."""
    center_x = width // 2
    center_y = height // 2
    
    # Draw center "neutral" zone
    center_radius = int(CENTER_ZONE_RADIUS * width)
    cv2.circle(frame, (center_x, center_y), center_radius, (100, 100, 100), 2)
    cv2.putText(frame, "NEUTRAL", (center_x - 45, center_y),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (100, 100, 100), 2)
    
    # Draw zone labels
    label_distance = int(CENTER_ZONE_RADIUS * width) + 80
    
    cv2.putText(frame, "UP", (center_x - 20, center_y - label_distance),
                cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 255, 255), 2)
    cv2.putText(frame, "DOWN", (center_x - 40, center_y + label_distance),
                cv2.FONT_HERSHEY_SIMPLEX, 1.2, (255, 255, 0), 2)
    cv2.putText(frame, "LEFT", (center_x - label_distance - 60, center_y),
                cv2.FONT_HERSHEY_SIMPLEX, 1.2, (255, 0, 255), 2)
    cv2.putText(frame, "RIGHT", (center_x + label_distance - 60, center_y),
                cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 255, 0), 2)
    
    # Draw crosshairs
    cv2.line(frame, (center_x, 0), (center_x, height), (50, 50, 50), 1)
    cv2.line(frame, (0, center_y), (width, center_y), (50, 50, 50), 1)

def draw_hand_info(frame, detector, hand_landmarks, width, height, hit, zone, fist_level):
    """Show hand position, zone, and fist level."""
    palm = hand_landmarks.landmark[0]
    px = int(palm.x * width)
    py = int(palm.y * height)
    
    # Zone color
    zone_colors = {
        "CENTER": (100, 100, 100),
        "UP": (0, 255, 255),
        "DOWN": (255, 255, 0),
        "LEFT": (255, 0, 255),
        "RIGHT": (0, 255, 0)
    }
    color = zone_colors.get(zone, (255, 255, 255))
    
    # Draw circle at hand
    radius = 25 if hit else 20
    cv2.circle(frame, (px, py), radius, color, -1 if hit else 3)
    
    # Fist level bar
    bar_length = int(fist_level * 100)
    bar_color = (0, 255, 0) if fist_level >= FIST_THRESHOLD else (0, 0, 255)
    
    cv2.rectangle(frame, (px - 50, py + 40), (px - 50 + bar_length, py + 50), bar_color, -1)
    cv2.rectangle(frame, (px - 50, py + 40), (px + 50, py + 50), (100, 100, 100), 2)
    
    # Labels
    if hit:
        cv2.putText(frame, "HIT!", (px - 30, py - 35),
                    cv2.FONT_HERSHEY_SIMPLEX, 1.0, (255, 255, 255), 2)
    else:
        cv2.putText(frame, zone, (px - 30, py - 35),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
    
    # Fist level
    fist_text = "FIST" if fist_level >= FIST_THRESHOLD else "OPEN"
    cv2.putText(frame, fist_text, (px - 30, py + 70),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, bar_color, 1)

def draw_ui(frame, width, height, left_detector, right_detector):
    """Draw UI elements."""
    cv2.putText(frame, "FIST DETECTION MODE", (10, 40),
                cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2)
    cv2.putText(frame, "Position hand in direction, CLOSE FIST to hit!", (10, 80),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
    
    total = left_detector.hit_count + right_detector.hit_count
    cv2.putText(frame, f"Hits: {total}", (10, 120),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
    
    cv2.putText(frame, "1. Move hand to UP/DOWN/LEFT/RIGHT zone", (10, height - 110),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    cv2.putText(frame, "2. When arrow reaches target: CLOSE FIST", (10, height - 80),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    cv2.putText(frame, "3. Open hand and reposition for next arrow", (10, height - 50),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    cv2.putText(frame, f"Fist threshold: {FIST_THRESHOLD:.1f} | Q=Quit | +/- = Adjust", 
                (10, height - 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

# ==================== MAIN LOOP ====================

left_detector = FistDetector("Left")
right_detector = FistDetector("Right")

print("=" * 60)
print("FIST DETECTION MODE")
print("=" * 60)
print(f"UDP: {GODOT_IP}:{GODOT_PORT}")
print("\nHOW IT WORKS:")
print("  - Hand POSITION = which direction (UP/DOWN/LEFT/RIGHT)")
print("  - CLOSE FIST = trigger the hit")
print("  - System detects fist closure as the 'hit' moment")
print("\nGAMEPLAY:")
print("  1. See arrow moving toward a target")
print("  2. Move hand to that zone (watch the zones on screen)")
print("  3. When arrow REACHES target → CLOSE YOUR FIST")
print("  4. Open hand and reposition for next arrow")
print("\nFOR TWO ARROWS:")
print("  - Use BOTH hands, position each in its zone")
print("  - Close BOTH fists when arrows reach targets")
print("\nADJUST:")
print("  + = Higher threshold (need tighter fist)")
print("  - = Lower threshold (easier to trigger)")
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
                
                hit, zone, fist_level = detector.update(hand_landmarks, current_time)
                draw_hand_info(frame, detector, hand_landmarks, width, height, hit is not None, zone, fist_level)
                
                if hit:
                    detected_inputs.append(hit)
                    recent_inputs.append((current_time, hand_label, hit))
        
        # Send inputs
        simultaneous = check_simultaneous(current_time)
        if simultaneous:
            send_input(simultaneous)
            recent_inputs.clear()
        elif len(detected_inputs) == 1:
            send_input(detected_inputs[0])
        
        cv2.imshow('Fist Detection Controller', frame)
        
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q') or key == ord('Q'):
            print("\nShutting down...")
            break
        elif key == ord('+') or key == ord('='):
            FIST_THRESHOLD = min(0.9, FIST_THRESHOLD + 0.05)
            print(f"\n→ Fist threshold: {FIST_THRESHOLD:.2f} (tighter fist needed)")
        elif key == ord('-') or key == ord('_'):
            FIST_THRESHOLD = max(0.1, FIST_THRESHOLD - 0.05)
            print(f"\n→ Fist threshold: {FIST_THRESHOLD:.2f} (easier to trigger)")

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
# Rhythm-Game
CSCI 4250 HCI Rhythm Game Project

A rhythm-based game built in Godot Engine 4.5 for our CSCI 4250 - Human Computer Interaction course.  
Players must hit beats in time with the music using hand gestures detected by webcam.  
The game provides instant feedback and scoring based on timing accuracy (Perfect, Good, Miss).

## Features
- Real-time beat detection with a customizable BPM.
- Scoring and combo system with hit accuracy feedback.
- Webcam motion detection.

## How It Works
1. The Conductor emits beats based on the BPM and audio playback.
2. The WebcamInput sends hit events when motion is detected.
3. The ScoreManager compares the hit time with the closest beat to determine accuracy.
4. The FeedbackUI updates the player’s score and combo on screen.

## Requirements
- Godot Engine 4.5 or later
- Webcam (↑ ↓ ← → arrows for testing)
- A `.wav` file as the background music (add your own under `res://audio/`)
- A computer with a **Vulkan-compatible GPU**

## How to Run the Game
1. Clone the repository:
   ```bash
   git clone https://github.com/CSCI4250-HCI-Project/Rhythm-Game.git

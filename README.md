# Rhythm Game - CSCI 4250 HCI Project

A full-featured rhythm game built in Godot Engine 4.5 for CSCI 4250 - Human Computer Interaction. Players hit directional arrows in sync with music using either keyboard controls on desktop or smartphone swipe controls via network connection.

## 🎮 Game Features

### Core Gameplay
- **4-directional rhythm gameplay** (Up, Down, Left, Right arrows)
- **Chord support** - Hit multiple arrows simultaneously for complex patterns
- **Timing-based scoring** - Perfect/Good/Miss feedback with score multipliers
- **Combo system** - Chain hits together for bonus points
- **Multiple difficulty levels** - Easy, Normal, Hard with different arrow speeds
- **Song selection** - Multiple songs with custom charts
- **High score tracking** - Persistent high scores across sessions
- **Visual feedback** - Particle effects on Perfect hits, arrow flashing

### Songs Included
- "Billie Jean" by Michael Jackson
- "Rolling in the Deep" by Adele  
- "I'll Follow The Sun" by The Beatles

### Control Options

#### 1. Desktop Play (Keyboard)
- Arrow keys to hit directional notes
- Supports chord notes (multiple simultaneous arrows)

#### 2. Mobile Play (Smartphone as Controller)
- **Phone Controller App** - Swipe on your phone to control the PC game
- Swipe detection anywhere on screen (Up/Down/Left/Right)
- Multi-touch support for chord notes
- Low latency over local Wi-Fi (~10-30ms)
- Real-time visual feedback on phone

## 📋 Requirements

### For Desktop Play
- **Godot Engine 4.5** or later
- **Windows 11** (or Windows 10)
- Computer with Vulkan-compatible GPU
- Keyboard

### For Phone Controller Setup
- All desktop requirements above
- **Android smartphone** (Android 11 or later)
- **Android Studio** (for Android SDK and build tools)
- PC and phone on the **same Wi-Fi network**
- **Windows Defender Firewall** configured to allow UDP on port 5005

## 🚀 Quick Start - Desktop Play

### 1. Clone the Repository
```bash
git clone https://github.com/CSCI4250-HCI-Project/Rhythm-Game.git
cd Rhythm-Game
```

### 2. Open in Godot
- Launch **Godot 4.5**
- Click **Import**
- Navigate to the cloned repository
- Select `project.godot`
- Click **Import & Edit**

### 3. Run the Game
- Press **F5** or click the **Play** button in Godot
- Navigate through the menu:
  - Click **Start** on title screen
  - Select difficulty (Easy/Normal/Hard)
  - Choose a song
  - Play using arrow keys!

## 📱 Phone Controller Setup

Want to use your smartphone as a wireless controller? Follow these steps:

### Part 1: Setup Phone Controller App

#### 1. Install Android Studio and SDK
1. Download and install [Android Studio](https://developer.android.com/studio)
2. During setup, install:
   - Android SDK (API 30 or higher)
   - Android SDK Build-Tools 35.0.0+
   - Android SDK Platform-Tools
3. Note your SDK location (usually `C:\Users\YourName\AppData\Local\Android\Sdk`)

#### 2. Configure Godot for Android Export
1. In Godot, go to **Editor → Editor Settings**
2. Navigate to **Export → Android**
3. Set **Android SDK Path** to your SDK location
4. Download export templates: **Editor → Manage Export Templates → Download and Install**

#### 3. Create Phone Controller Project
1. Open Godot and create a **new project** named "PhoneController"
2. Copy `PhoneController.gd` from this repository into your new project folder
3. In Godot, create a new scene:
   - Scene → New Scene → **User Interface** (creates a Control node)
   - Save scene as `Controller.tscn`
4. Attach `PhoneController.gd` to the Control node
5. Set as main scene: **Project → Project Settings → Application → Run → Main Scene** = `res://Controller.tscn`

#### 4. Configure Your PC's IP Address
1. Find your PC's local IP address:
   - Open Command Prompt (Windows + R, type `cmd`, press Enter)
   - Type: `ipconfig`
   - Look for **IPv4 Address** (e.g., `192.168.1.187`)
2. Open `PhoneController.gd` in Godot
3. Change line 9 to your PC's IP:
   ```gdscript
   const PC_IP = "192.168.1.187"  # Change to YOUR PC's IP!
   ```
4. Save the file

#### 5. Setup Display Settings
1. **Project → Project Settings → Display → Window**
2. Set these values:
   - **Stretch Mode**: canvas_items
   - **Stretch Aspect**: expand
3. Close Project Settings

#### 6. Setup Android Export
1. **Project → Export → Add... → Android**
2. Configure the preset:
   - **Min SDK**: 24
   - **Target SDK**: 30
   - **Screen → Orientation**: Landscape or Portrait (your choice)
   - **Permissions → INTERNET**: ✓ Checked
3. Click **Close**

#### 7. Export Phone Controller APK
1. **Project → Export**
2. Select your Android preset
3. Click **Export Project...**
4. Name it `PhoneController.apk`
5. Save it somewhere easy to find
6. Transfer the APK to your phone and install it
   - You may need to enable "Install from Unknown Sources" in Android settings

### Part 2: Setup PC Game to Receive Controller Input

#### 1. Add UDP Receiver to Your Game
1. Open your main Rhythm Game project in Godot
2. Copy `UDPReceiver.gd` from this repository into your project folder
3. Open your main game scene (the one with ArrowGame, Center, etc.)
4. Add a new **Node** as a child of the root node
5. Rename it to "UDPReceiver"
6. Attach `UDPReceiver.gd` script to it
7. Save the scene

#### 2. Configure Windows Firewall
Your PC needs to allow UDP traffic on port 5005:

**Option A: Using Windows Defender Firewall**
1. Search for "Windows Defender Firewall" in Start menu
2. Click "Allow an app or feature through Windows Defender Firewall"
3. Click "Change settings" (may require admin)
4. Click "Allow another app..."
5. Browse to your Godot executable and add it
6. Make sure both **Private** and **Public** are checked
7. Click OK

**Option B: Using Advanced Security**
1. Open "Windows Defender Firewall with Advanced Security"
2. Click "Inbound Rules" in left sidebar
3. Click "New Rule..." in right sidebar
4. Choose **Port** → Next
5. Choose **UDP**, enter port **5005** → Next
6. Choose **Allow the connection** → Next
7. Check all three: Domain, Private, Public → Next
8. Name it "Godot Rhythm Game UDP" → Finish

### Part 3: Play with Phone Controller!

#### 1. Verify Network Connection
- Make sure your PC and phone are on the **same Wi-Fi network**
- Verify they're on the same subnet (both IPs should start with same numbers, e.g., `192.168.1.XXX`)

#### 2. Start the Game
1. Run your Rhythm Game on PC (press F5 in Godot)
2. Watch the console - you should see:
   ```
   ✓ UDP Receiver listening on port 5005
   Waiting for phone controller...
   ```

#### 3. Start Phone Controller
1. Open the PhoneController app on your phone
2. You should see:
   - "Controller Active" (green) at top
   - "Sending to: [Your PC IP]:5005" (cyan)
   - "SWIPE ANYWHERE" (white) in center
   - "Ready to swipe!" (yellow) at bottom

#### 4. Test Connection
1. Swipe on your phone (up/down/left/right)
2. Watch the PC console - you should see:
   ```
   ✓ Phone controller connected!
   Phone input received: UP → ui_up
   ```
3. If you see these messages, it's working!

#### 5. Play the Game!
1. Navigate to song selection in your PC game
2. Start a song
3. Use your phone to swipe:
   - **Swipe Up** = Hit Up arrow
   - **Swipe Down** = Hit Down arrow
   - **Swipe Left** = Hit Left arrow
   - **Swipe Right** = Hit Right arrow
   - **Two-finger swipe** = Hit chord notes

## 🎵 How to Change Arrow Speed

Arrow speeds are controlled in the chart JSON files located in `res://charts/`.

**To change speed for a specific song:**
1. Open the chart file (e.g., `I'll_Follow_The_Sun_Normal.json`)
2. Each note has a `speed` property:
   ```json
   { "time": 2000.0, "direction": "left", "type": "tap", "speed": 375.0 }
   ```
3. Change the `speed` value:
   - Higher = faster arrows
   - Lower = slower arrows
   - Typical range: 300-500

**To change base speed globally:**
1. Open `Center.gd`
2. Find the line with `base_speed` (around line 20-30)
3. Change the value (default is usually 400.0)

## 🎮 Game Controls

### Keyboard (Desktop)
- **Arrow Keys** - Hit corresponding arrows
- **Multiple Arrow Keys** - Hit chord notes
- **ESC** - Pause game

### Phone Controller
- **Swipe Up/Down/Left/Right** - Hit corresponding arrows
- **Multi-finger swipes** - Hit chord notes
- Swipe detection works anywhere on screen
- Minimum swipe distance: ~1-2 inches

## 🔧 Troubleshooting

### Phone Controller Issues

**Problem: Phone shows gray screen**
- Solution: Make sure you selected "User Interface" when creating the scene, not "2D Scene" or "Node"
- Solution: Verify Stretch Mode is set to "canvas_items" and Aspect is "expand"

**Problem: Phone not connecting to PC**
- Check both devices are on same Wi-Fi network
- Verify IP address in PhoneController.gd matches your PC's IP
- Check Windows Firewall is allowing UDP port 5005
- Try temporarily disabling Windows Firewall to test

**Problem: Phone connects but no inputs register**
- Make sure UDPReceiver.gd is attached to a node in your game scene
- Check Godot console for error messages
- Verify swipes are at least 120 pixels (~1-2 inches)

**Problem: Swipes feel laggy**
- This is likely network latency (typical is 10-30ms on local Wi-Fi)
- Make sure no other devices are heavily using the Wi-Fi
- Move closer to your Wi-Fi router
- Try 5GHz Wi-Fi if available

### Desktop Game Issues

**Problem: No sound**
- Verify audio files are in `res://assets/audio/` folder
- Check audio file format is supported (.mp3, .ogg, .wav)
- Verify AudioStreamPlayer nodes are in the scene

**Problem: Arrows not spawning**
- Check that chart JSON files exist in `res://charts/`
- Verify chart file format is correct
- Check Godot console for parsing errors

**Problem: Timer not showing**
- This is a known UI scaling issue on some displays
- Timer functionality still works even if not visible

## 📁 Project Structure

```
Rhythm-Game/
├── assets/
│   ├── audio/           # Song files (.mp3)
│   ├── images/          # Arrow sprites, backgrounds
│   └── fonts/           # UI fonts
├── charts/              # Song chart JSON files
│   ├── Billie_Jean_Easy.json
│   ├── Billie_Jean_Normal.json
│   └── ...
├── scenes/              # Godot scene files
│   ├── ArrowGame.tscn   # Main game scene
│   ├── TitleScreen.tscn
│   ├── DifficultySelection.tscn
│   └── SongSelection.tscn
├── scripts/             # GDScript files
│   ├── Center.gd        # Core game logic
│   ├── Conductor.gd     # Music timing
│   ├── ScoreManager.gd  # Scoring system
│   ├── UDPReceiver.gd   # Phone controller receiver
│   └── ...
├── PhoneController/     # Separate phone controller project
│   ├── PhoneController.gd
│   ├── Controller.tscn
│   └── project.godot
└── project.godot        # Main project file
```

## 👥 Team Members

- Gregory Treinen - [GitHub Profile]
- [Add other team members]

## 📝 License

This project is for educational purposes as part of CSCI 4250.

## 🙏 Acknowledgments

- Songs used for educational purposes only
- Built with Godot Engine 4.5
- Course: CSCI 4250 - Human Computer Interaction

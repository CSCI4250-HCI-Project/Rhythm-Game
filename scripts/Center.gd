extends TextureRect

# References to other nodes (drag these in from the editor)
@export var arrow_up: TextureRect
@export var arrow_down: TextureRect
@export var arrow_left: TextureRect
@export var arrow_right: TextureRect
@export var feedback_label: Label
@export var score_label: Label
@export var timerlabel: Label  # NEW: Now you can drag and drop!
@export var countdownlabel: Label  # NEW: Now you can drag and drop!
@export var combomilestone_label: Label  # NEW: Now you can drag and drop!
@export var music_player: AudioStreamPlayer
@export var conductor: Node

# Particle systems
@export var up_particles: GPUParticles2D
@export var down_particles: GPUParticles2D
@export var left_particles: GPUParticles2D
@export var right_particles: GPUParticles2D

# Light nodes
@export var up_light: PointLight2D
@export var down_light: PointLight2D
@export var left_light: PointLight2D
@export var right_light: PointLight2D

# Chart file path
var chart_file: String = ""

# Preload arrow textures 
@onready var arrow_up_texture = preload("res://assets/visuals/up_arrow.png") 
@onready var arrow_down_texture = preload("res://assets/visuals/down_arrow.png") 
@onready var arrow_left_texture = preload("res://assets/visuals/left_arrow.png") 
@onready var arrow_right_texture = preload("res://assets/visuals/right_arrow.png")

# References to labels (accessed via node path since Center is TextureRect)
var timer_label: Label
var countdown_label: Label
var combo_milestone_label: Label

# Movement
var arrows = {}
var target_arrow = ""
var target_position = Vector2()
var center_position = Vector2()
var speed := 400.0
var base_speed := 400.0
var active := false
var overshoot_distance := 30.0
var overshooting := false

# Countdown
var countdown_active := false
var countdown_time := 3

# Timing
var arrow_start_time := 0.0
var travel_time := 0.0
var target_reach_time := 0.0
var hit_registered := false

# NEW: Chord note tracking
var is_chord := false
var chord_directions := []
var chord_keys_hit := {}

# Chart data
var chart_data = {}
var note_queue = []
var current_note_index = 0
var song_start_time := 0.0
var song_playing := false

func set_direction(direction): 
    if direction is Array:
        texture = get_texture_for_direction(direction[0])
    elif direction is String:
        texture = get_texture_for_direction(direction)
    else:
        texture = null

func get_texture_for_direction(dir: String):
    match dir: 
        "Up", "up": 
            return arrow_up_texture 
        "Down", "down": 
            return arrow_down_texture 
        "Left", "left": 
            return arrow_left_texture 
        "Right", "right": 
            return arrow_right_texture 
        _: 
            return arrow_up_texture

func _ready():
    print("Center._ready() START")
    center_position = global_position

    arrows = {
        "Up": arrow_up.global_position,
        "Down": arrow_down.global_position,
        "Left": arrow_left.global_position,
        "Right": arrow_right.global_position,
        "up": arrow_up.global_position,
        "down": arrow_down.global_position,
        "left": arrow_left.global_position,
        "right": arrow_right.global_position
    }

    size = arrow_up.size
    ScoreManager.hit_result.connect(_on_hit_result)

    score_label.text = "Score: " + str(ScoreManager.score)
    feedback_label.text = ""

    # Get label references
    timer_label = get_node("../TimerLabel")
    countdown_label = get_node("../CountdownLabel")
    combo_milestone_label = get_node("../ComboMilestoneLabel")
    
    # Hide labels initially
    if timer_label:
        timer_label.hide()
    if combo_milestone_label:
        combo_milestone_label.hide()
    
    # Set base speed based on difficulty
    var difficulty = GameSettings.difficulty
    match difficulty:
        "Easy":
            base_speed = 300.0
        "Normal":
            base_speed = 400.0
        "Hard":
            base_speed = 500.0
        _:
            base_speed = 400.0

    chart_file = GameSettings.selected_chart
    
    print("Center.gd _ready() - Chart file: ", chart_file)
    print("Center.gd _ready() - Song file: ", GameSettings.selected_song)
    print("Center.gd _ready() - Difficulty: ", difficulty)
    print("Center.gd _ready() - Base speed: ", base_speed)

    load_chart()
    print("Chart loaded, starting countdown...")
    
    start_countdown()


func start_countdown():
    if not countdown_label:
        push_error("CountdownLabel not found!")
        start_song()
        return
    
    countdown_active = true
    countdown_label.show()
    
    # Countdown 3, 2, 1, GO!
    for i in range(3, 0, -1):
        countdown_label.text = str(i)
        countdown_label.modulate = Color(1, 1, 1, 1)
        countdown_label.scale = Vector2(2, 2)
        
        var tween = create_tween()
        tween.tween_property(countdown_label, "scale", Vector2(1, 1), 0.3)
        tween.parallel().tween_property(countdown_label, "modulate:a", 0.5, 0.8)
        
        await get_tree().create_timer(1.0).timeout
    
    # Show GO!
    countdown_label.text = "GO!"
    countdown_label.modulate = Color(0, 1, 0, 1)
    countdown_label.scale = Vector2(2.5, 2.5)
    
    var go_tween = create_tween()
    go_tween.tween_property(countdown_label, "scale", Vector2(1, 1), 0.2)
    go_tween.parallel().tween_property(countdown_label, "modulate:a", 0, 0.5)
    
    await get_tree().create_timer(0.6).timeout
    countdown_label.hide()
    countdown_active = false
    
    start_song()
    
    if timer_label:
        timer_label.show()


func load_chart():
    if chart_file == "":
        push_error("Chart file path is empty!")
        return
    
    if not FileAccess.file_exists(chart_file):
        push_error("Chart file not found: " + chart_file)
        return
    
    var file = FileAccess.open(chart_file, FileAccess.READ)
    if file == null:
        push_error("Could not open chart file: " + chart_file)
        return
    
    var json_string = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var parse_result = json.parse(json_string)
    
    if parse_result != OK:
        push_error("Failed to parse chart JSON: " + chart_file)
        return
    
    chart_data = json.data
    note_queue = chart_data.get("notes", [])
    
    print("Chart loaded: " + chart_data.get("title", "Unknown"))
    print("Total notes: " + str(note_queue.size()))


func start_song():
    print("start_song() called")
    
    if not music_player:
        push_error("music_player is null!")
        return
    
    if not chart_data.has("song_file"):
        push_error("chart_data doesn't have 'song_file' key!")
        return
    
    var song_filename = chart_data["song_file"]
    
    var possible_paths = [
        "res://assets/audio/" + song_filename,
        "res://assets/audio/songs/" + song_filename,
        "res://audio/" + song_filename,
        "res://" + song_filename,
        GameSettings.selected_song
    ]
    
    var song_path = ""
    for path in possible_paths:
        if FileAccess.file_exists(path):
            song_path = path
            break
    
    if song_path != "":
        var audio_stream = load(song_path)
        if audio_stream:
            music_player.stream = audio_stream
            music_player.play()
            song_start_time = Time.get_ticks_msec() / 1000.0
            song_playing = true
            current_note_index = 0
            print("Song started successfully!")
        else:
            push_error("Failed to load audio stream")
    else:
        push_error("Song file not found")
        song_start_time = Time.get_ticks_msec() / 1000.0
        song_playing = true
        current_note_index = 0


func lane_to_direction(lane: int) -> String:
    match lane:
        0: return "Left"
        1: return "Down"
        2: return "Up"
        3: return "Right"
        _: return "Up"


func direction_string_to_standard(dir: String) -> String:
    match dir.to_lower():
        "up": return "Up"
        "down": return "Down"
        "left": return "Left"
        "right": return "Right"
        _: return "Up"


func get_random_speed_for_difficulty() -> float:
    var difficulty = GameSettings.difficulty
    var min_speed: float
    var max_speed: float
    
    match difficulty:
        "Easy":
            min_speed = 250.0
            max_speed = 400.0
        "Normal":
            min_speed = 350.0
            max_speed = 500.0
        "Hard":
            min_speed = 450.0
            max_speed = 650.0
        _:
            min_speed = 300.0
            max_speed = 500.0
    
    return randf_range(min_speed, max_speed)


func spawn_next_arrow():
    if current_note_index >= note_queue.size():
        return
    
    var note = note_queue[current_note_index]
    
    var note_type = note.get("type", "tap")
    
    var direction
    if note.has("lane"):
        var lane = int(note.get("lane", 0))
        direction = lane_to_direction(lane)
    else:
        direction = note.get("direction", "up")
    
    if note_type == "chord":
        is_chord = true
        if direction is Array:
            chord_directions = []
            for dir in direction:
                var normalized_dir = direction_string_to_standard(str(dir))
                chord_directions.append(normalized_dir)
        else:
            chord_directions = [direction_string_to_standard(str(direction))]
        target_arrow = chord_directions
        chord_keys_hit = {}
        
    else:
        is_chord = false
        target_arrow = direction_string_to_standard(str(direction))
    
    if is_chord:
        target_position = arrows[chord_directions[0]]
    else:
        target_position = arrows[target_arrow]
    
    set_direction(target_arrow)
    
    active = true
    hit_registered = false
    arrow_start_time = Time.get_ticks_msec() / 1000.0
    
    speed = get_random_speed_for_difficulty()
    travel_time = (target_position - center_position).length() / speed
    target_reach_time = arrow_start_time + travel_time
    
    global_position = center_position
    overshooting = false
    
    current_note_index += 1


func _process(delta):
    if score_label:
        score_label.text = "Score: %d   Combo: %d" % [ScoreManager.score, ScoreManager.combo]

    # Update timer
    if song_playing and timer_label and music_player and music_player.playing:
        var time_remaining = music_player.stream.get_length() - music_player.get_playback_position()
        var minutes = int(time_remaining) / 60
        var seconds = int(time_remaining) % 60
        timer_label.text = "%d:%02d" % [minutes, seconds]

    # Check if time to spawn
    if song_playing and not active and current_note_index < note_queue.size():
        var current_song_time = Time.get_ticks_msec() / 1000.0 - song_start_time
        var next_note = note_queue[current_note_index]
        var note_time = next_note.get("time", 0.0)
        
        if note_time > 1000:
            note_time = note_time / 1000.0
        
        var spawn_speed = get_random_speed_for_difficulty()
        var spawn_travel_time = (arrows["Up"] - center_position).length() / spawn_speed
        var spawn_time = note_time - spawn_travel_time
        
        if current_song_time >= spawn_time:
            spawn_next_arrow()

    if not active:
        return

    var to_target = target_position - global_position
    var distance_to_target = to_target.length()

    if not overshooting:
        if distance_to_target > speed * delta:
            global_position += to_target.normalized() * speed * delta
        else:
            global_position = target_position
            overshooting = true
            target_reach_time = Time.get_ticks_msec() / 1000.0

    else:
        var dir = (target_position - center_position).normalized()
        var overshoot_target = target_position + dir * overshoot_distance
        var to_overshoot = overshoot_target - global_position

        if to_overshoot.length() > speed * delta:
            global_position += to_overshoot.normalized() * speed * delta
        else:
            global_position = overshoot_target

            if not hit_registered:
                ScoreManager._apply_score("Miss", 0)
                hit_registered = true
                _reset_center()
                return

    var current_time = Time.get_ticks_msec() / 1000.0
    if not hit_registered and current_time > target_reach_time + ScoreManager.MISS_WINDOW:
        ScoreManager._apply_score("Miss", 0)
        hit_registered = true
        _reset_center()


func _input(event):
    if not active:
        return
    
    if event is InputEventKey and event.pressed and not event.echo:
        var pressed_arrow = keycode_to_direction(event.keycode)
        if pressed_arrow == "":
            return
        
        if is_chord:
            if pressed_arrow in chord_directions:
                chord_keys_hit[pressed_arrow] = true
                
                if chord_keys_hit.size() == chord_directions.size():
                    var current_time = Time.get_ticks_msec() / 1000.0
                    var offset = abs(current_time - target_reach_time)
                    
                    var result = ""
                    if offset <= ScoreManager.PERFECT_WINDOW:
                        result = "Perfect"
                        ScoreManager._apply_score(result, 500)
                        for dir in chord_directions:
                            _trigger_particles(dir)
                            _flash_arrow(dir)
                    elif offset <= ScoreManager.GOOD_WINDOW:
                        result = "Good"
                        ScoreManager._apply_score(result, 200)
                    else:
                        result = "Miss"
                        ScoreManager._apply_score(result, 0)
                    
                    _show_feedback(result + " Chord!")
                    _reset_center()
                    hit_registered = true
            return
        
        if pressed_arrow == target_arrow:
            var current_time = Time.get_ticks_msec() / 1000.0
            var offset = abs(current_time - target_reach_time)

            var result = ""
            if offset <= ScoreManager.PERFECT_WINDOW:
                result = "Perfect"
                ScoreManager._apply_score(result, 300)
                _trigger_particles(pressed_arrow)
                _flash_arrow(pressed_arrow)
            elif offset <= ScoreManager.GOOD_WINDOW:
                result = "Good"
                ScoreManager._apply_score(result, 100)
            else:
                result = "Miss"
                ScoreManager._apply_score(result, 0)

            _show_feedback(result)
            _reset_center()
            hit_registered = true
        else:
            ScoreManager._apply_score("Miss", 0)
            _show_feedback("Miss")
            _reset_center()
            hit_registered = true


func keycode_to_direction(keycode: int) -> String:
    match keycode:
        Key.KEY_UP:
            return "Up"
        Key.KEY_DOWN:
            return "Down"
        Key.KEY_LEFT:
            return "Left"
        Key.KEY_RIGHT:
            return "Right"
        _:
            return ""


func _show_feedback(result: String):
    feedback_label.text = result
    score_label.text = "Score: " + str(ScoreManager.score)
    feedback_label.modulate = Color(1, 1, 1, 1)
    feedback_label.scale = Vector2(1.2, 1.2)
    feedback_label.create_tween().tween_property(feedback_label, "modulate:a", 0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _flash_arrow(arrow_name: String):
    var arrow = null
    match arrow_name:
        "Up": arrow = arrow_up
        "Down": arrow = arrow_down
        "Left": arrow = arrow_left
        "Right": arrow = arrow_right
    if arrow:
        var flash_color = Color(0.3, 0.8, 1.0, 1.0)
        var bright_flash = Color(1.5, 2.0, 2.5, 1.0)
        
        var tween = create_tween()
        tween.tween_property(arrow, "modulate", bright_flash, 0.05)
        tween.tween_property(arrow, "modulate", flash_color, 0.15)
        tween.tween_property(arrow, "modulate", Color(1, 1, 1), 0.3)


func _trigger_light(arrow_name: String):
    var light = null
    match arrow_name:
        "Up": light = up_light
        "Down": light = down_light
        "Left": light = left_light
        "Right": light = right_light
    
    if light:
        light.enabled = true
        light.energy = 2.0
        var light_tween = create_tween()
        light_tween.tween_property(light, "energy", 4.0, 0.05)
        light_tween.tween_property(light, "energy", 0.0, 0.4)
        light_tween.tween_callback(func(): light.enabled = false)


func _trigger_particles(arrow_name: String):
    var particles = null
    match arrow_name:
        "Up": particles = up_particles
        "Down": particles = down_particles
        "Left": particles = left_particles
        "Right": particles = right_particles
    
    if particles:
        particles.restart()
        particles.emitting = true


func _reset_center():
    global_position = center_position
    active = false
    is_chord = false
    chord_keys_hit = {}
    chord_directions = []


func _on_hit_result(result: String, score: int, combo: int) -> void:
    if score_label:
        score_label.text = "Score: %d   Combo: %d" % [score, combo]

    if feedback_label:
        var points = 0
        match result:
            "Perfect":
                points = 300
            "Good":
                points = 100
            "Miss":
                points = 0
        feedback_label.text = "%s  +%d" % [result, points]
        feedback_label.modulate = Color.WHITE
        feedback_label.show()
        await get_tree().create_timer(0.5).timeout
        feedback_label.hide()

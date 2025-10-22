extends TextureRect

# References to other nodes (drag these in from the editor)
@export var arrow_up: TextureRect
@export var arrow_down: TextureRect
@export var arrow_left: TextureRect
@export var arrow_right: TextureRect
@export var feedback_label: Label   # Label to show Perfect/Good/Miss
@export var score_label: Label      # Label to always show score + combo
@export var music_player: AudioStreamPlayer
@export var conductor: Node

# Movement
var arrows = {}
var target_arrow = ""
var target_position = Vector2()
var center_position = Vector2()
var speed := 400.0
var active := false
var overshoot_distance := 30.0
var overshooting := false

# Timing
var arrow_start_time := 0.0
var travel_time := 0.0
var target_reach_time := 0.0
var hit_registered := false

func _ready():
    center_position = global_position

    arrows = {
        "Up": arrow_up.global_position,
        "Down": arrow_down.global_position,
        "Left": arrow_left.global_position,
        "Right": arrow_right.global_position
    }

    ScoreManager.hit_result.connect(_on_hit_result)

    # Initialize score label
    score_label.text = "Score: " + str(ScoreManager.score)
    feedback_label.text = ""

    # Play background music
    if music_player:
        music_player.play()

    choose_random_arrow()


func choose_random_arrow():
    target_arrow = arrows.keys()[randi() % arrows.size()]
    target_position = arrows[target_arrow]
    active = true
    hit_registered = false
    arrow_start_time = Time.get_ticks_msec() / 1000.0
    travel_time = (target_position - center_position).length() / speed
    target_reach_time = arrow_start_time + travel_time
    global_position = center_position


func _process(delta):
    # Always update the visible score/combo if we have a score_label
    if score_label:
        score_label.text = "Score: %d   Combo: %d" % [ScoreManager.score, ScoreManager.combo]

    if not active:
        return

    var to_target = target_position - global_position
    var distance_to_target = to_target.length()

    # If we're still approaching the arrow (haven't reached it yet)
    if not overshooting:
        # Move toward the arrow
        if distance_to_target > speed * delta:
            global_position += to_target.normalized() * speed * delta
        else:
            # Snap to arrow and start overshoot phase
            global_position = target_position
            overshooting = true
            # Record the time when we reached the arrow (for timing checks)
            # target_reach_time should already be set in choose_random_arrow(), but update just in case
            target_reach_time = Time.get_ticks_msec() / 1000.0

    else:
        # We are in the overshoot phase: move past the arrow toward the overshoot target
        var dir = (target_position - center_position).normalized()
        var overshoot_target = target_position + dir * overshoot_distance
        var to_overshoot = overshoot_target - global_position

        if to_overshoot.length() > speed * delta:
            global_position += to_overshoot.normalized() * speed * delta
        else:
            # Reached the overshoot end; if no hit was registered, it's a miss
            global_position = overshoot_target

            if not hit_registered:
                # If the player hasn't hit, count as a Miss
                ScoreManager._apply_score("Miss", 0)
                hit_registered = true
                # Reset circle and queue next note
                _reset_circle()
                return

    # Additionally, if player is extremely late (time-based safety),
    # treat as miss even if overshoot hasn't fully completed.
    var current_time = Time.get_ticks_msec() / 1000.0
    if not hit_registered and current_time > target_reach_time + ScoreManager.MISS_WINDOW:
        ScoreManager._apply_score("Miss", 0)
        hit_registered = true
        _reset_circle()


func _input(event):
    if not active or not (event is InputEventKey and event.pressed):
        return

    var pressed_arrow = ""
    match event.keycode:
        Key.KEY_UP:
            pressed_arrow = "Up"
        Key.KEY_DOWN:
            pressed_arrow = "Down"
        Key.KEY_LEFT:
            pressed_arrow = "Left"
        Key.KEY_RIGHT:
            pressed_arrow = "Right"
        _:
            return

    if pressed_arrow == target_arrow:
        var current_time = Time.get_ticks_msec() / 1000.0
        var offset = abs(current_time - target_reach_time)

        var result = ""
        if offset <= ScoreManager.PERFECT_WINDOW:
            result = "Perfect"
            ScoreManager._apply_score(result, 300)
        elif offset <= ScoreManager.GOOD_WINDOW:
            result = "Good"
            ScoreManager._apply_score(result, 100)
        else:
            result = "Miss"
            ScoreManager._apply_score(result, 0)

        # Visual feedback
        _show_feedback(result)
        _flash_arrow(pressed_arrow)
        _reset_circle()
        hit_registered = true
    else:
        # Wrong arrow
        ScoreManager._apply_score("Miss", 0)
        _show_feedback("Miss")
        _reset_circle()
        hit_registered = true

func _show_feedback(result: String):
    feedback_label.text = result
    score_label.text = "Score: " + str(ScoreManager.score)
    feedback_label.modulate = Color(1, 1, 1, 1)  # full visible
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
        var tween = create_tween()
        tween.tween_property(arrow, "modulate", Color(1, 1, 0.5), 0.1)
        tween.tween_property(arrow, "modulate", Color(1, 1, 1), 0.3)

func _reset_circle():
    global_position = center_position
    active = false
    await get_tree().create_timer(0.3).timeout
    choose_random_arrow()


func _on_hit_result(result: String, score: int, combo: int) -> void:
    # Always-visible score & combo
    if score_label:
        score_label.text = "Score: %d   Combo: %d" % [score, combo]

    # Flash temporary feedback (Perfect/Good/Miss + points)
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

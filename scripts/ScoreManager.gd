extends Node

# Scoring thresholds (in seconds)
const PERFECT_WINDOW := 0.10
const GOOD_WINDOW := 0.25
const MISS_WINDOW := 0.40

# Score tracking
var score := 0
var combo := 0

# Emits every time the player hits (or misses)
# result: "Perfect", "Good", "Miss"
# score: total accumulated score
# combo: current combo count
signal hit_result(result: String, score: int, combo: int)

func _ready():
    print("ScoreManager initialized")

# Called when the player performs an input (keyboard or webcam)
# expected_time = beat time from Conductor
# hit_time = player's input time
func register_hit(expected_time: float, hit_time: float):
    var offset = abs(expected_time - hit_time)

    if offset <= PERFECT_WINDOW:
        _apply_score("Perfect", 300)
    elif offset <= GOOD_WINDOW:
        _apply_score("Good", 100)
    elif offset <= MISS_WINDOW:
        _apply_score("Miss", 0)
    else:
        _apply_score("Miss", 0)

func _apply_score(result: String, points: int):
    if result == "Miss":
        combo = 0
    else:
        combo += 1

    score += points
    emit_signal("hit_result", result, score, combo)

    print("Result:", result, "| Score:", score, "| Combo:", combo)

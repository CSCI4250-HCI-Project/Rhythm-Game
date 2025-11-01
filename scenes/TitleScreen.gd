extends Control

@onready var title_label = $TitleLabel
@onready var press_any_label = $PressAnyLabel
@onready var animated_gradient = $AnimatedGradient

var time_passed = 0.0
var blink_timer = 0.0

func _ready():
    # Start with animated gradient slightly transparent
    if animated_gradient:
        animated_gradient.modulate.a = 0.3

func _process(delta):
    time_passed += delta
    blink_timer += delta
    
    # Animate the gradient (pulsing light effect)
    if animated_gradient:
        var pulse = (sin(time_passed * 2.0) + 1.0) / 2.0  # Oscillates between 0 and 1
        animated_gradient.modulate.a = 0.1 + (pulse * 0.3)  # Alpha between 0.1 and 0.4
    
    # Blink the "Press Any Button" text
    if blink_timer > 0.5:  # Blink every 0.5 seconds
        press_any_label.visible = !press_any_label.visible
        blink_timer = 0.0
    
    # Add a subtle color shift to the title
    if title_label:
        var hue_shift = sin(time_passed * 0.5) * 0.2
        title_label.modulate = Color(1.0 + hue_shift, 1.0, 1.0 + hue_shift)

func _input(event):
    # Respond to any key press, mouse click, or gamepad button
    if event.is_action_pressed("ui_accept") or \
       event.is_action_pressed("ui_cancel") or \
       event is InputEventKey and event.pressed or \
       (event is InputEventMouseButton and event.pressed):
        _go_to_difficulty_selection()

func _go_to_difficulty_selection():
    # Go to difficulty selection screen
    get_tree().change_scene_to_file("res://scenes/DifficultySelection.tscn")

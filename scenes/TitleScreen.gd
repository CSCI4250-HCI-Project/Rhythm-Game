extends Control

@onready var title_label = $TitleLabel
@onready var press_any_label = $PressAnyLabel
@onready var animated_gradient = $AnimatedGradient
@onready var play_button = $PlayButton
@onready var high_scores_button = $HighScoresButton

var time_passed = 0.0
var blink_timer = 0.0
var showing_menu = false

func _ready():
	# Start with animated gradient slightly transparent
	if animated_gradient:
		animated_gradient.modulate.a = 0.3
	
	# Hide buttons initially
	if play_button:
		play_button.hide()
	if high_scores_button:
		high_scores_button.hide()
	
	# Connect button signals
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if high_scores_button:
		high_scores_button.pressed.connect(_on_high_scores_pressed)

func _process(delta):
	time_passed += delta
	blink_timer += delta
	
	# Animate the gradient (pulsing light effect)
	if animated_gradient:
		var pulse = (sin(time_passed * 2.0) + 1.0) / 2.0  # Oscillates between 0 and 1
		animated_gradient.modulate.a = 0.1 + (pulse * 0.3)  # Alpha between 0.1 and 0.4
	
	# Blink the "Press Any Button" text (only if not showing menu)
	if not showing_menu:
		if blink_timer > 0.5:  # Blink every 0.5 seconds
			press_any_label.visible = !press_any_label.visible
			blink_timer = 0.0
	
	# Add a subtle color shift to the title
	if title_label:
		var hue_shift = sin(time_passed * 0.5) * 0.2
		title_label.modulate = Color(1.0 + hue_shift, 1.0, 1.0 + hue_shift)

func _input(event):
	# Only respond to input if not already showing menu
	if not showing_menu:
		# Respond to any key press, mouse click, or gamepad button
		if event.is_action_pressed("ui_accept") or \
		   event.is_action_pressed("ui_cancel") or \
		   event is InputEventKey and event.pressed or \
		   (event is InputEventMouseButton and event.pressed):
			_show_menu()

func _show_menu():
	showing_menu = true
	
	# Hide "Press Any Button" label
	if press_any_label:
		press_any_label.hide()
	
	# Optional: Change background color/gradient
	if animated_gradient:
		var tween = create_tween()
		tween.tween_property(animated_gradient, "modulate:a", 0.6, 0.5)
	
	# Show buttons with fade-in effect
	if play_button:
		play_button.show()
		play_button.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(play_button, "modulate:a", 1.0, 0.5)
	
	if high_scores_button:
		high_scores_button.show()
		high_scores_button.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(high_scores_button, "modulate:a", 1.0, 0.5).set_delay(0.2)

func _on_play_pressed():
	# Go to DIFFICULTY selection first!
	get_tree().change_scene_to_file("res://scenes/DifficultySelection.tscn")

func _on_high_scores_pressed():
	# Go to high scores screen
	get_tree().change_scene_to_file("res://scenes/HighScores.tscn")

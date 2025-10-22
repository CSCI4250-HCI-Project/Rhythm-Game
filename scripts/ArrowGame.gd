extends Node2D

@export var note_scene: PackedScene
@export var spawn_y: float = -200.0  # Start above the screen
@export var target_y: float = 400.0  # Where the arrows are
@export var spawn_interval: float = 1.0  # seconds between notes

var spawn_timer: float = 0.0

func _process(delta):
    spawn_timer += delta
    if spawn_timer >= spawn_interval:
        spawn_timer = 0.0
        spawn_note()

func spawn_note():
    if note_scene:
        var note = note_scene.instantiate()
        note.position = Vector2(randi_range(100, 600), spawn_y)
        note.target_position = Vector2(note.position.x, target_y)
        add_child(note)

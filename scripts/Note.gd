extends Node2D

@export var target_position: Vector2
@export var speed: float = 300.0

func _process(delta):
    if position.distance_to(target_position) > 10:
        position = position.move_toward(target_position, speed * delta)
    else:
        queue_free()  # remove once it reaches the arrow

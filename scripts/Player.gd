extends CharacterBody2D
class_name ValombrePlayer

@export var move_speed := 190.0
@export var world_size := Vector2(1500.0, 1100.0)

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed
	move_and_slide()
	global_position.x = clampf(global_position.x, 35.0, world_size.x - 35.0)
	global_position.y = clampf(global_position.y, 35.0, world_size.y - 35.0)

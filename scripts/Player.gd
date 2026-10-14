extends CharacterBody2D
class_name ValombrePlayer

signal dodge_started(position: Vector2)

@export var move_speed := 190.0
@export var world_size := Vector2(1500.0, 1100.0)
var run_active := false
var dodge_time := 0.0
var dodge_cooldown := 0.0
var invulnerability := 0.0
var dodge_direction := Vector2.DOWN
var facing := Vector2.DOWN
var dodge_speed := 570.0
var dodge_duration := 0.18
var dodge_invulnerability := 0.24
var dodge_recharge := 2.6
var movement_multiplier := 1.0
var equipment_speed := 1.0
var touch_move_vector := Vector2.ZERO

func _draw() -> void:
	if dodge_time <= 0.0:
		return
	var direction := dodge_direction.normalized()
	var start := Vector2(-direction.x * 32.0 - direction.y * 7.0, -direction.y * 32.0 + direction.x * 7.0)
	var finish := -direction * 12.0
	draw_line(start, finish, Color(0.85, 0.76, 0.54, 0.53), 3.0)

func _physics_process(delta: float) -> void:
	if not run_active:
		velocity = Vector2.ZERO
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down") + touch_move_vector
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	if Input.is_action_just_pressed("dodge") and dodge_cooldown <= 0.0:
		dodge_direction = direction.normalized() if direction != Vector2.ZERO else facing
		dodge_time = dodge_duration
		dodge_cooldown = dodge_recharge
		invulnerability = maxf(invulnerability, dodge_invulnerability)
		dodge_started.emit(global_position)
	if dodge_time > 0.0:
		var step := minf(delta, dodge_time)
		velocity = dodge_direction * dodge_speed * movement_multiplier * equipment_speed * step / delta
		dodge_time -= step
	else:
		velocity = direction * move_speed * movement_multiplier * equipment_speed
		if direction != Vector2.ZERO:
			facing = direction
	move_and_slide()
	global_position.x = clampf(global_position.x, 35.0, world_size.x - 35.0)
	global_position.y = clampf(global_position.y, 35.0, world_size.y - 35.0)
	queue_redraw()

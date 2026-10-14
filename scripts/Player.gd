extends CharacterBody2D
class_name ValombrePlayer

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
var skill_dash_time := 0.0
var skill_dash_speed := 0.0
var skill_dash_direction := Vector2.DOWN

func _physics_process(delta: float) -> void:
	if not run_active:
		velocity = Vector2.ZERO
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("dodge") and dodge_cooldown <= 0.0:
		dodge_direction = direction.normalized() if direction != Vector2.ZERO else facing
		dodge_time = dodge_duration
		dodge_cooldown = dodge_recharge
		invulnerability = maxf(invulnerability, dodge_invulnerability)
	if skill_dash_time > 0.0:
		var skill_step := minf(delta, skill_dash_time)
		velocity = skill_dash_direction * skill_dash_speed * skill_step / delta
		skill_dash_time -= skill_step
	elif dodge_time > 0.0:
		var step := minf(delta, dodge_time)
		velocity = dodge_direction * dodge_speed * movement_multiplier * step / delta
		dodge_time -= step
	else:
		velocity = direction * move_speed * movement_multiplier
		if direction != Vector2.ZERO:
			facing = direction
	move_and_slide()
	global_position.x = clampf(global_position.x, 35.0, world_size.x - 35.0)
	global_position.y = clampf(global_position.y, 35.0, world_size.y - 35.0)

extends CharacterBody2D
class_name ValombrePlayer

signal dodge_started(position: Vector2)

@export var move_speed := 190.0
@export var world_size := Vector2(1500.0, 1100.0)
@export var world_edge := 71.0
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
var hammer_swing_progress := -1.0
var weapon_swing_visuals: Dictionary = {}
var shield_amount := 0.0
var shield_max_health := 100.0

func _draw() -> void:
	if shield_amount > 0.0:
		var shield_alpha := minf(0.82, 0.3 + shield_amount / maxf(1.0, shield_max_health))
		var shield_radius := 23.0 + minf(5.0, shield_amount / 10.0)
		var shield_glow := Color(0.45, 0.84, 0.9, shield_alpha * 0.22)
		draw_arc(Vector2(0.0, -3.0), shield_radius, 0.0, TAU, 48, shield_glow, 8.0, true)
		var shield_tint := Color(0.60, 0.91, 0.94, shield_alpha)
		draw_arc(Vector2(0.0, -3.0), shield_radius, 0.0, TAU, 48, shield_tint, 2.5, true)
	if dodge_time > 0.0:
		var direction := dodge_direction.normalized()
		var start := Vector2(-direction.x * 32.0 - direction.y * 7.0, -direction.y * 32.0 + direction.x * 7.0)
		var finish := -direction * 12.0
		draw_line(start, finish, Color(0.85, 0.76, 0.54, 0.53), 3.0)
	for weapon_id in weapon_swing_visuals:
		var attack: Dictionary = weapon_swing_visuals[weapon_id]
		var progress := clampf(float(attack.get("progress", 0.0)), 0.0, 1.0)
		var reach := float(attack.get("reach", 108.0))
		match str(weapon_id):
			"sabre":
				if bool(attack.get("special_slash", false)):
					_draw_sabre_special_slash(progress, reach, float(attack.get("swing_direction", -1.0)))
			"dagues": _draw_dagger_swing(progress, reach)
			"lance": _draw_lance_swing(progress, reach)
			"faux": _draw_scythe_swing(progress, reach)
	if hammer_swing_progress < 0.0:
		return
	var progress := clampf(hammer_swing_progress, 0.0, 1.0)
	var impact_alpha := 1.0 - clampf(progress / 0.62, 0.0, 1.0)
	if impact_alpha <= 0.0:
		return
	var pulse := 0.5 + 0.5 * sin(progress * 75.0)
	var impact_radius := 34.0 + pulse * 12.0
	var facing_angle := facing.angle()
	for shard in 9:
		var angle := float(shard) / 9.0 * TAU + progress * 0.4
		var inner := 5.0 + float(shard % 3) * 3.0
		var outer := impact_radius * (0.62 + float(shard % 2) * 0.34)
		var bend := (1.0 if shard % 2 == 1 else -1.0) * (0.09 + 0.035 * pulse)
		var start := Vector2(cos(facing_angle + angle), sin(facing_angle + angle)) * inner
		var middle := Vector2(cos(facing_angle + angle + bend), sin(facing_angle + angle + bend)) * ((inner + outer) * 0.52)
		var finish := Vector2(cos(facing_angle + angle - bend * 0.45), sin(facing_angle + angle - bend * 0.45)) * outer
		var alpha := impact_alpha * (0.55 + 0.45 * sin(progress * 55.0 + float(shard) * 1.4))
		var glow := Color(1.0, 0.54, 0.24, alpha * 0.28)
		var tint := Color("fff2c5") if shard % 3 == 0 else Color("ffd184")
		tint.a = alpha
		var points := PackedVector2Array([start, middle, finish])
		draw_polyline(points, glow, 7.0 + pulse * 3.0, true)
		draw_polyline(points, tint, 2.0 + pulse * 2.0, true)
		var shard_angle := progress * 18.0 + float(shard) * 2.4
		var shard_center := finish + Vector2(cos(shard_angle), sin(shard_angle)) * 3.0
		var half_size := 1.5 + pulse
		var shard_points := PackedVector2Array([
			shard_center + Vector2(-half_size, -half_size).rotated(shard_angle),
			shard_center + Vector2(half_size, -half_size).rotated(shard_angle),
			shard_center + Vector2(half_size, half_size).rotated(shard_angle),
			shard_center + Vector2(-half_size, half_size).rotated(shard_angle),
		])
		draw_colored_polygon(shard_points, Color(1.0, 0.94, 0.73, alpha))

func _draw_dagger_swing(progress: float, reach: float) -> void:
	var extension := reach * (1.0 - 0.65 * clampf(progress / 0.42, 0.0, 1.0))
	var forward := facing.normalized()
	var side_vector := Vector2(-forward.y, forward.x)
	for side in [-1.0, 1.0]:
		var start := forward * 8.0 + side_vector * side * 5.0
		var finish := forward * (8.0 + extension) + side_vector * side * 5.0
		draw_line(start, finish, Color(0.66, 1.0, 0.86, 0.38), 7.0, true)
		draw_line(start, finish, Color("effff4"), 3.5, true)
		var tip := forward * (12.0 + extension) + side_vector * side * 5.0
		var tip_points := PackedVector2Array([
			tip + forward * 3.0,
			tip - forward * 4.0 + side_vector * 3.0,
			tip - forward * 4.0 - side_vector * 3.0,
		])
		draw_colored_polygon(tip_points, Color("a9e6d0"))

func _draw_sabre_special_slash(progress: float, reach: float, direction: float) -> void:
	var blade_angle := facing.angle() + direction * (-1.3 + 2.6 * progress)
	var blade_direction := Vector2(cos(blade_angle), sin(blade_angle))
	var start := blade_direction * 12.0
	var finish := blade_direction * reach * 0.88
	draw_line(start, finish, Color(1.0, 0.78, 0.37, 0.48), 11.0, true)
	draw_line(start, finish, Color("fff0b3"), 5.0, true)

func _draw_lance_swing(progress: float, reach: float) -> void:
	var pulse := sin(progress * PI)
	var reach_point := reach * (0.48 + 0.52 * pulse)
	var forward := facing.normalized()
	var side_vector := Vector2(-forward.y, forward.x)
	var alpha := 0.55 + 0.45 * pulse
	draw_line(forward * 4.0, forward * (reach_point * 0.83), Color(0.69, 0.51, 0.37, alpha), 5.0, true)
	var tip := forward * reach_point
	var spearhead := PackedVector2Array([
		tip,
		forward * (reach_point * 0.8) - side_vector * 5.0,
		forward * (reach_point * 0.8) + side_vector * 5.0,
	])
	draw_colored_polygon(spearhead, Color(0.96, 0.91, 0.74, alpha))
	draw_polyline(PackedVector2Array([spearhead[1], spearhead[0], spearhead[2]]), Color(1.0, 0.94, 0.72, alpha * 0.8), 1.5, true)

func _draw_scythe_swing(progress: float, reach: float) -> void:
	var sweep_start := -PI + progress * TAU
	var sweep_end := sweep_start + progress * TAU
	var pulse := sin(progress * PI)
	var alpha := 0.35 + 0.6 * pulse
	var radius := reach * 0.86
	draw_arc(Vector2.ZERO, radius, sweep_start, sweep_end, 64, Color(0.66, 0.87, 0.54, alpha * 0.32), 10.0, true)
	draw_arc(Vector2.ZERO, radius, sweep_start, sweep_end, 64, Color(0.75, 0.9, 0.61, alpha), 5.0 + 3.0 * pulse, true)

func advance(delta: float) -> void:
	if not run_active:
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
		global_position += dodge_direction * dodge_speed * movement_multiplier * equipment_speed * step
		dodge_time -= step
	else:
		global_position += direction * move_speed * movement_multiplier * equipment_speed * delta
		if direction != Vector2.ZERO:
			facing = direction
	global_position.x = clampf(global_position.x, world_edge, world_size.x - world_edge)
	global_position.y = clampf(global_position.y, world_edge, world_size.y - world_edge)
	queue_redraw()

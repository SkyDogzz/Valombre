extends Node2D
class_name ValombreEnemy

var kind := "ghoul"
var hp := 1.0
var max_hp := 1.0
var radius := 14.0
var speed := 74.0
var damage := 9.0
var projectile_damage := 8.0
var heal_on_hit := 0.0
var elite := false
var elite_id := ""
var elite_color := Color("e4c978")
var elite_name := ""
var hit_flash := 0.0
var attack_cooldown := 0.0
var attack_timer := 0.8
var telegraph := 0.0
var aim_position := Vector2.ZERO
var dash_direction := Vector2.ZERO
var dash_distance_left := 0.0
var dash_time_left := 0.0
var dash_hit := false
var dash_sets_recovery := false
var dash_landing_damage := false
var dash_is_approach := false
var dash_damage := 0.0
var dash_width := 30.0
var attack_mode := "slam"
var approach_telegraph := 0.0
var approach_cooldown := 0.0
var boss_id := "guardian"
var boss_behavior := "guardian"
var slow_time := 0.0
var slow_factor := 1.0
var visual_phase := 0.0
var landing_radius := 22.0
var boss_slam_radius := 0.0
var boss_dash_distance := 0.0
var boss_charge_distance := 0.0
var boss_dash_stop_distance := 0.0
var boss_dash_width := 40.0
var boss_charge_width := 38.0
var telegraph_range := 330.0
var sprite: Sprite2D
var elite_label: Label

func configure(record_kind: String, definition: Dictionary, is_elite: bool = false) -> void:
	kind = record_kind
	hp = float(definition.get("health", 34))
	max_hp = hp
	radius = float(definition.get("radius", 14))
	speed = float(definition.get("speed", 74))
	damage = float(definition.get("damage", 9))
	elite = is_elite
	sprite = Sprite2D.new()
	var file_name := str(definition.get("sprite", "boss" if kind == "boss" else kind))
	sprite.texture = load("res://assets/%s.svg" % file_name)
	var sprite_size := 118.0 if kind == "boss" and file_name == "colossus" else 100.0 if kind == "boss" else 66.0 if kind == "brute" else 58.0 if kind == "caster" else 56.0 if kind == "leaper" else 48.0
	var texture_size := sprite.texture.get_size()
	sprite.scale = Vector2(sprite_size / texture_size.x, sprite_size / texture_size.y)
	sprite.position.y = -sprite_size * 0.28
	add_child(sprite)
	elite_label = Label.new()
	elite_label.position = Vector2(-50.0, sprite.position.y - sprite_size * 0.5 - 14.0)
	elite_label.size = Vector2(100.0, 14.0)
	elite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elite_label.add_theme_font_size_override("font_size", 10)
	elite_label.visible = false
	add_child(elite_label)
	queue_redraw()

func update_elite_label() -> void:
	elite_label.text = elite_name
	elite_label.add_theme_color_override("font_color", elite_color)
	elite_label.visible = not elite_name.is_empty()

func _draw() -> void:
	var aim := aim_position - position
	var aim_direction := aim.normalized() if aim.length_squared() > 0.001 else Vector2.RIGHT
	if dash_time_left > 0.0:
		var dash_back := -dash_direction.normalized()
		draw_line(dash_back * radius * 1.8, dash_back * radius * 0.25, Color(1.0, 0.46, 0.29, 0.7), radius * 0.8)
	if kind == "boss" and approach_telegraph > 0.0:
		var distance := minf(boss_dash_distance, maxf(0.0, aim.length() - boss_dash_stop_distance))
		_draw_lane(aim_direction, distance, boss_dash_width, Color(1.0, 0.46, 0.29, 0.18), Color(1.0, 0.59, 0.37, 0.9))
	if telegraph > 0.0:
		if kind == "boss" and boss_behavior != "volley":
			if attack_mode == "slam":
				draw_circle(Vector2.ZERO, boss_slam_radius, Color(0.75, 0.20, 0.15, 0.17))
				draw_arc(Vector2.ZERO, boss_slam_radius, 0.0, TAU, 48, Color(0.92, 0.36, 0.25, 0.82), 3.0)
			else:
				var distance := minf(boss_charge_distance, maxf(0.0, aim.length() - boss_dash_stop_distance))
				_draw_lane(aim_direction, distance, boss_charge_width, Color(1.0, 0.46, 0.29, 0.18), Color(1.0, 0.59, 0.37, 0.9))
		else:
			var warning := Color("bd79ce") if boss_behavior == "volley" or kind == "shaman" else Color("f2ae5a") if kind in ["charger", "leaper"] else Color("db5644")
			var alpha := 0.48 + sin(visual_phase * 4.0) * 0.22
			if kind == "leaper":
				var landing := aim
				draw_circle(landing, landing_radius, Color(0.95, 0.68, 0.35, 0.16))
				draw_arc(landing, landing_radius, 0.0, TAU, 36, warning, 2.0)
			elif boss_behavior == "volley":
				_draw_fan(aim_direction, 330.0, 0.2, 5, warning)
			elif kind == "shaman":
				_draw_fan(aim_direction, telegraph_range, 0.24, 3, warning)
			else:
				draw_line(Vector2.ZERO, aim, Color(warning.r, warning.g, warning.b, alpha), 5.0 if kind == "charger" else 2.0)
	if elite:
		draw_arc(Vector2.ZERO, radius + 6.0 + sin(visual_phase * 10.0) * 1.5, 0.0, TAU, 32, elite_color, 3.0)
	if bool(get_meta("sabre_mark", false)):
		draw_arc(Vector2.ZERO, radius + 5.0 + sin(visual_phase * 11.1) * 2.0, 0.0, TAU, 32, Color("ffe39a"), 2.0)
	var combo_marks := int(get_meta("sabre_combo_marks", 0))
	for mark in combo_marks:
		var angle := float(mark) / 5.0 * TAU - PI * 0.5
		draw_circle(Vector2(cos(angle), sin(angle)) * (radius + 5.0), 2.5, Color("ffb257"))
	if get_meta("dagger_bleed", null) is Dictionary:
		var pulse := 0.5 + 0.5 * sin(visual_phase * 13.3)
		draw_arc(Vector2.ZERO, radius + 3.0 + pulse * 2.0, 0.0, TAU, 32, Color(0.34, 0.94, 0.72, 0.55 + pulse * 0.4), 2.0)
	if slow_time > 0.0:
		draw_arc(Vector2.ZERO, radius + 3.0 + sin(visual_phase * 8.0), 0.0, TAU, 32, Color(0.55, 0.91, 0.96, 0.78), 2.0)
	if hit_flash > 0.0:
		draw_circle(Vector2.ZERO, radius + 2.0, Color(1.0, 0.8, 0.6, 0.3))
	if hp < max_hp:
		var bar_width := maxf(26.0, radius * 2.2)
		draw_rect(Rect2(-bar_width * 0.5, -radius - 10.0, bar_width, 3.0), Color("261b18"))
		draw_rect(Rect2(-bar_width * 0.5, -radius - 10.0, bar_width * clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0), 3.0), Color("aa4939"))

func _draw_lane(direction: Vector2, distance: float, width: float, fill: Color, outline: Color) -> void:
	var side := Vector2(-direction.y, direction.x) * width
	var end := direction * distance
	var points := PackedVector2Array([side, end + side, end - side, -side])
	draw_colored_polygon(points, fill)
	points.append(side)
	draw_polyline(points, outline, 3.0, true)

func _draw_fan(direction: Vector2, length: float, spread: float, shot_count: int, tint: Color) -> void:
	var angle := direction.angle()
	for shot in range(shot_count):
		var offset := (float(shot) - float(shot_count - 1) * 0.5) * spread
		var ray := Vector2(cos(angle + offset), sin(angle + offset))
		draw_line(Vector2.ZERO, ray * length, Color(tint.r, tint.g, tint.b, 0.7), 1.5)

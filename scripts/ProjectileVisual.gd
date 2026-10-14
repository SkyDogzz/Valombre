extends Node2D
class_name ValombreProjectileVisual

var radius := 7.0
var tint := Color("e36d5c")
var team := "enemy"
var explosive := false
var special_blast := false
var piercing := false
var lightning := false
var frost := false

func _draw() -> void:
	draw_line(Vector2(-radius * 3.0, 0.0), Vector2(-radius * 0.25, 0.0), _with_alpha(tint, 0.72), maxf(2.0, radius * 0.65))
	draw_circle(Vector2.ZERO, radius + 3.0, _with_alpha(tint, 0.10))
	draw_circle(Vector2.ZERO, radius + 1.0, _with_alpha(tint, 0.24))
	if explosive:
		draw_circle(Vector2.ZERO, radius + 1.0, tint)
		draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 28, Color("ffe18a") if special_blast else Color("ffd18a"), 1.5)
	elif lightning:
		var bolt := PackedVector2Array([
			Vector2(radius * 1.65, 0.0),
			Vector2(radius * 0.32, -radius * 0.12),
			Vector2(radius * 0.72, -radius * 0.82),
			Vector2(-radius * 0.42, radius * 0.08),
			Vector2(-radius * 0.04, radius * 0.76),
			Vector2(-radius * 1.25, radius * 0.08),
		])
		draw_colored_polygon(bolt, tint)
		draw_line(Vector2(-radius * 0.88, 0.0), Vector2(radius * 1.18, 0.0), Color("f4eaff"), maxf(1.0, radius * 0.18))
	elif frost:
		var crystal := PackedVector2Array([
			Vector2(radius * 1.55, 0.0),
			Vector2(radius * 0.45, -radius * 0.38),
			Vector2(radius * 0.1, -radius * 0.98),
			Vector2(-radius * 0.52, -radius * 0.42),
			Vector2(-radius * 1.12, 0.0),
			Vector2(-radius * 0.52, radius * 0.42),
			Vector2(radius * 0.1, radius * 0.98),
			Vector2(radius * 0.45, radius * 0.38),
		])
		draw_colored_polygon(crystal, tint)
		draw_circle(Vector2.ZERO, radius * 0.24, Color("e8fdff"))
	elif team == "player":
		var arrow := PackedVector2Array([
			Vector2(radius * 1.7, 0.0),
			Vector2(-radius * 0.6, -radius * 0.72),
			Vector2(-radius * 0.2, 0.0),
			Vector2(-radius * 0.6, radius * 0.72),
		])
		draw_colored_polygon(arrow, tint)
	else:
		draw_circle(Vector2.ZERO, radius, tint)
	if piercing:
		draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 28, Color("fff0bd"), 1.5)

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)

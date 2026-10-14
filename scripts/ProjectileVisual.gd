extends Node2D
class_name ValombreProjectileVisual

var radius := 7.0
var tint := Color("e36d5c")
var team := "enemy"
var explosive := false
var special_blast := false
var piercing := false

func _draw() -> void:
	draw_line(Vector2(-radius * 3.0, 0.0), Vector2(-radius * 0.25, 0.0), _with_alpha(tint, 0.72), maxf(2.0, radius * 0.65))
	draw_circle(Vector2.ZERO, radius + 3.0, _with_alpha(tint, 0.10))
	draw_circle(Vector2.ZERO, radius + 1.0, _with_alpha(tint, 0.24))
	if explosive:
		draw_circle(Vector2.ZERO, radius + 1.0, tint)
		draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 28, Color("ffe18a") if special_blast else Color("ffd18a"), 1.5)
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

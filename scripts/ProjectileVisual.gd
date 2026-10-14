extends Node2D
class_name ValombreProjectileVisual

var radius := 7.0
var tint := Color("e36d5c")

func _draw() -> void:
	draw_line(Vector2(-radius * 3.0, 0.0), Vector2(-radius * 0.25, 0.0), Color(tint, 0.72), maxf(2.0, radius * 0.65))
	draw_circle(Vector2.ZERO, radius + 3.0, Color(tint, 0.12))
	draw_circle(Vector2.ZERO, radius + 1.0, Color(tint, 0.28))
	draw_circle(Vector2.ZERO, radius, tint)

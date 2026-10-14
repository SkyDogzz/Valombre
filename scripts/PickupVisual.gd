extends Node2D
class_name ValombrePickupVisual

var tint := Color("d9a2ff")
var icon_size := 24.0
var shadow_blur := 28.0

func configure(texture_path: String, pickup_type: String) -> void:
	var icon := Sprite2D.new()
	match pickup_type:
		"weapon":
			tint = Color("85c5b3")
			icon_size = 22.0
			shadow_blur = 10.0
		"relic":
			tint = Color("d6b765")
			icon_size = 22.0
			shadow_blur = 10.0
	icon.texture = load(texture_path)
	var texture_size := icon.texture.get_size()
	icon.scale = Vector2(icon_size / texture_size.x, icon_size / texture_size.y)
	add_child(icon)
	queue_redraw()

func _draw() -> void:
	var icon_radius := 2.5 if icon_size >= 24.0 else icon_size * 0.5
	draw_circle(Vector2.ZERO, icon_radius + shadow_blur * 0.75, _with_alpha(tint, 0.045))
	draw_circle(Vector2.ZERO, icon_radius + shadow_blur * 0.38, _with_alpha(tint, 0.085))
	draw_circle(Vector2.ZERO, icon_radius + shadow_blur * 0.14, _with_alpha(tint, 0.16))

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)

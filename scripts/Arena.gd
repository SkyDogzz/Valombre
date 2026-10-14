extends Node2D
class_name Arena

const WORLD_SIZE := Vector2(1500.0, 1100.0)
const OBSTACLES := [
	Vector3(605.0, 530.0, 27.0),
	Vector3(898.0, 605.0, 31.0),
	Vector3(770.0, 415.0, 23.0),
	Vector3(735.0, 705.0, 24.0),
]

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	_draw_ground()
	_draw_ruins()
	_draw_props()
	_draw_obstacles()

func _draw_ground() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("22251b"), true)
	for y in range(0, int(WORLD_SIZE.y), 64):
		for x in range(0, int(WORLD_SIZE.x), 64):
			var noise := _noise(float(x) * 12.9898, float(y) * 78.233)
			var ground := Color("292a1f") if noise > 0.87 else Color("1e2119") if noise < 0.12 else Color("24261d")
			draw_rect(Rect2(x, y, 63, 63), ground, true)
			if noise > 0.78:
				draw_rect(Rect2(x + 13, y + 19, 2, 2), Color("3c3a2b"), true)
				draw_rect(Rect2(x + 42, y + 47, 3, 2), Color("3c3a2b"), true)

func _draw_ruins() -> void:
	draw_rect(Rect2(565, 395, 370, 310), Color("343126"), true)
	draw_rect(Rect2(572, 402, 356, 296), Color("302e23"), true)
	draw_rect(Rect2(572, 402, 356, 296), Color("494332"), false, 3.0)
	var dash_color := Color("3d392a")
	for x in range(632, 869, 14):
		draw_line(Vector2(x, 453), Vector2(minf(x + 5, 868), 453), dash_color, 2.0)
		draw_line(Vector2(x, 647), Vector2(minf(x + 5, 868), 647), dash_color, 2.0)
	for y in range(462, 641, 14):
		draw_line(Vector2(632, y), Vector2(632, minf(y + 5, 640)), dash_color, 2.0)
		draw_line(Vector2(868, y), Vector2(868, minf(y + 5, 640)), dash_color, 2.0)
	var border := Rect2(Vector2(6, 6), WORLD_SIZE - Vector2(12, 12))
	draw_rect(border, Color("62583e"), false, 12.0)
	draw_rect(border, Color("25251d"), false, 4.0)

func _draw_props() -> void:
	for y in range(55, int(WORLD_SIZE.y), 88):
		for x in range(55, int(WORLD_SIZE.x), 96):
			var noise := _noise(float(x) * 24.1, float(y) * 8.7)
			if noise > 0.87 or Vector2(x, y).distance_to(WORLD_SIZE * 0.5) < 245.0:
				continue
			var center := Vector2(float(x) + sin(float(y)) * 15.0, float(y) + cos(float(x)) * 12.0)
			var radius := 10.0 + noise * 12.0
			_draw_ellipse(center + Vector2(0, 7), Vector2(radius * 1.2, radius * 0.48), Color("151811"))
			draw_circle(center, radius, Color("343025") if noise > 0.94 else Color("303426"))
			draw_circle(center - Vector2(radius * 0.25, radius * 0.3), radius * 0.58, Color("424331"))
			draw_line(center + Vector2(-radius * 0.8, radius * 0.25), center + Vector2(radius * 0.8, -radius * 0.25), Color("594c33"), 2.0)

func _draw_obstacles() -> void:
	for obstacle in OBSTACLES:
		var center := Vector2(obstacle.x, obstacle.y)
		var radius: float = obstacle.z
		_draw_ellipse(center + Vector2(0, 8), Vector2(radius * 1.3, radius * 0.55), Color("161712"))
		draw_circle(center, radius, Color("4a4737"))
		draw_circle(center - Vector2(radius * 0.3, radius * 0.35), radius * 0.55, Color("66604a"))

func _draw_ellipse(center: Vector2, radii: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for index in 16:
		var angle := TAU * float(index) / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, tint)

func _noise(x: float, y: float) -> float:
	var value := sin(x + y) * 43758.5453
	return value - floorf(value)

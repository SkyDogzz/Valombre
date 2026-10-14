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
	_build_obstacles()
	queue_redraw()

func _draw() -> void:
	# A deliberately quiet base layer; detailed scenery and lighting are added in the art pass.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("252b24"), true)
	draw_rect(Rect2(Vector2(35, 35), WORLD_SIZE - Vector2(70, 70)), Color("30372d"), true)
	for x in range(65, int(WORLD_SIZE.x), 100):
		for y in range(65, int(WORLD_SIZE.y), 100):
			var seed_value := x * 37 + y * 71
			var center := Vector2(x + (seed_value % 23), y + (seed_value % 17))
			draw_circle(center, 1.5 + float(seed_value % 4), Color(0.48, 0.48, 0.35, 0.11))
	draw_rect(Rect2(Vector2(35, 35), WORLD_SIZE - Vector2(70, 70)), Color("71694d"), false, 5.0)
	for obstacle in OBSTACLES:
		var center := Vector2(obstacle.x, obstacle.y)
		draw_circle(center + Vector2(3, 5), obstacle.z + 8.0, Color(0.07, 0.08, 0.065, 0.46))
		draw_circle(center, obstacle.z + 7.0, Color("4a493b"))
		draw_circle(center, obstacle.z, Color("68624b"))
		draw_arc(center, obstacle.z - 3.0, 0.0, TAU, 32, Color("8b805d"), 2.0)

func _build_obstacles() -> void:
	for obstacle in OBSTACLES:
		var body := StaticBody2D.new()
		body.position = Vector2(obstacle.x, obstacle.y)
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = obstacle.z
		shape.shape = circle
		body.add_child(shape)
		add_child(body)

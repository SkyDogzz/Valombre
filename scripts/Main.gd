extends Node2D

const PLAYER_SPEED := 190.0
const WORLD_SIZE := Vector2(1500.0, 1100.0)

var catalog := ContentCatalog.new()

func _enter_tree() -> void:
	if not catalog.load_content():
		push_error("Content validation failed: %s" % "; ".join(catalog.validation_errors))

func _ready() -> void:
	_configure_player()
	_build_camera()

func _configure_player() -> void:
	var player: ValombrePlayer = $Arena/Player
	player.position = WORLD_SIZE * 0.5
	player.move_speed = float(catalog.section("config").get("player", {}).get("speed", PLAYER_SPEED))
	player.world_size = WORLD_SIZE
	var shape: CollisionShape2D = $Arena/Player/CollisionShape2D
	var capsule := CircleShape2D.new()
	capsule.radius = 12.0
	shape.shape = capsule
	var sprite: Sprite2D = $Arena/Player/Sprite2D
	sprite.texture = load("res://assets/hero.svg")
	sprite.scale = Vector2(0.75, 0.75)

func _build_camera() -> void:
	var camera: Camera2D = $Arena/Player/Camera2D
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)

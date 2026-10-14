extends Node2D

const PLAYER_SPEED := 190.0
const WORLD_SIZE := Vector2(1500.0, 1100.0)

var catalog := ContentCatalog.new()

func _ready() -> void:
	if not catalog.load_content():
		push_error("Content validation failed: %s" % "; ".join(catalog.validation_errors))
	_configure_player()
	_build_camera()
	_build_hud()

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
	sprite.scale = Vector2(0.62, 0.62)

func _build_camera() -> void:
	var camera: Camera2D = $Arena/Player/Camera2D
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.position = Vector2(20, 16)
	label.text = "LES CENDRES DE VALOMBRE\nWASD / flèches — se déplacer"
	label.add_theme_color_override("font_color", Color("eee2c5"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(label)
	add_child(layer)

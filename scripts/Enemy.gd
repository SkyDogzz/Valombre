extends Node2D
class_name ValombreEnemy

var kind := "ghoul"
var hp := 1.0
var max_hp := 1.0
var radius := 14.0
var speed := 74.0
var damage := 9.0
var elite := false
var hit_flash := 0.0
var attack_cooldown := 0.0
var sprite: Sprite2D

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
	var diameter := radius * 2.0
	var texture_size := sprite.texture.get_size()
	sprite.scale = Vector2.ONE * diameter / maxf(texture_size.x, texture_size.y)
	add_child(sprite)
	queue_redraw()

func _process(delta: float) -> void:
	hit_flash = maxf(0.0, hit_flash - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	queue_redraw()

func _draw() -> void:
	if elite:
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 28, Color("e4c978"), 2.0)
	if hit_flash > 0.0:
		draw_circle(Vector2.ZERO, radius + 2.0, Color(1.0, 0.8, 0.6, 0.3))
	var bar_width := maxf(26.0, radius * 2.2)
	draw_rect(Rect2(-bar_width * 0.5, -radius - 10.0, bar_width, 3.0), Color("261b18"))
	draw_rect(Rect2(-bar_width * 0.5, -radius - 10.0, bar_width * clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0), 3.0), Color("bd5849"))

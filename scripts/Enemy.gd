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

func _draw() -> void:
	if telegraph > 0.0 or approach_telegraph > 0.0:
		draw_line(Vector2.ZERO, aim_position - position, Color(1.0, 0.35, 0.24, 0.72), 2.0)
		draw_arc(aim_position - position, 18.0, 0.0, TAU, 24, Color(1.0, 0.35, 0.24, 0.82), 2.0)
	if elite:
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 28, elite_color, 2.0)
	if hit_flash > 0.0:
		draw_circle(Vector2.ZERO, radius + 2.0, Color(1.0, 0.8, 0.6, 0.3))
	var bar_width := maxf(26.0, radius * 2.2)
	draw_rect(Rect2(-bar_width * 0.5, -radius - 10.0, bar_width, 3.0), Color("261b18"))
	draw_rect(Rect2(-bar_width * 0.5, -radius - 10.0, bar_width * clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0), 3.0), Color("bd5849"))

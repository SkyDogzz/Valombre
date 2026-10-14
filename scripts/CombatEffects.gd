extends Node2D
class_name ValombreCombatEffects

var effects: Array[Dictionary] = []
var lightning_arcs: Array[Dictionary] = []

func add_effect(effect: Dictionary) -> void:
	var visual := effect.duplicate(true)
	visual.max_life = float(visual.get("max_life", visual.get("life", 0.0)))
	visual.persistent_lifetime = str(visual.get("kind", "")) == "bomb_burn" or str(visual.get("kind", "")) == "lightning_zone"
	effects.append(visual)
	queue_redraw()

func update_persistent_effect(source: Dictionary) -> void:
	var kind := str(source.get("kind", ""))
	if kind != "bomb_burn" and kind != "lightning_zone":
		return
	for index in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[index]
		if str(effect.get("kind", "")) != kind or effect.get("position", Vector2.ZERO) != source.get("position", Vector2.ZERO):
			continue
		effect.life = float(source.life)
		effect.tick = float(source.tick)
		effects[index] = effect
		break
	queue_redraw()

func add_lightning_arc(from: Vector2, to: Vector2) -> void:
	lightning_arcs.append({"from": from, "to": to, "life": 0.16, "max_life": 0.16})
	queue_redraw()

func clear() -> void:
	effects.clear()
	lightning_arcs.clear()
	queue_redraw()

func _process(delta: float) -> void:
	for index in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[index]
		if float(effect.get("delay", 0.0)) > 0.0:
			effect.delay = maxf(0.0, float(effect.delay) - delta)
			effects[index] = effect
			continue
		if not bool(effect.get("persistent_lifetime", false)):
			effect.life = float(effect.life) - delta
			if float(effect.life) <= 0.0:
				effects.remove_at(index)
				continue
		effects[index] = effect
	for index in range(lightning_arcs.size() - 1, -1, -1):
		var arc: Dictionary = lightning_arcs[index]
		arc.life = float(arc.life) - delta
		if float(arc.life) <= 0.0:
			lightning_arcs.remove_at(index)
		else:
			lightning_arcs[index] = arc
	queue_redraw()

func _draw() -> void:
	for effect in effects:
		if float(effect.get("delay", 0.0)) > 0.0:
			continue
		_draw_effect(effect)
	for arc in lightning_arcs:
		_draw_lightning_arc(arc)

func _draw_effect(effect: Dictionary) -> void:
	var kind := str(effect.kind)
	var center: Vector2 = effect.get("position", Vector2.ZERO)
	var radius := float(effect.get("radius", 0.0))
	var life := float(effect.life)
	var max_life := maxf(0.001, float(effect.get("max_life", effect.life)))
	var progress := clampf(1.0 - life / max_life, 0.0, 1.0)
	if bool(effect.get("persistent_lifetime", false)) and life <= 0.0:
		return
	match kind:
		"drop_trail":
			var from: Vector2 = effect.from
			var to: Vector2 = effect.to
			var tint: Color = effect.tint
			var alpha := clampf(life / max_life, 0.0, 1.0)
			draw_line(from, to, _with_alpha(tint, alpha * 0.28), 5.0, true)
			draw_line(from, to, _with_alpha(tint, alpha * 0.68), 2.0, true)
		"hammer_wave":
			if not bool(effect.get("full_circle", false)):
				return
			var wave_radius := float(effect.outer) * progress
			var alpha := 1.0 - progress * 0.55
			draw_arc(center, wave_radius, 0.0, TAU, 48, Color(1.0, 0.90, 0.63, alpha), 5.0 * (1.0 - progress) + 1.0)
			for ray in 12:
				var angle := float(ray) / 12.0 * TAU + progress * 0.14
				draw_line(center + Vector2(cos(angle), sin(angle)) * wave_radius * 0.72, center + Vector2(cos(angle), sin(angle)) * wave_radius, Color(1.0, 0.90, 0.63, alpha), 2.0)
		"hammer_shockwave":
			draw_arc(center, radius * progress, 0.0, TAU, 48, Color(1.0, 0.94, 0.74, 0.82 * (1.0 - progress)), 4.0 * (1.0 - progress) + 1.0)
		"sabre_burst", "frost_nova":
			var tint := Color("a3f4ff") if kind == "frost_nova" else Color("ffc16a")
			var wave_radius := radius * progress
			draw_circle(center, wave_radius, _with_alpha(tint, 0.10 * (1.0 - progress)))
			draw_arc(center, wave_radius, 0.0, TAU, 48, _with_alpha(tint, 1.0 - progress), 4.0 * (1.0 - progress) + 1.0)
			for ray in 8:
				var angle := float(ray) / 8.0 * TAU + progress * 0.25
				draw_line(center + Vector2(cos(angle), sin(angle)) * wave_radius * 0.55, center + Vector2(cos(angle), sin(angle)) * wave_radius, _with_alpha(tint, 1.0 - progress), 2.0)
		"scythe_wave":
			var wave_radius := radius * progress
			var tint := Color("c9f09e")
			draw_arc(center, wave_radius, 0.0, TAU, 48, _with_alpha(tint, 1.0 - progress), 5.0 * (1.0 - progress) + 1.0)
			var ray_count := 8 + int(effect.get("souls", 0)) * 2
			for ray in ray_count:
				var angle := float(ray) / float(ray_count) * TAU + progress * 0.4
				draw_line(center + Vector2(cos(angle), sin(angle)) * wave_radius * 0.72, center + Vector2(cos(angle), sin(angle)) * wave_radius, _with_alpha(tint, 1.0 - progress), 2.0)
		"bomb_explosion":
			var reach := radius * (1.0 - pow(1.0 - progress, 3.0))
			var special := bool(effect.get("special", false))
			var fill := Color(1.0, 0.70, 0.29, 0.24) if special else Color(0.94, 0.39, 0.24, 0.20)
			var outline := Color(1.0, 0.94, 0.63, 1.0 - progress) if special else Color(1.0, 0.73, 0.41, 1.0 - progress)
			draw_circle(center, reach, _with_alpha(fill, 1.0 - progress))
			draw_arc(center, reach, 0.0, TAU, 48, outline, 4.0 * (1.0 - progress) + 1.0)
			for ray in 10:
				var angle := float(ray) / 10.0 * TAU + progress * 0.22
				var inner := reach * (0.54 + float(ray % 3) * 0.07)
				var outer := reach * (0.82 + float(ray % 2) * 0.14)
				draw_line(center + Vector2(cos(angle), sin(angle)) * inner, center + Vector2(cos(angle), sin(angle)) * outer, Color(1.0, 0.94, 0.76, 1.0 - progress), 2.0)
		"bomb_burn":
			var pulse := 0.94 + sin(float(Time.get_ticks_msec()) / 40.0) * 0.06
			var alpha := minf(0.72, life / max_life)
			draw_circle(center, radius * pulse, Color(0.91, 0.36, 0.19, alpha * 0.16))
			draw_arc(center, radius * pulse, 0.0, TAU, 48, Color(1.0, 0.68, 0.31, alpha), 2.0)
			for spark in 7:
				var angle := float(Time.get_ticks_msec()) / 190.0 + float(spark) / 7.0 * TAU
				var distance := radius * (0.56 + float(spark % 3) * 0.1)
				draw_circle(center + Vector2(cos(angle), sin(angle)) * distance, 2.0, Color("ffe28a") if spark % 2 == 0 else Color("ffb04d"))
		"lightning_zone":
			var pulse := 1.0 + sin(float(Time.get_ticks_msec()) / 45.0) * 0.12
			var alpha := minf(1.0, life / 0.3)
			draw_circle(center, radius * pulse, Color(0.66, 0.54, 1.0, 0.13 * alpha))
			draw_arc(center, radius * pulse, 0.0, TAU, 48, Color(0.85, 0.77, 1.0, alpha), 3.0)
			for bolt in 4:
				var angle := float(Time.get_ticks_msec()) / 170.0 + float(bolt) * PI * 0.5
				draw_line(center + Vector2(cos(angle), sin(angle)) * 7.0, center + Vector2(cos(angle), sin(angle)) * radius * 0.8, _with_alpha(Color("d8c4ff"), alpha), 2.0)

func _draw_lightning_arc(arc: Dictionary) -> void:
	var start: Vector2 = arc.from
	var finish: Vector2 = arc.to
	var points := PackedVector2Array([start])
	var phase := float(Time.get_ticks_msec()) / 35.0
	for segment in range(1, 5):
		var progress := float(segment) / 5.0
		var offset := Vector2(sin(phase + float(segment) * 3.1), cos(phase * 0.83 + float(segment) * 2.2)) * 9.0
		points.append(start.lerp(finish, progress) + offset)
	points.append(finish)
	var alpha := minf(1.0, float(arc.life) / 0.16)
	draw_polyline(points, Color("a88aff", alpha * 0.14), 18.0, true)
	draw_polyline(points, Color("c6a6ff", alpha * 0.24), 8.0, true)
	draw_polyline(points, Color("c6a6ff", alpha), 3.0, true)

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)

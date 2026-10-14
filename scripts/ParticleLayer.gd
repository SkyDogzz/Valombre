extends Node2D
class_name ValombreParticleLayer

var particles: Array[Dictionary] = []

func burst(position: Vector2, tint: Color, count: int, rng: RandomNumberGenerator) -> void:
	for _index in count:
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(35.0, 150.0)
		particles.append({
			"position": position,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"life": rng.randf_range(0.18, 0.5),
			"color": tint,
		})
	queue_redraw()

func clear() -> void:
	particles.clear()
	queue_redraw()

func advance(delta: float) -> void:
	for index in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[index]
		particle.life = float(particle.life) - delta
		if float(particle.life) <= 0.0:
			particles.remove_at(index)
			continue
		particle.position = particle.position + particle.velocity * delta
		particle.velocity = particle.velocity * 0.94
		particles[index] = particle
	queue_redraw()

func _draw() -> void:
	for particle in particles:
		var tint: Color = particle.color
		tint.a = clampf(float(particle.life) * 3.0, 0.0, 1.0)
		draw_circle(particle.position, 2.2, tint)

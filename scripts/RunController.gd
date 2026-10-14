extends Node
class_name RunController

const ENEMY_SCRIPT := preload("res://scripts/Enemy.gd")
const WORLD_SIZE := Vector2(1500.0, 1100.0)
const OBSTACLES := [Vector3(605, 530, 27), Vector3(898, 605, 31), Vector3(770, 415, 23), Vector3(735, 705, 24)]

var main: Node2D
var arena: Arena
var player: ValombrePlayer
var catalog: ContentCatalog
var state := "title"
var hero_id := "pilgrim"
var weapon_id := "sabre"
var mode := "waves"
var difficulty_id := "insane"
var wave := 0
var defeated := 0
var hp := 100.0
var max_hp := 100.0
var base_hp := 100.0
var bonus_max_hp := 0.0
var xp := 0.0
var next_xp := 5.0
var level := 1
var damage_multiplier := 1.0
var attack_speed_multiplier := 1.0
var range_bonus := 0.0
var movement_multiplier := 1.0
var defense := 0.0
var pickup_range := 90.0
var pickup_range_multiplier := 1.0
var upgrade_ranks := {"damage": 0, "attackSpeed": 0, "range": 0, "projectileSize": 0, "projectileSpeed": 0, "movementSpeed": 0, "health": 0, "defense": 0, "pickupRange": 0}
var pending_upgrades := 0
var weapon_cooldown := 0.0
var spawn_clock := 1.0
var intermission := 0.0
var contact_cooldown := 0.0
var skill_cooldown := 0.0
var pending_spawns: Array[Dictionary] = []
var wave_groups: Array[Dictionary] = []
var swarm_timer := -1.0
var boss_after_wave_id := ""
var enemies: Array[ValombreEnemy] = []
var drops: Array[Dictionary] = []
var weapon_inventory: Array[Dictionary] = []
var relic_inventory: Array[Dictionary] = []
var weapon_cooldowns: Dictionary = {}
var equipment_damage := 1.0
var equipment_speed := 1.0
var equipment_range := 0.0
var equipment_defense := 0.0
var equipment_xp := 1.0
var equipment_lifesteal := 0.0
var global_pickup := false
var player_shield := 0.0
var scythe_souls := 0
var weapon_swing_counts: Dictionary = {}
var projectiles: Array[Dictionary] = []
var projectile_size_multiplier := 1.0
var projectile_speed_multiplier := 1.0
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var objective_type := "kills"
var objective_progress := 0
var objective_target := 12
var objective_complete := false
var run_challenges: Array[Dictionary] = []
var profile := {"schema_version": 1, "wins": 0, "bestKills": 0, "shards": 0}
var result_recorded := false

var layer: CanvasLayer
var menu_panel: PanelContainer
var title_label: Label
var status_label: Label
var picker_labels: Array[Label] = []
var hero_picker: OptionButton
var weapon_picker: OptionButton
var mode_picker: OptionButton
var difficulty_picker: OptionButton
var start_button: Button
var hud: Label
var boss_bar: ProgressBar
var boss_name_label: Label

func _ready() -> void:
	main = get_parent()
	arena = main.get_node("Arena")
	player = arena.get_node("Player")
	catalog = main.catalog
	_load_profile()
	rng.randomize()
	_create_interface()
	player.run_active = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == "playing":
			_set_state("paused")
		elif state == "paused":
			_set_state("playing")
		elif state in ["victory", "defeat"]:
			_set_state("title")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and state == "playing":
		status_label.text = _inventory_summary()
		status_label.visible = not status_label.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("special") and state == "playing":
		_use_hero_skill()

func _process(delta: float) -> void:
	if state != "playing":
		return
	elapsed += delta
	weapon_cooldown = maxf(0.0, weapon_cooldown - delta)
	for id in weapon_cooldowns.keys():
		weapon_cooldowns[id] = maxf(0.0, float(weapon_cooldowns[id]) - delta)
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	skill_cooldown = maxf(0.0, skill_cooldown - delta)
	if intermission > 0.0:
		intermission -= delta
		if intermission <= 0.0:
			_start_wave(wave + 1)
	else:
		_update_spawns(delta)
		_update_enemies(delta)
		if state != "playing":
			return
		_update_projectiles(delta)
		if state != "playing":
			return
		_update_auto_attack()
		if state != "playing":
			return
	_update_drops(delta)
	_update_hud()

func _create_interface() -> void:
	layer = CanvasLayer.new()
	main.add_child(layer)
	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_panel.custom_minimum_size = Vector2(430, 0)
	layer.add_child(menu_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	menu_panel.add_child(column)
	title_label = Label.new()
	title_label.text = "LES CENDRES DE VALOMBRE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	column.add_child(title_label)
	var subtitle := Label.new()
	subtitle.text = "La nuit se lève. Les morts se sont éveillés."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	hero_picker = _add_picker(column, "Héros", ["Le Pèlerin", "La Sentinelle"])
	weapon_picker = _add_picker(column, "Arme de départ", [])
	for weapon in catalog.definitions.get("weapons", []):
		weapon_picker.add_item(weapon.display_name)
		weapon_picker.set_item_metadata(weapon_picker.item_count - 1, str(weapon.id))
	mode_picker = _add_picker(column, "Mode", ["Vagues", "Infini"])
	difficulty_picker = _add_picker(column, "Difficulté", ["Insane", "Nightmare", "Cataclysm"])
	start_button = Button.new()
	start_button.text = "Entrer dans la forêt"
	start_button.pressed.connect(_on_start_pressed)
	column.add_child(start_button)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status_label)
	hud = Label.new()
	hud.position = Vector2(18, 48)
	hud.add_theme_color_override("font_color", Color("eee2c5"))
	hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(hud)
	boss_name_label = Label.new()
	boss_name_label.position = Vector2(300, 15)
	boss_name_label.size = Vector2(360, 24)
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_color_override("font_color", Color("eee2c5"))
	layer.add_child(boss_name_label)
	boss_bar = ProgressBar.new()
	boss_bar.position = Vector2(300, 40)
	boss_bar.size = Vector2(360, 13)
	boss_bar.show_percentage = false
	boss_bar.modulate = Color("bc594b")
	layer.add_child(boss_bar)
	boss_name_label.visible = false
	boss_bar.visible = false
	status_label.visible = false
	_set_state("title")

func _add_picker(parent: VBoxContainer, label_text: String, choices: Array) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	picker_labels.append(label)
	var picker := OptionButton.new()
	for choice in choices:
		picker.add_item(choice)
	parent.add_child(picker)
	return picker

func _on_start_pressed() -> void:
	if state == "paused":
		_set_state("playing")
		return
	if state == "playing":
		return
	hero_id = "sentinel" if hero_picker.selected == 1 else "pilgrim"
	mode = "infinite" if mode_picker.selected == 1 else "waves"
	difficulty_id = ["insane", "nightmare", "cataclysm"][difficulty_picker.selected]
	weapon_id = str(weapon_picker.get_item_metadata(weapon_picker.selected))
	_start_run()

func _start_run() -> void:
	for enemy in enemies:
		enemy.queue_free()
	for drop in drops:
		drop.node.queue_free()
	enemies.clear()
	drops.clear()
	for projectile in projectiles:
		if is_instance_valid(projectile.get("node")):
			projectile.node.queue_free()
	projectiles.clear()
	pending_spawns.clear()
	var hero: GameDefinition = _find_definition("heroes", hero_id)
	var stats: Dictionary = hero.values
	max_hp = float(stats.get("health", 100))
	hp = max_hp
	player.position = WORLD_SIZE * 0.5
	player.run_active = true
	player.move_speed = float(stats.get("speed", 190))
	player.movement_multiplier = 1.0
	player.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var avatar: Sprite2D = player.get_node("Sprite2D")
	avatar.texture = load("res://assets/%s.svg" % ("sentinel" if hero_id == "sentinel" else "hero"))
	player.facing = Vector2.DOWN
	player.skill_dash_time = 0.0
	xp = 0.0
	next_xp = 5.0
	level = 1
	defeated = 0
	damage_multiplier = 1.0
	movement_multiplier = 1.0
	defense = 0.0
	pickup_range = 90.0
	weapon_cooldown = 0.0
	spawn_clock = 1.0
	swarm_timer = -1.0
	intermission = 0.0
	contact_cooldown = 0.0
	skill_cooldown = 0.0
	wave = 0
	elapsed = 0.0
	boss_after_wave_id = ""
	base_hp = float(stats.get("health", 100))
	bonus_max_hp = 0.0
	weapon_inventory = [{"id": weapon_id, "level": 1, "special": false, "locked": false}]
	relic_inventory.clear()
	weapon_cooldowns.clear()
	equipment_damage = 1.0
	equipment_speed = 1.0
	equipment_range = 0.0
	equipment_defense = 0.0
	equipment_xp = 1.0
	equipment_lifesteal = 0.0
	global_pickup = false
	player_shield = 0.0
	scythe_souls = 0
	weapon_swing_counts.clear()
	attack_speed_multiplier = 1.0
	range_bonus = 0.0
	projectile_size_multiplier = 1.0
	projectile_speed_multiplier = 1.0
	pickup_range_multiplier = 1.0
	upgrade_ranks = {"damage": 0, "attackSpeed": 0, "range": 0, "projectileSize": 0, "projectileSpeed": 0, "movementSpeed": 0, "health": 0, "defense": 0, "pickupRange": 0}
	pending_upgrades = 0
	rng.randomize()
	_start_wave(1)
	_set_state("playing")

func _start_wave(number: int) -> void:
	wave = number
	objective_type = ["kills", "xp", "elite"][(number - 1) % 3]
	objective_target = [12, 8, 1][(number - 1) % 3]
	objective_progress = 0
	objective_complete = false
	run_challenges = [
		{"id": "kills", "label": "Vaincre 50 créatures", "target": 50, "progress": 0, "complete": false},
		{"id": "elites", "label": "Vaincre 5 élites", "target": 5, "progress": 0, "complete": false},
		{"id": "xp", "label": "Ramasser 20 orbes d’XP", "target": 20, "progress": 0, "complete": false},
	]
	result_recorded = false
	if mode == "infinite" and number > 4:
		wave_groups = [
			{"kind": "ghoul", "count": 35 + number * 6},
			{"kind": "brute", "count": 12 + number * 3},
			{"kind": "caster", "count": mini(2 + int(number / 2), 9)},
			{"kind": "stalker", "count": mini(4 + number, 15)},
			{"kind": "charger", "count": mini(2 + number, 12)},
			{"kind": "shaman", "count": mini(1 + int(number / 2), 7)},
			{"kind": "leech", "count": mini(4 + number * 2, 32)},
			{"kind": "leaper", "count": mini(3 + number, 18)},
		]
	else:
		wave_groups = (catalog.content.waves[number - 1] if number <= catalog.content.waves.size() else []).duplicate(true)
	boss_after_wave_id = ["guardian", "matriarch", "colossus"][(int(number / 5) - 1) % 3] if mode == "infinite" and number % 5 == 0 else ""
	pending_spawns.clear()
	for entry in wave_groups:
		var count := int(entry.get("count", 1))
		for spawn_index in count:
			pending_spawns.append({"kind": str(entry.kind), "elite": entry.kind != "boss" and (spawn_index + 1) % (18 if mode == "infinite" else 24) == 0, "boss_id": entry.get("boss_id", "guardian")})
	spawn_clock = 1.0 if number == 1 else 0.62
	swarm_timer = rng.randf_range(14.0, 26.0) if rng.randf() < 0.38 else -1.0
	intermission = 0.0
	status_label.text = "Vague %d" % number

func _update_spawns(delta: float) -> void:
	if swarm_timer > 0.0:
		swarm_timer -= delta
		if swarm_timer <= 0.0:
			var swarm_count := mini(62, 26 + mini(wave, 18) * 2)
			var swarm: Array[Dictionary] = []
			for _index in swarm_count:
				var total_weight := 0
				for group in wave_groups:
					total_weight += mini(int(group.get("count", 1)), 12)
				var selected_weight := rng.randi_range(1, max(1, total_weight))
				var kind := "ghoul"
				for group in wave_groups:
					selected_weight -= mini(int(group.get("count", 1)), 12)
					if selected_weight <= 0:
						kind = str(group.kind)
						break
				swarm.append({"kind": kind, "elite": false, "swarm": true, "boss_id": "guardian"})
			swarm.append_array(pending_spawns)
			pending_spawns = swarm
			spawn_clock = 0.0
			swarm_timer = -1.0
	if pending_spawns.is_empty() and enemies.is_empty():
		if not boss_after_wave_id.is_empty():
			var next_boss := boss_after_wave_id
			boss_after_wave_id = ""
			_spawn_enemy("boss", false, next_boss)
			return
		if mode == "infinite" or wave < catalog.content.waves.size():
			intermission = 3.0
			return
		if not enemies.any(func(enemy: ValombreEnemy) -> bool: return enemy.kind == "boss"):
			_spawn_enemy("boss", false, "guardian")
		return
	if pending_spawns.is_empty():
		return
	spawn_clock -= delta
	var difficulty: Dictionary = catalog.content.difficulties[difficulty_id]
	var capacity := 10.0 * float(difficulty.spawnCapacity)
	if mode == "infinite":
		capacity = minf(200.0, 10.0 + floorf(elapsed / 60.0 * 24.0)) * float(difficulty.spawnCapacity)
	var occupied := 0.0
	for enemy in enemies:
		occupied += float(enemy.get_meta("spawn_weight", 1.0))
	var pending_index := -1
	for index in pending_spawns.size():
		var weight := 10.0 if pending_spawns[index].kind == "boss" else float(catalog.content.config.enemies.get(pending_spawns[index].kind, {}).get("weight", 1.0))
		if occupied + weight <= capacity:
			pending_index = index
			break
	if spawn_clock <= 0.0 and pending_index >= 0:
		var spawn := pending_spawns.pop_at(pending_index)
		_spawn_enemy(str(spawn.kind), bool(spawn.get("elite", false)), str(spawn.get("boss_id", "guardian")))
		spawn_clock = 0.12 if spawn.get("swarm", false) else maxf(0.12, 0.62 * pow(0.7, elapsed / 60.0)) if mode == "infinite" else 0.62

func _spawn_enemy(kind: String, is_elite: bool, boss_id: String) -> void:
	var base: Dictionary
	if kind == "boss":
		base = catalog.content.bosses.get(boss_id, catalog.content.bosses.guardian).duplicate(true)
	else:
		base = catalog.content.config.enemies[kind].duplicate(true)
		base.merge(catalog.content.bestiary.get(kind, {}), true)
	var progress := maxf(0.0, wave - 1.0)
	var difficulty: Dictionary = catalog.content.difficulties[difficulty_id]
	var elite_id := ""
	var elite_stats: Dictionary = {}
	if is_elite:
		var elite_ids: Array = catalog.content.eliteAffixes.keys()
		elite_id = str(elite_ids[rng.randi_range(0, elite_ids.size() - 1)])
		elite_stats = catalog.content.eliteAffixes[elite_id]
	var infinite_health := pow(1.28, progress) if mode == "infinite" else 1.0
	var infinite_damage := pow(1.22, progress) if mode == "infinite" else 1.0
	var enemy_stats := base.duplicate(true)
	enemy_stats.health = roundi(float(base.get("health", 34)) * infinite_health * float(difficulty.health) * float(elite_stats.get("health", 1.0)))
	enemy_stats.speed = float(base.get("speed", 74)) * (1.0 + minf(1.2, progress * 0.035) if mode == "infinite" else 1.0) * float(difficulty.speed) * float(elite_stats.get("speed", 1.0))
	enemy_stats.damage = roundi(float(base.get("damage", 9)) * infinite_damage * float(difficulty.damage) * float(elite_stats.get("damage", 1.0)))
	enemy_stats.radius = float(base.get("radius", 33 if kind == "boss" else 14))
	if kind == "boss":
		enemy_stats.sprite = "boss" if boss_id == "guardian" else boss_id
	var enemy := ENEMY_SCRIPT.new() as ValombreEnemy
	enemy.configure(kind, enemy_stats, is_elite)
	if is_elite:
		enemy.elite_name = str(elite_stats.get("name", "Élite"))
		enemy.elite_color = Color(str(elite_stats.get("color", "#e4c978")))
	enemy.attack_timer = rng.randf_range(0.3, 1.3)
	enemy.heal_on_hit = float(base.get("healOnHit", 0.0))
	if kind == "boss":
		enemy.radius = float(base.get("radius", 33))
		enemy.damage = roundf(float(base.get("slamDamage", 26)) * float(difficulty.damage) * infinite_damage)
		enemy.projectile_damage = float(base.get("projectileDamage", enemy.damage)) * float(difficulty.damage) * infinite_damage
		enemy.boss_id = boss_id
		enemy.boss_behavior = str(base.get("behavior", "guardian"))
		enemy.attack_mode = "volley" if enemy.boss_behavior == "volley" else "slam"
		enemy.approach_cooldown = rng.randf_range(0.8, 2.0)
		enemy.set_meta("boss_id", boss_id)
		enemy.set_meta("display_name", str(base.get("name", boss_id)))
		enemy.set_meta("spawn_weight", float(base.get("weight", 10)))
	else:
		enemy.set_meta("spawn_weight", float(base.get("weight", 1)) + (1.0 if is_elite else 0.0))
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(350.0, 540.0)
	enemy.position = Vector2(
		clampf(player.position.x + cos(angle) * distance, 60.0, WORLD_SIZE.x - 60.0),
		clampf(player.position.y + sin(angle) * distance, 60.0, WORLD_SIZE.y - 60.0)
	)
	if kind == "boss":
		enemy.name = "Boss_" + boss_id
	arena.add_child(enemy)
	enemies.append(enemy)

func _update_enemies(delta: float) -> void:
	var to_remove: Array[ValombreEnemy] = []
	var attack_speed := float(catalog.content.difficulties[difficulty_id].attackSpeed)
	for enemy in enemies:
		if not is_instance_valid(enemy):
			to_remove.append(enemy)
			continue
		enemy.hit_flash = maxf(0.0, enemy.hit_flash - delta)
		enemy.slow_time = maxf(0.0, enemy.slow_time - delta)
		if enemy.slow_time <= 0.0:
			enemy.slow_factor = 1.0
		enemy.queue_redraw()
		enemy.attack_timer -= delta * attack_speed
		if enemy.dash_time_left > 0.0:
			_advance_enemy_dash(enemy, delta)
			if state != "playing":
				break
			continue
		var to_player := player.position - enemy.position
		var distance := maxf(to_player.length(), 0.001)
		var direction := to_player / distance
		if enemy.kind == "boss":
			_update_boss(enemy, delta, attack_speed, to_player, distance, direction)
		elif enemy.kind == "charger":
			_update_charger(enemy, delta, attack_speed, distance, direction)
		elif enemy.kind == "leaper":
			_update_leaper(enemy, delta, attack_speed, distance, direction)
		elif enemy.kind == "caster" or enemy.kind == "shaman":
			_update_caster(enemy, delta, attack_speed, distance, direction)
		else:
			_update_contact_enemy(enemy, delta, direction)
		if state != "playing":
			break
	for enemy in to_remove:
		enemies.erase(enemy)

func _update_contact_enemy(enemy: ValombreEnemy, delta: float, direction: Vector2) -> void:
	var reach := enemy.radius + 24.0
	if enemy.position.distance_to(player.position) > reach:
		_move_enemy_around_obstacles(enemy, direction * enemy.speed * enemy.slow_factor * delta)
		return
	if enemy.attack_timer <= 0.0 and player.invulnerability <= 0.0:
		_damage_player(enemy.damage)
		if enemy.heal_on_hit > 0.0 and hp > 0.0:
			enemy.hp = minf(enemy.max_hp, enemy.hp + enemy.heal_on_hit)
		enemy.attack_timer = float(catalog.content.config.enemies.attackCooldown)

func _update_charger(enemy: ValombreEnemy, delta: float, attack_speed: float, distance: float, direction: Vector2) -> void:
	var spec: Dictionary = catalog.content.config.enemies.charger
	if enemy.telegraph > 0.0:
		enemy.telegraph = maxf(0.0, enemy.telegraph - delta * attack_speed)
		if enemy.telegraph <= 0.0:
			var dash := enemy.aim_position - enemy.position
			var dash_length := maxf(dash.length(), 0.001)
			var along := (player.position - enemy.position).dot(dash / dash_length)
			var across := absf((player.position - enemy.position).cross(dash / dash_length))
			if along > 0.0 and along < float(spec.range) and across < 30.0 and player.invulnerability <= 0.0:
				_damage_player(enemy.damage)
			var amount := float(spec.chargeSpeed) * float(catalog.content.difficulties[difficulty_id].speed) * 0.45
			_move_enemy_around_obstacles(enemy, (dash / dash_length) * amount)
			enemy.attack_timer = float(spec.attackCooldown)
	elif enemy.attack_timer <= 0.0 and distance < float(spec.range):
		enemy.aim_position = player.position
		enemy.telegraph = float(spec.windup)
	else:
		_move_enemy_around_obstacles(enemy, direction * enemy.speed * enemy.slow_factor * delta)

func _update_leaper(enemy: ValombreEnemy, delta: float, attack_speed: float, distance: float, direction: Vector2) -> void:
	var spec: Dictionary = catalog.content.config.enemies.leaper
	if enemy.telegraph > 0.0:
		enemy.telegraph = maxf(0.0, enemy.telegraph - delta * attack_speed)
		if enemy.telegraph <= 0.0:
			var leap := enemy.aim_position - enemy.position
			enemy.dash_direction = leap.normalized()
			enemy.dash_distance_left = leap.length()
			enemy.dash_time_left = 0.24
			enemy.dash_damage = enemy.damage
			enemy.dash_width = float(spec.landingRadius)
			enemy.dash_hit = false
			enemy.dash_landing_damage = true
			enemy.dash_sets_recovery = false
			enemy.attack_timer = float(spec.attackCooldown)
		return
	if enemy.attack_timer <= 0.0 and distance < float(spec.leapRange):
		enemy.aim_position = player.position
		enemy.telegraph = float(spec.windup)
	elif distance > enemy.radius + 24.0:
		_move_enemy_around_obstacles(enemy, direction * enemy.speed * enemy.slow_factor * delta)

func _update_caster(enemy: ValombreEnemy, delta: float, attack_speed: float, distance: float, direction: Vector2) -> void:
	var spec: Dictionary = catalog.content.config.enemies[enemy.kind]
	if distance < float(spec.range) * 0.72:
		_move_enemy_around_obstacles(enemy, -direction * enemy.speed * enemy.slow_factor * delta)
	elif distance > float(spec.range):
		_move_enemy_around_obstacles(enemy, direction * enemy.speed * enemy.slow_factor * delta)
	if enemy.telegraph > 0.0:
		enemy.telegraph = maxf(0.0, enemy.telegraph - delta * attack_speed)
		if enemy.telegraph <= 0.0:
			var count := 3 if enemy.kind == "shaman" else 1
			_fire_enemy_fan(enemy, count, 0.24, float(spec.projectileSpeed), enemy.damage, 2.0, "#bd79ce" if count == 3 else "#d7bb8d")
			enemy.attack_timer = float(spec.attackCooldown)
	elif enemy.attack_timer <= 0.0 and distance < float(spec.range) + 115.0:
		enemy.aim_position = player.position
		enemy.telegraph = float(spec.windup)

func _update_boss(enemy: ValombreEnemy, delta: float, attack_speed: float, to_player: Vector2, distance: float, direction: Vector2) -> void:
	var spec: Dictionary = catalog.content.bosses[enemy.boss_id]
	if enemy.approach_telegraph > 0.0:
		enemy.approach_telegraph = maxf(0.0, enemy.approach_telegraph - delta * attack_speed)
		if enemy.approach_telegraph <= 0.0:
			var approach_distance := minf(float(spec.dashDistance), maxf(0.0, distance - float(spec.dashStopDistance)))
			enemy.dash_direction = direction
			enemy.dash_distance_left = approach_distance
			enemy.dash_time_left = float(spec.dashDuration)
			enemy.dash_damage = roundf(float(spec.chargeDamage) * float(catalog.content.difficulties[difficulty_id].damage) * (pow(1.22, maxf(0.0, wave - 1.0)) if mode == "infinite" else 1.0))
			enemy.dash_width = float(spec.dashWidth)
			enemy.dash_hit = false
			enemy.dash_landing_damage = false
			enemy.dash_sets_recovery = true
			enemy.dash_is_approach = true
		return
	enemy.approach_cooldown -= delta * attack_speed
	if distance > float(spec.approachRange) and enemy.approach_cooldown <= 0.0 and enemy.telegraph <= 0.0:
		enemy.aim_position = player.position
		enemy.approach_telegraph = float(spec.dashWindup)
		return
	if enemy.boss_behavior == "volley":
		if distance < 210.0:
			_move_enemy_around_obstacles(enemy, -direction * enemy.speed * enemy.slow_factor * delta)
		elif distance > 330.0:
			_move_enemy_around_obstacles(enemy, direction * enemy.speed * enemy.slow_factor * delta)
		if enemy.telegraph > 0.0:
			enemy.telegraph = maxf(0.0, enemy.telegraph - delta * attack_speed)
			if enemy.telegraph <= 0.0:
				_fire_enemy_fan(enemy, 5, 0.2, float(spec.projectileSpeed), enemy.projectile_damage, 3.0, "#a8d978")
				enemy.attack_timer = float(spec.cooldown)
		elif enemy.attack_timer <= 0.0:
			enemy.aim_position = player.position
			enemy.telegraph = float(spec.telegraph)
		return
	if enemy.telegraph > 0.0:
		enemy.telegraph = maxf(0.0, enemy.telegraph - delta * attack_speed)
		if enemy.telegraph <= 0.0:
			if enemy.attack_mode == "slam":
				if distance < float(spec.slamRadius) and player.invulnerability <= 0.0:
					_damage_player(enemy.damage)
			else:
				var vector := enemy.aim_position - enemy.position
				var dash_distance := minf(float(spec.chargeDistance), maxf(0.0, vector.length() - float(spec.dashStopDistance)))
				enemy.dash_direction = vector.normalized() if vector.length_squared() > 0.0 else direction
				enemy.dash_distance_left = dash_distance
				enemy.dash_time_left = float(spec.dashDuration)
				enemy.dash_damage = roundf(float(spec.chargeDamage) * float(catalog.content.difficulties[difficulty_id].damage) * (pow(1.22, maxf(0.0, wave - 1.0)) if mode == "infinite" else 1.0))
				enemy.dash_width = float(spec.chargeWidth)
				enemy.dash_hit = false
				enemy.dash_landing_damage = false
				enemy.dash_sets_recovery = true
				enemy.dash_is_approach = false
			enemy.attack_timer = float(spec.cooldown)
			enemy.attack_mode = "charge" if enemy.attack_mode == "slam" else "slam"
	elif enemy.attack_timer <= 0.0:
		enemy.aim_position = player.position
		enemy.telegraph = float(spec.telegraph)
	elif distance > enemy.radius + 85.0:
		_move_enemy_around_obstacles(enemy, direction * enemy.speed * enemy.slow_factor * delta)

func _fire_enemy_fan(enemy: ValombreEnemy, count: int, spread: float, speed: float, damage: float, lifetime: float, tint: String) -> void:
	var base_angle := (enemy.aim_position - enemy.position).angle()
	var difficulty: Dictionary = catalog.content.difficulties[difficulty_id]
	for shot in count:
		var angle := base_angle + (float(shot) - float(count - 1) * 0.5) * spread
		var direction := Vector2(cos(angle), sin(angle))
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/xp.svg")
		sprite.scale = Vector2(0.18, 0.18)
		sprite.modulate = Color(tint)
		sprite.position = enemy.position
		arena.add_child(sprite)
		projectiles.append({"node": sprite, "team": "enemy", "velocity": direction * speed * float(difficulty.projectileSpeed), "damage": damage, "radius": 7.0, "life": lifetime, "source": enemy.kind})

func _advance_enemy_dash(enemy: ValombreEnemy, delta: float) -> void:
	var step_length := minf(enemy.dash_distance_left, enemy.dash_distance_left * delta / maxf(enemy.dash_time_left, delta))
	var start := enemy.position
	var step := enemy.dash_direction * step_length
	_move_enemy_around_obstacles(enemy, step)
	var finish := enemy.position
	if not enemy.dash_landing_damage and not enemy.dash_hit and player.invulnerability <= 0.0 and _distance_to_segment(player.position, start, finish) < enemy.dash_width + 12.0:
		_damage_player(enemy.dash_damage)
		enemy.dash_hit = true
	enemy.dash_distance_left = maxf(0.0, enemy.dash_distance_left - step_length)
	enemy.dash_time_left = maxf(0.0, enemy.dash_time_left - delta)
	if enemy.dash_time_left <= 0.0 or enemy.dash_distance_left <= 0.0:
		if enemy.dash_landing_damage and player.invulnerability <= 0.0 and player.position.distance_to(enemy.position) < enemy.dash_width:
			_damage_player(enemy.dash_damage)
		enemy.dash_landing_damage = false
		if enemy.dash_sets_recovery:
			enemy.attack_timer = maxf(enemy.attack_timer, 0.65)
		if enemy.dash_is_approach:
			enemy.approach_cooldown = float(catalog.content.bosses[enemy.boss_id].dashCooldown)
			enemy.dash_is_approach = false

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0) if length_squared > 0.0 else 0.0
	return point.distance_to(start + segment * t)

func _move_enemy_around_obstacles(enemy: ValombreEnemy, step: Vector2) -> void:
	var candidate := enemy.position + step
	if _position_blocked(candidate, enemy.radius):
		candidate = enemy.position + Vector2(step.x, 0.0)
		if _position_blocked(candidate, enemy.radius):
			candidate = enemy.position + Vector2(0.0, step.y)
	if not _position_blocked(candidate, enemy.radius):
		enemy.position = candidate

func _position_blocked(position: Vector2, radius: float) -> bool:
	if position.x < 35.0 + radius or position.y < 35.0 + radius or position.x > WORLD_SIZE.x - 35.0 - radius or position.y > WORLD_SIZE.y - 35.0 - radius:
		return true
	for obstacle in OBSTACLES:
		if position.distance_to(Vector2(obstacle.x, obstacle.y)) < obstacle.z + radius:
			return true
	return false

func _update_auto_attack() -> void:
	for owned in weapon_inventory:
		var id := str(owned.id)
		var weapon: Dictionary = catalog.content.weapons[id]
		var target: ValombreEnemy
		var nearest := INF
		for enemy in enemies:
			var distance := player.position.distance_to(enemy.position)
			if distance < nearest:
				nearest = distance
				target = enemy
		var manual := id == weapon_id and Input.is_action_just_pressed("attack")
		var level_scale := 1.0 + 0.18 * (int(owned.level) - 1)
		var reach := (float(weapon.get("range", 108.0)) + range_bonus + equipment_range) * float(_synergy_data(id).get("rangeMultiplier", 1.0))
		if not target or nearest > reach or (float(weapon_cooldowns.get(id, 0.0)) > 0.0 and not manual):
			continue
		var aim := (target.position - player.position).normalized()
		if aim != Vector2.ZERO:
			player.facing = aim
		var synergy := _synergy_data(id)
		var damage_scale := damage_multiplier * equipment_damage * level_scale * float(synergy.get("damageMultiplier", 1.0)) * (1.5 if bool(owned.special) else 1.0) * (1.0 + (level - 1) * 0.005)
		var frequency := maxf(0.1, float(weapon.speed) * attack_speed_multiplier * equipment_speed * (1.0 + 0.08 * (int(owned.level) - 1)) * float(synergy.get("attackSpeedMultiplier", 1.0)) * (1.2 if bool(owned.special) else 1.0))
		weapon_cooldowns[id] = 0.26 / frequency
		if bool(weapon.get("ranged", false)):
			_launch_projectile(weapon, target, damage_scale, id, reach)
			continue
		weapon_swing_counts[id] = int(weapon_swing_counts.get(id, 0)) + 1
		for enemy in enemies.duplicate():
			var offset := enemy.position - player.position
			var distance := offset.length()
			var in_shape := false
			if bool(weapon.get("circular", false)):
				in_shape = distance < reach
			elif bool(weapon.get("piercing", false)):
				var along := clampf(offset.dot(player.facing), 0.0, reach)
				var closest := player.position + player.facing * along
				in_shape = enemy.position.distance_to(closest) < 18.0 + enemy.radius
			else:
				var alignment := offset.normalized().dot(player.facing) if distance > 0.0 else 1.0
				in_shape = distance < reach and alignment > float(weapon.get("arc", -1.0))
			if in_shape:
				var sabre_burst := false
				if id == "sabre" and _synergy_active(id):
					var marks := int(enemy.get_meta("sabre_combo_marks", 0)) + 1
					enemy.set_meta("sabre_combo_marks", marks % 5)
					sabre_burst = marks >= 5
				if id == "lance" and _synergy_active(id):
					player_shield = minf(max_hp * 0.5, player_shield + 8.0)
				_damage_enemy(enemy, _weapon_base_damage(weapon, enemy) * damage_scale, id)
				if id == "sabre" and bool(owned.special) and int(weapon_swing_counts[id]) % 3 == 0 and is_instance_valid(enemy):
					enemy.set_meta("sabre_mark", true)
				if sabre_burst:
					for nearby in enemies.duplicate():
						if nearby.position.distance_to(enemy.position) <= 104.0:
							_damage_enemy(nearby, _weapon_base_damage(weapon, nearby) * damage_scale * 1.35, id)
		if id == "marteau" and bool(owned.special):
			var full_circle := _synergy_active(id)
			for enemy in enemies.duplicate():
				var offset := enemy.position - player.position
				var distance := offset.length()
				var in_wave := distance <= reach + 34.0
				if not full_circle and distance > 0.0:
					in_wave = in_wave and offset.normalized().dot(player.facing) > float(weapon.get("arc", -1.0))
				if in_wave:
					_damage_enemy(enemy, _weapon_base_damage(weapon, enemy) * damage_scale * (1.05 if full_circle else 0.55), id)
					if is_instance_valid(enemy) and enemy.hp > 0.0 and not full_circle:
						enemy.position += offset.normalized() * 26.0
			if full_circle:
				for enemy in enemies.duplicate():
					var away := enemy.position - player.position
					if away.length() <= reach + 82.0 and away.length() > 0.0:
						enemy.position += away.normalized() * 76.0
		if id == "faux" and _synergy_active(id) and scythe_souls > 0:
			var released := scythe_souls
			scythe_souls = 0
			for enemy in enemies.duplicate():
				if enemy.position.distance_to(player.position) <= reach * 1.08:
					_damage_enemy(enemy, float(weapon.ghoulDamage) * damage_scale * (0.32 + released * 0.42), id)

func _weapon_base_damage(weapon: Dictionary, enemy: ValombreEnemy) -> float:
	return float(weapon.get("bruteDamage", 25) if enemy.kind == "brute" else weapon.get("ghoulDamage", 32))

func _launch_projectile(weapon: Dictionary, target: ValombreEnemy, damage_scale: float, id: String, reach: float) -> void:
	var direction := (target.position - player.position).normalized()
	var directions: Array[Vector2] = [direction]
	if id == "arc" and _synergy_active(id):
		directions = [direction.rotated(-0.2), direction, direction.rotated(0.2)]
	for shot_index in directions.size():
		var shot_direction := directions[shot_index]
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/weapons/%s.svg" % id)
		sprite.scale = Vector2(0.18, 0.18) * projectile_size_multiplier
		sprite.modulate = Color("c7a8ff") if weapon.get("lightning", false) else Color("91e9ef") if weapon.get("frost", false) else Color("ff9a4e") if weapon.get("explosive", false) else Color("85d8ce")
		sprite.position = player.position + shot_direction * 14.0
		arena.add_child(sprite)
		projectiles.append({
			"node": sprite,
			"direction": shot_direction,
			"speed": 520.0 * projectile_speed_multiplier,
			"radius": 5.0 * projectile_size_multiplier,
			"damage": _weapon_base_damage(weapon, target) * damage_scale * (0.72 if directions.size() == 3 and shot_index != 1 else 1.0),
			"weapon": id,
			"remaining": reach + 40.0,
			"explosive": bool(weapon.get("explosive", false)),
			"lightning": bool(weapon.get("lightning", false)),
			"frost": bool(weapon.get("frost", false)),
			"slow_duration": 1.25 * (float(_synergy_data(id).get("slowDurationMultiplier", 1.0))) * (2.4 / 1.25 if bool(_owned_weapon(id).get("special", false)) else 1.0),
						"slow_factor": 0.42 if bool(_owned_weapon(id).get("special", false)) else 0.58,
			"chain_targets": int(_owned_weapon(id).get("level", 1)) + (1 if bool(_owned_weapon(id).get("special", false)) and bool(weapon.get("lightning", false)) else 0),
			"chain_range": 380.0 if id == "foudre" and _synergy_active(id) else 190.0,
			"hit_targets": [],
		})

func _update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[index]
		var node: Sprite2D = projectile.node
		if projectile.get("team", "player") == "enemy":
			node.position += projectile.velocity * delta
			projectile.life -= delta
			if node.position.distance_to(player.position) < float(projectile.radius) + 10.0:
				if player.invulnerability <= 0.0:
					_damage_player(float(projectile.damage))
				_remove_projectile(index)
				continue
			if float(projectile.life) <= 0.0 or _position_blocked(node.position, float(projectile.radius)):
				_remove_projectile(index)
			continue
		var step := float(projectile.speed) * delta
		if projectile.has("homing_target") and is_instance_valid(projectile.homing_target):
			projectile.direction = node.position.direction_to(projectile.homing_target.position)
		node.position += projectile.direction * step
		projectile.remaining -= step
		var hit_target: ValombreEnemy
		for enemy in enemies:
			if projectile.hit_targets.has(enemy):
				continue
			if enemy.position.distance_to(node.position) <= enemy.radius + float(projectile.radius):
				hit_target = enemy
				break
		if hit_target:
			if projectile.explosive:
				_detonate_projectile(projectile, node.position)
				_remove_projectile(index)
				continue
			if projectile.frost:
				hit_target.slow_time = maxf(hit_target.slow_time, float(projectile.get("slow_duration", 1.25)))
				hit_target.slow_factor = float(projectile.get("slow_factor", 0.58))
			_damage_enemy(hit_target, float(projectile.damage), str(projectile.weapon))
			if projectile.lightning:
				_chain_lightning(hit_target, projectile)
			_remove_projectile(index)
			continue
		if projectile.remaining <= 0.0 or _position_blocked(node.position, float(projectile.radius)):
			if projectile.explosive:
				_detonate_projectile(projectile, node.position)
			_remove_projectile(index)

func _chain_lightning(first: ValombreEnemy, projectile: Dictionary) -> void:
	var current := first
	var hit: Array[ValombreEnemy] = [first]
	var max_bounces := int(projectile.get("chain_targets", 1))
	for _bounce in max_bounces:
		var nearest: ValombreEnemy
		var nearest_distance := float(projectile.get("chain_range", 190.0))
		for enemy in enemies:
			if hit.has(enemy):
				continue
			var distance := current.position.distance_to(enemy.position)
			if distance <= nearest_distance:
				nearest = enemy
				nearest_distance = distance
		if not nearest:
			break
		hit.append(nearest)
		_damage_enemy(nearest, float(projectile.damage) * 0.72, str(projectile.weapon))
		current = nearest

func _detonate_projectile(projectile: Dictionary, center: Vector2) -> void:
	var radius := float(projectile.get("radius", 44.0))
	for enemy in enemies.duplicate():
		if enemy.position.distance_to(center) <= radius + enemy.radius:
			_damage_enemy(enemy, float(projectile.damage), str(projectile.weapon))

func _remove_projectile(index: int) -> void:
	var projectile: Dictionary = projectiles[index]
	if is_instance_valid(projectile.node):
		projectile.node.queue_free()
	projectiles.remove_at(index)

func _damage_enemy(enemy: ValombreEnemy, amount: float, _weapon: String) -> void:
	if not is_instance_valid(enemy):
		return
	if bool(enemy.get_meta("sabre_mark", false)):
		amount *= 1.5
		enemy.set_meta("sabre_mark", false)
	var damage := roundf(amount)
	var dealt := minf(damage, maxf(0.0, enemy.hp))
	enemy.hp -= damage
	enemy.hit_flash = 0.18
	if enemy.hp <= 0.0:
		defeated += 1
		_on_enemy_killed(enemy, _weapon)
		if enemy.kind == "boss":
			_enemy_drop_xp(enemy.position, 1.0, false)
			enemy.queue_free()
			enemies.erase(enemy)
			if mode == "infinite":
				profile.shards = int(profile.shards) + 1
				_save_profile()
				intermission = 3.0
			else:
				_finish_run("victory")
		else:
			_enemy_drop_xp(enemy.position, 1.5 if enemy.elite else 1.0)
			_progress_objective("kills")
			if enemy.elite:
				_progress_objective("elite")
			enemy.queue_free()
			enemies.erase(enemy)
	if equipment_lifesteal > 0.0 and is_instance_valid(player):
		hp = minf(max_hp, hp + dealt * equipment_lifesteal)

func _weapon_scale(id: String) -> float:
	var owned := _owned_weapon(id)
	if owned.is_empty():
		return damage_multiplier * equipment_damage * (1.0 + (level - 1) * 0.005)
	return damage_multiplier * equipment_damage * (1.0 + 0.18 * (int(owned.level) - 1)) * (1.5 if bool(owned.special) else 1.0) * float(_synergy_data(id).get("damageMultiplier", 1.0)) * (1.0 + (level - 1) * 0.005)

func _on_enemy_killed(enemy: ValombreEnemy, weapon: String) -> void:
	var death_position := enemy.position
	if weapon == "faux" and _synergy_active("faux"):
		scythe_souls = mini(5, scythe_souls + 1)
	if weapon == "dagues" and _synergy_active("dagues"):
		var targets: Array[ValombreEnemy] = []
		for candidate in enemies:
			if candidate != enemy and candidate.position.distance_to(death_position) <= 300.0:
				targets.append(candidate)
		targets.sort_custom(func(a: ValombreEnemy, b: ValombreEnemy) -> bool: return a.position.distance_to(death_position) < b.position.distance_to(death_position))
		for target in targets.slice(0, mini(3, targets.size())):
			var dagger := Sprite2D.new()
			dagger.texture = load("res://assets/weapons/dagues.svg")
			dagger.modulate = Color("a9ffe1")
			dagger.scale = Vector2(0.13, 0.13)
			dagger.position = death_position
			arena.add_child(dagger)
			projectiles.append({"node": dagger, "direction": death_position.direction_to(target.position), "speed": 620.0, "radius": 6.0, "damage": float(catalog.content.weapons.dagues.ghoulDamage) * _weapon_scale("dagues") * 1.4, "weapon": "", "remaining": 900.0, "homing_target": target, "explosive": false, "lightning": false, "frost": false, "hit_targets": []})
	if weapon == "givre" and enemy.slow_time > 0.0 and _synergy_active("givre"):
		for target in enemies.duplicate():
			if target == enemy or target.position.distance_to(death_position) > 124.0:
				continue
			target.slow_time = maxf(target.slow_time, 1.8)
			target.slow_factor = 0.35
			_damage_enemy(target, float(catalog.content.weapons.givre.ghoulDamage) * _weapon_scale("givre") * 1.35, "")

func _enemy_drop_xp(position: Vector2, value: float, allow_item_drop := true) -> void:
	var node := Sprite2D.new()
	node.texture = load("res://assets/xp.svg")
	node.scale = Vector2(0.18, 0.18)
	node.position = position + Vector2(rng.randf_range(-15, 15), rng.randf_range(-15, 15))
	arena.add_child(node)
	var xp_multiplier := equipment_xp * float(_synergy_data("foudre").get("experienceMultiplier", 1.0))
	drops.append({"node": node, "type": "xp", "value": value * xp_multiplier, "life": 18.0})
	var difficulty: Dictionary = catalog.content.difficulties.get(difficulty_id, {})
	if not allow_item_drop:
		return
	var drop_roll := rng.randf()
	var potion_chance := float(catalog.content.config.drops.get("potionChance", 0.08)) * float(difficulty.get("itemDrop", 1.0))
	var equipment_chance := float(catalog.content.config.drops.get("relicChance", 0.22)) * float(difficulty.get("itemDrop", 1.0))
	if drop_roll < potion_chance:
		var potion := Sprite2D.new()
		potion.texture = load("res://assets/relics/heart.svg")
		potion.scale = Vector2(0.17, 0.17)
		potion.position = position
		arena.add_child(potion)
		drops.append({"node": potion, "type": "potion", "life": 18.0})
	elif drop_roll < potion_chance + equipment_chance:
		var choices: Array[String] = []
		for definition: GameDefinition in catalog.definitions.get("weapons", []):
			var owned := _owned_weapon(str(definition.id))
			if owned.is_empty() or int(owned.level) < 5 or not bool(owned.special):
				choices.append("weapon:%s" % definition.id)
		for relic: Dictionary in catalog.content.relics:
			var owned_relic := _owned_relic(str(relic.id))
			if owned_relic.is_empty() or int(owned_relic.level) < 5:
				choices.append("relic:%s" % relic.id)
		if not choices.is_empty():
			var parts := choices[rng.randi_range(0, choices.size() - 1)].split(":")
			var loot_type := str(parts[0])
			var loot_id := str(parts[1])
			var loot_node := Sprite2D.new()
			loot_node.texture = load("res://assets/weapons/%s.svg" % loot_id) if loot_type == "weapon" else load("res://assets/relics/%s.svg" % loot_id)
			loot_node.scale = Vector2(0.17, 0.17)
			loot_node.position = position + Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20))
			arena.add_child(loot_node)
			drops.append({"node": loot_node, "type": loot_type, "id": loot_id, "life": 18.0})

func _update_drops(delta: float) -> void:
	var bomb_combo_pickups := 0
	for index in range(drops.size() - 1, -1, -1):
		var drop: Dictionary = drops[index]
		drop.life -= delta
		if not is_instance_valid(drop.node) or drop.life <= 0.0:
			drop.node.queue_free()
			drops.remove_at(index)
			continue
		var distance: float = player.position.distance_to(drop.node.position)
		if distance <= pickup_range or global_pickup:
			var pull := player.position.direction_to(drop.node.position) * minf(240.0 * delta, distance)
			drop.node.position -= pull
		if player.position.distance_to(drop.node.position) <= 22.0:
			if global_pickup:
				bomb_combo_pickups += 1
			if str(drop.get("type", "xp")) == "weapon":
				_pick_weapon(str(drop.id))
			elif str(drop.get("type", "xp")) == "relic":
				_pick_relic(str(drop.id))
			elif str(drop.get("type", "xp")) == "potion":
				hp = minf(max_hp, hp + 32.0)
			else:
				xp += float(drop.value)
			drop.node.queue_free()
			drops.remove_at(index)
			if str(drop.get("type", "xp")) == "xp":
				_progress_objective("xp")
				while xp >= next_xp:
					xp -= next_xp
					level += 1
					next_xp += 3.0
					pending_upgrades += 1
				var old_max_hp := max_hp
				max_hp = base_hp * (1.0 + (level - 1) * 0.01) + bonus_max_hp + _relic_health()
				hp = minf(max_hp, hp + max_hp - old_max_hp)
				if pending_upgrades > 0:
					_show_level_up()
					return
	if bomb_combo_pickups > 0 and state == "playing":
		var bomb_damage := float(catalog.content.weapons.bombe.ghoulDamage) * _weapon_scale("bombe") * minf(4.0, 1.4 + (bomb_combo_pickups - 1) * 0.55)
		_detonate_projectile({"radius": 92.0, "damage": bomb_damage, "weapon": "bombe"}, player.position)

func _show_level_up() -> void:
	_set_state("levelUp")
	var column: VBoxContainer = menu_panel.get_child(0)
	for child in column.get_children():
		if child is Button and child != start_button:
			child.queue_free()
	var choices: Array[GameDefinition] = []
	var pool: Array = catalog.definitions.upgrades.filter(func(item: GameDefinition) -> bool: return int(upgrade_ranks.get(str(item.id), 0)) < int(item.values.get("maxRanks", 10)))
	if pool.is_empty():
		pending_upgrades = 0
		_set_state("playing")
		return
	while choices.size() < 3 and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		choices.append(pool.pop_at(index))
	for definition in choices:
		var button := Button.new()
		button.text = "%s · %s\nRang %d/%d · prochain bonus %s" % [definition.display_name, definition.values.get("description", ""), upgrade_ranks.get(str(definition.id), 0), definition.values.get("maxRanks", 10), _format_upgrade_bonus(definition)]
		button.pressed.connect(_apply_upgrade.bind(definition))
		column.add_child(button)

func _apply_upgrade(definition: GameDefinition) -> void:
	var values: Dictionary = definition.values
	var rank := int(upgrade_ranks.get(str(definition.id), 0))
	var bonus := float(values.get("bonus", 0.0)) / float(rank + 1)
	match str(definition.id):
		"damage": damage_multiplier *= 1.0 + bonus
		"attackSpeed": attack_speed_multiplier *= 1.0 + bonus
		"range": range_bonus += bonus
		"projectileSize": projectile_size_multiplier *= 1.0 + bonus
		"projectileSpeed": projectile_speed_multiplier *= 1.0 + bonus
		"movementSpeed":
			movement_multiplier *= 1.0 + bonus
			player.movement_multiplier = movement_multiplier
		"health":
			bonus_max_hp += bonus
			max_hp += bonus
			hp = minf(max_hp, hp + bonus)
		"defense": defense += bonus
		"pickupRange":
			pickup_range_multiplier *= 1.0 + bonus
			pickup_range *= 1.0 + bonus
	upgrade_ranks[str(definition.id)] = rank + 1
	_refresh_relic_stats()
	pending_upgrades -= 1
	if pending_upgrades > 0:
		_show_level_up()
	else:
		_set_state("playing")

func _owned_weapon(id: String) -> Dictionary:
	for item in weapon_inventory:
		if str(item.id) == id:
			return item
	return {}

func _owned_relic(id: String) -> Dictionary:
	for item in relic_inventory:
		if str(item.id) == id:
			return item
	return {}

func _pick_weapon(id: String) -> void:
	var owned := _owned_weapon(id)
	if not owned.is_empty():
		if int(owned.level) < 5:
			owned.level = int(owned.level) + 1
		elif not bool(owned.special):
			owned.special = true
			status_label.text = "%s spéciale obtenue" % _find_definition("weapons", id).display_name
		else:
			return
		weapon_cooldowns[id] = 0.0
		_refresh_relic_stats()
		return
	var entry := {"id": id, "level": 1, "special": false, "locked": false}
	if weapon_inventory.size() < 5:
		weapon_inventory.append(entry)
		_refresh_relic_stats()
		return
	var choices: Array[Dictionary] = []
	for item in weapon_inventory:
		if not bool(item.get("locked", false)):
			choices.append(item)
	if choices.is_empty():
		return
	_set_state("loot")
	var column: VBoxContainer = menu_panel.get_child(0)
	for item in choices:
		var button := Button.new()
		button.text = "Remplacer %s · niveau %d" % [_find_definition("weapons", str(item.id)).display_name, int(item.level)]
		button.pressed.connect(func() -> void:
			weapon_inventory.erase(item)
			weapon_inventory.append(entry)
			weapon_cooldowns.erase(str(item.id))
			_refresh_relic_stats()
			_set_state("playing")
		)
		column.add_child(button)
	var pass_button := Button.new()
	pass_button.text = "Passer cette arme"
	pass_button.pressed.connect(func() -> void: _set_state("playing"))
	column.add_child(pass_button)

func _pick_relic(id: String) -> void:
	var owned := _owned_relic(id)
	if not owned.is_empty():
		if int(owned.level) < 5:
			owned.level = int(owned.level) + 1
			_refresh_relic_stats()
		return
	var entry: Dictionary = {}
	for relic: Dictionary in catalog.content.relics:
		if str(relic.id) == id:
			entry = relic.duplicate(true)
			break
	if entry.is_empty():
		return
	entry.level = 1
	entry.locked = false
	if relic_inventory.size() < 5:
		relic_inventory.append(entry)
		_refresh_relic_stats()
		return
	var choices: Array[Dictionary] = []
	for item in relic_inventory:
		if not bool(item.get("locked", false)):
			choices.append(item)
	if choices.is_empty():
		return
	_set_state("loot")
	var column: VBoxContainer = menu_panel.get_child(0)
	for item in choices:
		var button := Button.new()
		button.text = "Remplacer %s · niveau %d" % [str(item.get("name", item.id)), int(item.level)]
		button.pressed.connect(func() -> void:
			relic_inventory.erase(item)
			relic_inventory.append(entry)
			_refresh_relic_stats()
			_set_state("playing")
		)
		column.add_child(button)
	var pass_button := Button.new()
	pass_button.text = "Passer cette relique"
	pass_button.pressed.connect(func() -> void: _set_state("playing"))
	column.add_child(pass_button)

func _refresh_relic_stats() -> void:
	equipment_damage = 1.0
	equipment_speed = 1.0
	equipment_range = 0.0
	equipment_defense = 0.0
	equipment_xp = 1.0
	equipment_lifesteal = 0.0
	var pickup_mult := 1.0
	var health_bonus := 0.0
	global_pickup = false
	for relic in relic_inventory:
		var value := float(relic.get("value", 0.0))
		var ranks := int(relic.get("level", 1))
		match str(relic.get("effect", "")):
			"damage": equipment_damage += value * ranks
			"speed": equipment_speed *= 1.0 + (value - 1.0) * ranks
			"range": equipment_range += value * ranks
			"defense": equipment_defense = minf(0.65, equipment_defense + value * ranks)
			"experience": equipment_xp *= 1.0 + (value - 1.0) * ranks
			"lifesteal": equipment_lifesteal += value * ranks
			"health": health_bonus += value * ranks
			"pickup": pickup_mult *= 1.0 + (value - 1.0) * ranks
	for synergy: Dictionary in catalog.content.synergies:
		var owned_weapon := _owned_weapon(str(synergy.weaponId))
		var owned_relic := _owned_relic(str(synergy.relicId))
		if not owned_weapon.is_empty() and int(owned_weapon.level) == 5 and bool(owned_weapon.special) and not owned_relic.is_empty() and int(owned_relic.level) == 5 and bool(synergy.get("globalPickup", false)):
			global_pickup = true
	max_hp = base_hp * (1.0 + (level - 1) * 0.01) + bonus_max_hp + health_bonus
	hp = minf(max_hp, hp)
	pickup_range = 90.0 * pickup_range_multiplier * pickup_mult

func _synergy_active(weapon: String) -> bool:
	for synergy: Dictionary in catalog.content.synergies:
		if str(synergy.weaponId) != weapon:
			continue
		var owned_weapon := _owned_weapon(weapon)
		var owned_relic := _owned_relic(str(synergy.relicId))
		if not owned_weapon.is_empty() and int(owned_weapon.level) == 5 and bool(owned_weapon.special) and not owned_relic.is_empty() and int(owned_relic.level) == 5:
			return true
	return false

func _synergy_data(weapon: String) -> Dictionary:
	for synergy: Dictionary in catalog.content.synergies:
		if str(synergy.weaponId) == weapon and _synergy_active(weapon):
			return synergy
	return {}

func _inventory_summary() -> String:
	var lines: Array[String] = ["ARMES"]
	for item in weapon_inventory:
		lines.append("%s · niveau %d%s" % [_find_definition("weapons", str(item.id)).display_name, int(item.level), " · spéciale" if bool(item.special) else ""])
	lines.append("\nRELIQUES")
	for item in relic_inventory:
		lines.append("%s · niveau %d" % [str(item.get("name", item.id)), int(item.level)])
	lines.append("\nSYNERGIES ACTIVES")
	var found := false
	for synergy: Dictionary in catalog.content.synergies:
		if _synergy_active(str(synergy.weaponId)):
			lines.append(str(synergy.name))
			found = true
	if not found:
		lines.append("Aucune")
	return "\n".join(lines)

func _relic_health() -> float:
	var total := 0.0
	for item in relic_inventory:
		if str(item.get("effect", "")) == "health":
			total += float(item.value) * int(item.level)
	return total

func _damage_player(amount: float) -> void:
	var incoming := maxf(1.0, amount * (1.0 - minf(0.8, defense + equipment_defense)))
	var absorbed := minf(player_shield, incoming)
	player_shield -= absorbed
	hp -= incoming - absorbed
	player.invulnerability = 0.55
	if hp <= 0.0:
		hp = 0.0
		_finish_run("defeat")

func _use_hero_skill() -> void:
	if hero_id != "sentinel" or skill_cooldown > 0.0:
		return
	skill_cooldown = 5.0
	var forward := player.facing
	for enemy in enemies:
		var offset := enemy.position - player.position
		var forward_distance := offset.dot(forward)
		var side_distance := absf(offset.cross(forward))
		if forward_distance >= 0.0 and forward_distance <= 190.0 and side_distance <= 34.0:
			_damage_enemy(enemy, 58.0, weapon_id)
	player.skill_dash_direction = forward
	player.skill_dash_speed = 190.0 / 0.42
	player.skill_dash_time = 0.42
	player.invulnerability = 0.32

func _set_state(next_state: String) -> void:
	state = next_state
	var is_overlay := state != "playing"
	menu_panel.visible = is_overlay
	player.run_active = state == "playing"
	match state:
		"title":
			title_label.text = "LES CENDRES DE VALOMBRE"
			status_label.text = "Victoires : %d · Éclats : %d · Meilleur score : %d créatures\nChoisissez votre héros, votre arme, le mode et la difficulté.\nWASD / flèches · E capacité · Maj esquive · Échap pause" % [profile.wins, profile.shards, profile.bestKills]
			start_button.text = "Entrer dans la forêt"
		"paused":
			title_label.text = "LA CHASSE ATTEND"
			status_label.text = "Échap pour reprendre"
			start_button.text = "Reprendre la chasse"
		"levelUp":
			title_label.text = "UNE NOUVELLE FORCE"
			status_label.text = "Choisissez une amélioration."
			start_button.visible = false
		"loot":
			title_label.text = "UN NOUVEL ÉQUIPEMENT"
			status_label.text = "Votre sac est plein. Choisissez un objet à remplacer, ou passez."
			start_button.visible = false
		"victory":
			title_label.text = "VALOMBRE EST LIBÉRÉE"
			status_label.text = _result_summary(true)
			start_button.text = "Rejouer"
		"defeat":
			title_label.text = "LA FORÊT VOUS REPREND"
			status_label.text = _result_summary(false)
			start_button.text = "Rejouer"
	if state not in ["levelUp", "loot"]:
		start_button.visible = true
		hero_picker.visible = state == "title"
		weapon_picker.visible = state == "title"
		mode_picker.visible = state == "title"
		difficulty_picker.visible = state == "title"
		status_label.visible = state != "playing"
		for picker_label in picker_labels:
			picker_label.visible = state == "title"
		for child in menu_panel.get_child(0).get_children():
			if child is Button and child != start_button:
				child.queue_free()

func _update_hud() -> void:
	if not is_instance_valid(hud):
		return
	var objective := "%s %d/%d" % [objective_type, mini(objective_progress, objective_target), objective_target]
	var challenge_text := "Défis terminés"
	for challenge in run_challenges:
		if not bool(challenge.complete):
			challenge_text = "%s %d/%d" % [challenge.label, int(challenge.progress), int(challenge.target)]
			break
	hud.text = "PV %d/%d · Bouclier %d\nNiveau %d · XP %d/%d\nVague %d · %s · %s\nDéfi : %s\nÉliminations %d · Arsenal %d/5 · Reliques %d/5" % [ceili(hp), ceili(max_hp), ceili(player_shield), level, int(xp), int(next_xp), wave, difficulty_id.capitalize(), objective, challenge_text, defeated, weapon_inventory.size(), relic_inventory.size()]
	var active_boss: ValombreEnemy
	for enemy in enemies:
		if enemy.kind == "boss":
			active_boss = enemy
			break
	boss_bar.visible = active_boss != null
	boss_name_label.visible = active_boss != null
	if active_boss:
		boss_name_label.text = str(active_boss.get_meta("display_name", "Boss"))
		boss_bar.max_value = active_boss.max_hp
		boss_bar.value = active_boss.hp

func _find_definition(group: String, target_id: String) -> GameDefinition:
	for definition: GameDefinition in catalog.definitions.get(group, []):
		if str(definition.id) == target_id:
			return definition
	return catalog.definitions[group][0]

func _format_upgrade_bonus(definition: GameDefinition) -> String:
	var value := float(definition.values.get("bonus", 0.0)) / float(int(upgrade_ranks.get(str(definition.id), 0)) + 1)
	match str(definition.values.get("kind", "")):
		"range": return "%0.1f portée" % value
		"health": return "%d PV max" % roundi(value)
		"defense": return "%0.1f %% défense" % (value * 100.0)
		"pickup": return "%d %% ramassage" % roundi(value * 100.0)
		_: return "%d %%" % roundi(value * 100.0)

func _progress_objective(target: String) -> void:
	_progress_challenges(target)
	if objective_type != target or objective_complete:
		return
	objective_progress = mini(objective_target, objective_progress + 1)
	if objective_progress >= objective_target:
		objective_complete = true
		hp = minf(max_hp, hp + ceili(max_hp * 0.18))
		status_label.text = "Objectif accompli · +18 % PV"

func _progress_challenges(target: String) -> void:
	var challenge_id := "elites" if target == "elite" else target
	for challenge in run_challenges:
		if str(challenge.id) != challenge_id or bool(challenge.complete):
			continue
		challenge.progress = mini(int(challenge.target), int(challenge.progress) + 1)
		if int(challenge.progress) >= int(challenge.target):
			challenge.complete = true
			profile.shards = int(profile.shards) + 1
			_save_profile()
			status_label.text = "Défi accompli · +1 Éclat"

func _finish_run(result: String) -> void:
	if result_recorded:
		return
	result_recorded = true
	profile.bestKills = maxi(int(profile.bestKills), defeated)
	if result == "victory":
		profile.wins = int(profile.wins) + 1
		profile.shards = int(profile.shards) + 1
	_save_profile()
	_set_state(result)

func _result_summary(victory: bool) -> String:
	var total_seconds := int(elapsed)
	var time_text := "%d min %02d s" % [int(total_seconds / 60), total_seconds % 60]
	var boss_result := "vaincu" if victory else "non vaincu"
	var reward := " · Récompense : 1 Éclat du Gardien" if victory else ""
	return "Durée : %s · Vague atteinte : %d/%d · Créatures vaincues : %d · Niveau : %d · Boss : %s · Reliques : %d%s\nVictoires : %d · Éclats : %d · Meilleur score : %d" % [time_text, wave, catalog.content.waves.size(), defeated, level, boss_result, relic_inventory.size(), reward, profile.wins, profile.shards, profile.bestKills]

func _load_profile() -> void:
	if not FileAccess.file_exists("user://save.json"):
		return
	var file := FileAccess.open("user://save.json", FileAccess.READ)
	if file == null:
		return
	var saved: Variant = JSON.parse_string(file.get_as_text())
	if not saved is Dictionary:
		return
	if int(saved.get("schema_version", 1)) != 1:
		return
	for key in ["wins", "bestKills", "shards"]:
		var value: Variant = saved.get(key, 0)
		if value is int and value >= 0:
			profile[key] = value

func _save_profile() -> void:
	var file := FileAccess.open("user://save.json", FileAccess.WRITE)
	if file == null:
		push_warning("Unable to save profile: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(profile))

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
var enemies: Array[ValombreEnemy] = []
var drops: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var objective_type := "kills"
var objective_progress := 0
var objective_target := 12
var objective_complete := false

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

func _ready() -> void:
	main = get_parent()
	arena = main.get_node("Arena")
	player = arena.get_node("Player")
	catalog = main.catalog
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
		status_label.text = "ARMES\n%s\n\nRelique : aucune\nSynergies : aucune" % _find_definition("weapons", weapon_id).display_name
		status_label.visible = not status_label.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("special") and state == "playing":
		_use_hero_skill()

func _process(delta: float) -> void:
	if state != "playing":
		return
	elapsed += delta
	weapon_cooldown = maxf(0.0, weapon_cooldown - delta)
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	skill_cooldown = maxf(0.0, skill_cooldown - delta)
	if intermission > 0.0:
		intermission -= delta
		if intermission <= 0.0:
			_start_wave(wave + 1)
	else:
		_update_spawns(delta)
		_update_enemies(delta)
		_update_auto_attack()
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
	intermission = 0.0
	contact_cooldown = 0.0
	skill_cooldown = 0.0
	wave = 0
	elapsed = 0.0
	base_hp = float(stats.get("health", 100))
	bonus_max_hp = 0.0
	attack_speed_multiplier = 1.0
	range_bonus = 0.0
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
	if mode == "infinite" and number > 4:
		pending_spawns = [
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
		pending_spawns = (catalog.content.waves[number - 1] if number <= catalog.content.waves.size() else []).duplicate(true)
	if mode == "infinite" and number % 5 == 0:
		pending_spawns.append({"kind": "boss", "count": 1, "boss_id": ["guardian", "matriarch", "colossus"][(int(number / 5) - 1) % 3]})
	for index in range(pending_spawns.size()):
		var entry := pending_spawns[index]
		var count := int(entry.get("count", 1))
		for spawn_index in count:
			pending_spawns.append({"kind": str(entry.kind), "elite": entry.kind != "boss" and (spawn_index + 1) % (18 if mode == "infinite" else 24) == 0, "boss_id": entry.get("boss_id", "guardian")})
		pending_spawns[index] = {"kind": "__group_expanded__"}
	pending_spawns = pending_spawns.filter(func(item: Dictionary) -> bool: return item.kind != "__group_expanded__")
	spawn_clock = 1.0 if number == 1 else 0.62
	intermission = 0.0
	status_label.text = "Vague %d" % number

func _update_spawns(delta: float) -> void:
	if pending_spawns.is_empty() and enemies.is_empty():
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
		spawn_clock = 0.62

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
	if kind == "boss":
		enemy.radius = float(base.get("radius", 33))
		enemy.damage = float(base.get("slamDamage", 26))
		enemy.set_meta("boss_id", boss_id)
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
	for enemy in enemies:
		if not is_instance_valid(enemy):
			to_remove.append(enemy)
			continue
		var offset: Vector2 = player.position - enemy.position
		var distance := offset.length()
		if distance > enemy.radius + 17.0:
			var step := offset.normalized() * enemy.speed * delta
			_move_enemy_around_obstacles(enemy, step)
		elif contact_cooldown <= 0.0 and player.invulnerability <= 0.0:
			_damage_player(enemy.damage)
			contact_cooldown = 0.55
		if enemy.kind == "boss" and distance <= 108.0 and contact_cooldown <= 0.0 and player.invulnerability <= 0.0:
			_damage_player(enemy.damage)
			contact_cooldown = 0.55
	for enemy in to_remove:
		enemies.erase(enemy)
	if pending_spawns.is_empty() and enemies.is_empty() and intermission <= 0.0 and state == "playing":
		if mode == "waves" and wave >= catalog.content.waves.size():
			_spawn_enemy("boss", false, "guardian")

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
	var weapon: Dictionary = catalog.content.weapons[weapon_id]
	var target: ValombreEnemy
	var nearest := INF
	for enemy in enemies:
		var distance := player.position.distance_to(enemy.position)
		if distance < nearest:
			nearest = distance
			target = enemy
	var manual := Input.is_action_just_pressed("attack")
	if target and nearest <= float(weapon.get("range", 108.0)) + range_bonus and (weapon_cooldown <= 0.0 or manual):
		var base_damage := float(weapon.get("bruteDamage", 25) if target.kind == "brute" else weapon.get("ghoulDamage", 32))
		_damage_enemy(target, base_damage * damage_multiplier * (1.0 + (level - 1) * 0.005), weapon_id)
		weapon_cooldown = 1.0 / maxf(0.1, float(weapon.speed) * attack_speed_multiplier)
		player.facing = (target.position - player.position).normalized()

func _damage_enemy(enemy: ValombreEnemy, amount: float, _weapon: String) -> void:
	if not is_instance_valid(enemy):
		return
	enemy.hp -= roundf(amount)
	enemy.hit_flash = 0.18
	if enemy.hp <= 0.0:
		defeated += 1
		if enemy.kind == "boss":
			_enemy_drop_xp(enemy.position, 5.0)
			enemy.queue_free()
			enemies.erase(enemy)
			if mode == "infinite":
				intermission = 3.0
			else:
				_set_state("victory")
		else:
			_enemy_drop_xp(enemy.position, 1.0)
			_progress_objective("kills")
			if enemy.elite:
				_progress_objective("elite")
			enemy.queue_free()
			enemies.erase(enemy)

func _enemy_drop_xp(position: Vector2, value: float) -> void:
	var node := Sprite2D.new()
	node.texture = load("res://assets/xp.svg")
	node.scale = Vector2(0.18, 0.18)
	node.position = position + Vector2(rng.randf_range(-15, 15), rng.randf_range(-15, 15))
	arena.add_child(node)
	drops.append({"node": node, "value": value, "life": 18.0})

func _update_drops(delta: float) -> void:
	for index in range(drops.size() - 1, -1, -1):
		var drop: Dictionary = drops[index]
		drop.life -= delta
		if not is_instance_valid(drop.node) or drop.life <= 0.0:
			drop.node.queue_free()
			drops.remove_at(index)
			continue
		var distance: float = player.position.distance_to(drop.node.position)
		if distance <= pickup_range:
			var pull := player.position.direction_to(drop.node.position) * minf(240.0 * delta, distance)
			drop.node.position -= pull
		if player.position.distance_to(drop.node.position) <= 22.0:
			xp += float(drop.value)
			drop.node.queue_free()
			drops.remove_at(index)
			_progress_objective("xp")
			while xp >= next_xp:
				xp -= next_xp
				level += 1
				next_xp += 3.0
				pending_upgrades += 1
			var old_max_hp := max_hp
			max_hp = base_hp * (1.0 + (level - 1) * 0.01) + bonus_max_hp
			hp = minf(max_hp, hp + max_hp - old_max_hp)
			if pending_upgrades > 0:
				_show_level_up()
				return

func _show_level_up() -> void:
	_set_state("levelUp")
	var column: VBoxContainer = menu_panel.get_child(0)
	for child in column.get_children():
		if child is Button and child != start_button:
			child.queue_free()
	var choices: Array[GameDefinition] = []
	var pool: Array = catalog.definitions.upgrades.filter(func(item: GameDefinition) -> bool: return int(upgrade_ranks.get(str(item.id), 0)) < int(item.values.get("maxRanks", 10)))
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
	pending_upgrades -= 1
	if pending_upgrades > 0:
		_show_level_up()
	else:
		_set_state("playing")

func _damage_player(amount: float) -> void:
	hp -= maxf(1.0, amount * (1.0 - defense))
	player.invulnerability = 0.55
	if hp <= 0.0:
		hp = 0.0
		_set_state("defeat")

func _use_hero_skill() -> void:
	if hero_id != "sentinel" or skill_cooldown > 0.0:
		return
	skill_cooldown = 5.0
	var forward := player.facing
	for enemy in enemies:
		var offset := enemy.position - player.position
		var forward_distance := offset.dot(forward)
		var side_distance := absf(offset.cross(forward))
		if forward_distance >= 0.0 and forward_distance <= 190.0 and side_distance <= 17.0:
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
			status_label.text = "Choisissez votre héros, votre arme, le mode et la difficulté.\nWASD / flèches · E capacité · Maj esquive · Échap pause"
			start_button.text = "Entrer dans la forêt"
		"paused":
			title_label.text = "LA CHASSE ATTEND"
			status_label.text = "Échap pour reprendre"
			start_button.text = "Reprendre la chasse"
		"levelUp":
			title_label.text = "UNE NOUVELLE FORCE"
			status_label.text = "Choisissez une amélioration."
			start_button.visible = false
		"victory":
			title_label.text = "VALOMBRE EST LIBÉRÉE"
			status_label.text = "Ennemis vaincus : %d · niveau %d" % [defeated, level]
			start_button.text = "Rejouer"
		"defeat":
			title_label.text = "LA FORÊT VOUS REPREND"
			status_label.text = "Ennemis vaincus : %d · vague %d" % [defeated, wave]
			start_button.text = "Rejouer"
	if state != "levelUp":
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
	hud.text = "PV %d/%d\nNiveau %d · XP %d/%d\nVague %d · %s · %s\nÉliminations %d" % [ceili(hp), ceili(max_hp), level, int(xp), int(next_xp), wave, difficulty_id.capitalize(), objective, defeated]

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
	if objective_type != target or objective_complete:
		return
	objective_progress = mini(objective_target, objective_progress + 1)
	if objective_progress >= objective_target:
		objective_complete = true
		hp = minf(max_hp, hp + ceili(max_hp * 0.18))
		status_label.text = "Objectif accompli · +18 % PV"

extends RefCounted
class_name ContentCatalog

const CONTENT_PATH := "res://data/CONTENT_DATA.json"
const REQUIRED_SECTIONS := {
	"states": TYPE_DICTIONARY,
	"difficulties": TYPE_DICTIONARY,
	"config": TYPE_DICTIONARY,
	"bosses": TYPE_DICTIONARY,
	"weapons": TYPE_DICTIONARY,
	"heroes": TYPE_DICTIONARY,
	"bestiary": TYPE_DICTIONARY,
	"eliteAffixes": TYPE_DICTIONARY,
	"relics": TYPE_ARRAY,
	"upgrades": TYPE_ARRAY,
	"synergies": TYPE_ARRAY,
	"waves": TYPE_ARRAY,
}

var content: Dictionary = {}
var definitions: Dictionary = {}
var validation_errors: PackedStringArray = []

func load_content() -> bool:
	validation_errors.clear()
	definitions.clear()
	var file := FileAccess.open(CONTENT_PATH, FileAccess.READ)
	if file == null:
		validation_errors.append("Unable to open %s" % CONTENT_PATH)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		validation_errors.append("Content root must be a JSON object")
		return false
	content = parsed
	for section in REQUIRED_SECTIONS:
		if not content.has(section) or typeof(content[section]) != REQUIRED_SECTIONS[section]:
			validation_errors.append("Missing or invalid content section: %s" % section)
	if not validation_errors.is_empty():
		return false
	for key in ["player", "combat", "enemies", "boss", "drops", "arena"]:
		if not content.config.has(key) or not (content.config[key] is Dictionary):
			validation_errors.append("Missing or invalid config group: config.%s" % key)
	if not validation_errors.is_empty():
		return false
	_build_definitions("heroes", content.heroes)
	_build_definitions("weapons", content.weapons)
	_build_definitions("enemies", content.bestiary)
	_build_definitions("bosses", content.bosses)
	_build_definitions("elite_affixes", content.eliteAffixes)
	_build_definitions("difficulties", content.difficulties)
	_build_definitions("relics", content.relics)
	_build_definitions("upgrades", content.upgrades)
	_build_definitions("synergies", content.synergies)
	_build_definitions("waves", content.waves)
	_validate_records()
	return validation_errors.is_empty()

func _build_definitions(group_name: String, records: Variant) -> void:
	var group: Array[GameDefinition] = []
	if records is Dictionary:
		for record_id in records:
			if not (records[record_id] is Dictionary):
				validation_errors.append("%s.%s must be an object" % [group_name, record_id])
				continue
			var record: Dictionary = records[record_id]
			var source_record: Dictionary = record
			if group_name == "enemies" and content.config.enemies.has(record_id):
				var merged: Dictionary = content.config.enemies[record_id].duplicate(true)
				merged.merge(record, true)
				record = merged
			var definition := _make_definition(group_name, str(record_id), record)
			if group_name == "enemies":
				definition.source_data = source_record.duplicate(true)
			group.append(definition)
	elif records is Array:
		for index in records.size():
			var record: Dictionary
			var record_id := "%s_%02d" % [group_name, index + 1]
			if group_name == "waves":
				if not (records[index] is Array):
					validation_errors.append("waves[%d] must be an array" % index)
					continue
				record = {"groups": records[index]}
				record_id = str(index + 1)
			else:
				if not (records[index] is Dictionary):
					validation_errors.append("%s[%d] must be an object" % [group_name, index])
					continue
				record = records[index]
				record_id = str(record.get("id", record_id))
			group.append(_make_definition(group_name, record_id, record))
	definitions[group_name] = group

func _make_definition(group_name: String, record_id: String, record: Dictionary) -> GameDefinition:
	match group_name:
		"heroes": return HeroDefinition.create_resource(record_id, record)
		"weapons": return WeaponDefinition.create_resource(record_id, record)
		"enemies": return EnemyDefinition.create_resource(record_id, record)
		"bosses": return BossDefinition.create_resource(record_id, record)
		"elite_affixes": return EliteAffixDefinition.create_resource(record_id, record)
		"difficulties": return DifficultyDefinition.create_resource(record_id, record)
		"relics": return RelicDefinition.create_resource(record_id, record)
		"upgrades": return UpgradeDefinition.create_resource(record_id, record)
		"synergies": return SynergyDefinition.create_resource(record_id, record)
		"waves": return WaveDefinition.create_resource(record_id, record)
	return GameDefinition.from_record(record_id, record)

func _validate_records() -> void:
	for group_name in ["heroes", "weapons", "enemies", "bosses", "elite_affixes", "difficulties", "relics", "upgrades", "synergies", "waves"]:
		var seen: Dictionary = {}
		for definition: GameDefinition in definitions.get(group_name, []):
			var id := str(definition.id)
			if id.is_empty() or seen.has(id):
				validation_errors.append("%s contains an empty or duplicate id: %s" % [group_name, id])
			seen[id] = true
			if definition.display_name.strip_edges().is_empty():
				validation_errors.append("%s.%s has no display name" % [group_name, id])
			_validate_definition(group_name, definition)
	_validate_references()

func _validate_definition(group_name: String, definition: GameDefinition) -> void:
	var id := str(definition.id)
	match group_name:
		"heroes":
			var hero := definition as HeroDefinition
			_require_positive_number("heroes.%s.health" % id, hero.source_data, "health")
			_require_positive_number("heroes.%s.speed" % id, hero.source_data, "speed")
			_check_positive("heroes.%s.health" % id, hero.health)
			_check_positive("heroes.%s.speed" % id, hero.speed)
		"weapons":
			var weapon := definition as WeaponDefinition
			for key in ["range", "speed", "ghoulDamage", "bruteDamage", "arc"]:
				_require_numeric("weapons.%s.%s" % [id, key], weapon.source_data, key)
			_check_positive("weapons.%s.range" % id, weapon.reach)
			_check_positive("weapons.%s.speed" % id, weapon.attack_speed)
			_check_positive("weapons.%s.ghoulDamage" % id, weapon.ghoul_damage)
			_check_positive("weapons.%s.bruteDamage" % id, weapon.brute_damage)
		"enemies":
			var enemy := definition as EnemyDefinition
			if not enemy.sprite_path.is_empty() and not FileAccess.file_exists(enemy.sprite_path):
				validation_errors.append("enemies.%s references missing sprite %s" % [id, enemy.sprite_path])
			if not id.begins_with("boss:"):
				for key in ["health", "speed", "radius", "damage"]:
					_require_positive_number("enemies.%s.%s" % [id, key], enemy.behavior_data, key)
				_check_positive("enemies.%s.health" % id, enemy.health)
				_check_positive("enemies.%s.radius" % id, enemy.radius)
		"bosses":
			var boss := definition as BossDefinition
			for key in ["health", "speed", "radius"]:
				_require_positive_number("bosses.%s.%s" % [id, key], boss.source_data, key)
			_check_positive("bosses.%s.health" % id, boss.health)
			_check_positive("bosses.%s.radius" % id, boss.radius)
			if not FileAccess.file_exists(boss.sprite_path):
				validation_errors.append("bosses.%s references missing sprite %s" % [id, boss.sprite_path])
			if boss.behavior.strip_edges().is_empty():
				validation_errors.append("bosses.%s has no behavior" % id)
		"elite_affixes":
			var affix := definition as EliteAffixDefinition
			for key in ["health", "speed", "damage"]:
				_require_positive_number("eliteAffixes.%s.%s" % [id, key], affix.source_data, key)
			_check_positive("eliteAffixes.%s.health" % id, affix.health_multiplier)
			_check_positive("eliteAffixes.%s.speed" % id, affix.speed_multiplier)
			_check_positive("eliteAffixes.%s.damage" % id, affix.damage_multiplier)
		"difficulties":
			var difficulty := definition as DifficultyDefinition
			for key in ["health", "damage", "speed", "attackSpeed", "projectileSpeed", "spawnCapacity", "itemDrop"]:
				_require_positive_number("difficulties.%s.%s" % [id, key], difficulty.source_data, key)
			for field in [difficulty.health_multiplier, difficulty.damage_multiplier, difficulty.speed_multiplier, difficulty.attack_speed_multiplier, difficulty.projectile_speed_multiplier, difficulty.spawn_capacity_multiplier, difficulty.item_drop_multiplier]:
				if not _is_finite_number(field) or field <= 0.0:
					validation_errors.append("difficulties.%s contains an invalid multiplier" % id)
		"relics":
			var relic := definition as RelicDefinition
			if relic.effect.strip_edges().is_empty() or not (relic.source_data.get("effect") is String) or not _is_finite_number(relic.source_data.get("value")):
				validation_errors.append("relics.%s has an invalid effect or value" % id)
		"upgrades":
			var upgrade := definition as UpgradeDefinition
			if not _is_positive_integer(upgrade.source_data.get("maxRanks")) or upgrade.max_ranks <= 0 or not _is_finite_number(upgrade.bonus) or upgrade.kind.is_empty():
				validation_errors.append("upgrades.%s has invalid rank data" % id)
		"synergies":
			var synergy := definition as SynergyDefinition
			if str(synergy.weapon_id).is_empty() or str(synergy.relic_id).is_empty():
				validation_errors.append("synergies.%s has missing prerequisites" % id)
		"waves":
			var wave := definition as WaveDefinition
			var source_groups: Array[Dictionary] = wave.groups
			if not (source_groups is Array) or source_groups.is_empty():
				validation_errors.append("waves[%s] is empty" % id)
			for group in source_groups:
				if not (group is Dictionary):
					validation_errors.append("waves[%s] contains a non-object group" % id)
					continue
				if str(group.get("kind", "")).is_empty() or not _is_positive_integer(group.get("count")):
					validation_errors.append("waves[%s] contains a group with invalid kind/count" % id)

func _validate_references() -> void:
	var weapon_ids := _definition_ids("weapons")
	var enemy_ids := _definition_ids("enemies")
	var boss_ids := _definition_ids("bosses")
	var relic_ids := _definition_ids("relics")
	for definition: GameDefinition in definitions.get("synergies", []):
		var synergy := definition as SynergyDefinition
		if not weapon_ids.has(str(synergy.weapon_id)):
			validation_errors.append("synergies.%s references missing weapon %s" % [synergy.id, synergy.weapon_id])
		if not relic_ids.has(str(synergy.relic_id)):
			validation_errors.append("synergies.%s references missing relic %s" % [synergy.id, synergy.relic_id])
	for definition: GameDefinition in definitions.get("enemies", []):
		var enemy := definition as EnemyDefinition
		if str(enemy.id).begins_with("boss:") and not boss_ids.has(str(enemy.id).trim_prefix("boss:")):
			validation_errors.append("bestiary.%s references a missing boss" % enemy.id)
	for definition: GameDefinition in definitions.get("waves", []):
		var wave := definition as WaveDefinition
		for group in wave.groups:
			var kind := str(group.get("kind", ""))
			if kind != "boss" and not enemy_ids.has(kind):
				validation_errors.append("waves[%s] references missing enemy %s" % [wave.id, kind])
			if kind == "boss" and not boss_ids.has(str(group.get("boss_id", "guardian"))):
				validation_errors.append("waves[%s] references a missing boss" % wave.id)
	for enemy_id in content.config.enemies:
		if not (content.config.enemies[enemy_id] is Dictionary):
			continue
		if not content.bestiary.has(enemy_id) or str(enemy_id).begins_with("boss:"):
			validation_errors.append("config.enemies.%s has no bestiary record" % enemy_id)
	for hero_id in content.heroes:
		var hero_sprite := "sentinel" if str(hero_id) == "sentinel" else "hero" if str(hero_id) == "pilgrim" else ""
		if hero_sprite.is_empty() or not FileAccess.file_exists("res://assets/%s.svg" % hero_sprite):
			validation_errors.append("heroes.%s references no available portrait" % hero_id)
	for weapon_id in weapon_ids:
		for path in ["res://assets/weapons/%s.svg" % weapon_id, "res://assets/held-weapons/%s.svg" % weapon_id]:
			if not FileAccess.file_exists(path):
				validation_errors.append("weapons.%s references missing art %s" % [weapon_id, path])
	for relic_id in relic_ids:
		var icon_path := "res://assets/relics/%s.svg" % relic_id
		if not FileAccess.file_exists(icon_path):
			validation_errors.append("relics.%s references missing icon %s" % [relic_id, icon_path])

func _definition_ids(group_name: String) -> PackedStringArray:
	var ids := PackedStringArray()
	for definition: GameDefinition in definitions.get(group_name, []):
		ids.append(str(definition.id))
	return ids

func _check_positive(label: String, value: float) -> void:
	if not _is_finite_number(value) or value <= 0.0:
		validation_errors.append("%s must be positive and finite" % label)

func _require_numeric(label: String, record: Dictionary, field: String) -> void:
	if not record.has(field) or not _is_finite_number(record[field]):
		validation_errors.append("%s must be numeric" % label)

func _require_positive_number(label: String, record: Dictionary, field: String) -> void:
	if not record.has(field) or not _is_finite_number(record.get(field)) or float(record.get(field, 0.0)) <= 0.0:
		validation_errors.append("%s must be positive and finite" % label)

func _is_positive_integer(value: Variant) -> bool:
	return _is_finite_number(value) and float(value) > 0.0 and is_equal_approx(float(value), roundf(float(value)))

func _is_finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func section(section_name: String) -> Dictionary:
	return content.get(section_name, {})

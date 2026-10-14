extends GameDefinition
class_name WeaponDefinition

@export var reach := 0.0
@export var attack_speed := 0.0
@export var ghoul_damage := 0.0
@export var brute_damage := 0.0
@export var facing_threshold := 0.0
@export var attributes: Dictionary = {}

static func create_resource(record_id: String, record: Dictionary) -> WeaponDefinition:
	var item := WeaponDefinition.new()
	item.id = StringName(record_id)
	item.display_name = str(record.get("name", record_id))
	item.reach = float(record.get("range", 0.0))
	item.attack_speed = float(record.get("speed", 0.0))
	item.ghoul_damage = float(record.get("ghoulDamage", 0.0))
	item.brute_damage = float(record.get("bruteDamage", 0.0))
	item.facing_threshold = float(record.get("arc", 0.0))
	item.attributes = record.duplicate(true)
	item.values = record.duplicate(true)
	item.values["id"] = record_id
	item.source_data = record.duplicate(true)
	return item

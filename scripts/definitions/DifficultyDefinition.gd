extends GameDefinition
class_name DifficultyDefinition

@export var health_multiplier := 1.0
@export var damage_multiplier := 1.0
@export var speed_multiplier := 1.0
@export var attack_speed_multiplier := 1.0
@export var projectile_speed_multiplier := 1.0
@export var spawn_capacity_multiplier := 1.0
@export var item_drop_multiplier := 1.0

static func create_resource(record_id: String, record: Dictionary) -> DifficultyDefinition:
	var item := DifficultyDefinition.new()
	item.id = StringName(record_id)
	item.display_name = str(record.get("name", record_id.capitalize()))
	item.health_multiplier = float(record.get("health", 1.0))
	item.damage_multiplier = float(record.get("damage", 1.0))
	item.speed_multiplier = float(record.get("speed", 1.0))
	item.attack_speed_multiplier = float(record.get("attackSpeed", 1.0))
	item.projectile_speed_multiplier = float(record.get("projectileSpeed", 1.0))
	item.spawn_capacity_multiplier = float(record.get("spawnCapacity", 1.0))
	item.item_drop_multiplier = float(record.get("itemDrop", 1.0))
	item.values = record.duplicate(true)
	item.values["id"] = record_id
	item.source_data = record.duplicate(true)
	return item

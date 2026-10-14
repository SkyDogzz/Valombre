extends GameDefinition
class_name EnemyDefinition

@export var health := 0.0
@export var speed := 0.0
@export var radius := 0.0
@export var contact_damage := 0.0
@export var sprite_path := ""
@export var behavior_data: Dictionary = {}

static func create_resource(record_id: String, record: Dictionary) -> EnemyDefinition:
	var item := EnemyDefinition.new()
	item.id = StringName(record_id)
	item.display_name = str(record.get("name", record_id))
	item.health = float(record.get("health", 0.0))
	item.speed = float(record.get("speed", 0.0))
	item.radius = float(record.get("radius", 0.0))
	item.contact_damage = float(record.get("damage", 0.0))
	item.sprite_path = "res://assets/%s.svg" % str(record.get("sprite", record_id))
	item.behavior_data = record.duplicate(true)
	item.values = record.duplicate(true)
	item.values["id"] = record_id
	item.source_data = record.duplicate(true)
	return item

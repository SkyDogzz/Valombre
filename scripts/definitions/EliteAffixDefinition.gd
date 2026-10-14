extends GameDefinition
class_name EliteAffixDefinition

@export var health_multiplier := 1.0
@export var speed_multiplier := 1.0
@export var damage_multiplier := 1.0
@export var tint := Color.WHITE

static func create_resource(record_id: String, record: Dictionary) -> EliteAffixDefinition:
	var item := EliteAffixDefinition.new()
	item.id = StringName(record_id)
	item.display_name = str(record.get("name", record_id))
	item.health_multiplier = float(record.get("health", 1.0))
	item.speed_multiplier = float(record.get("speed", 1.0))
	item.damage_multiplier = float(record.get("damage", 1.0))
	item.tint = Color(str(record.get("color", "#ffffff")))
	item.values = record.duplicate(true)
	item.values["id"] = record_id
	item.source_data = record.duplicate(true)
	return item

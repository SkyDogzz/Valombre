extends GameDefinition
class_name HeroDefinition

@export var health := 100.0
@export var speed := 190.0
@export var class_name_text := ""

static func create_resource(record_id: String, record: Dictionary) -> HeroDefinition:
	var item := HeroDefinition.new()
	item.id = StringName(record_id)
	item.display_name = str(record.get("name", record_id))
	item.health = float(record.get("health", 100.0))
	item.speed = float(record.get("speed", 190.0))
	item.class_name_text = str(record.get("className", ""))
	item.values = record.duplicate(true)
	item.values["id"] = record_id
	item.source_data = record.duplicate(true)
	return item

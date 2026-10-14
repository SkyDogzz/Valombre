extends GameDefinition
class_name RelicDefinition

@export var effect := ""
@export var effect_value := 0.0

static func create_resource(record_id: String, record: Dictionary) -> RelicDefinition:
	var item := RelicDefinition.new()
	item.id = StringName(record_id)
	item.display_name = str(record.get("name", record_id))
	item.effect = str(record.get("effect", ""))
	item.effect_value = float(record.get("value", 0.0))
	item.values = record.duplicate(true)
	item.values["id"] = record_id
	item.source_data = record.duplicate(true)
	return item

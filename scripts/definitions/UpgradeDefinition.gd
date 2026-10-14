extends GameDefinition
class_name UpgradeDefinition

@export var max_ranks := 0
@export var bonus := 0.0
@export var kind := ""

static func create_resource(record_id: String, record: Dictionary) -> UpgradeDefinition:
	var item := UpgradeDefinition.new()
	item.id = StringName(record_id)
	item.display_name = str(record.get("name", record_id))
	item.max_ranks = int(record.get("maxRanks", 0))
	item.bonus = float(record.get("bonus", 0.0))
	item.kind = str(record.get("kind", ""))
	item.values = record.duplicate(true)
	item.values["id"] = record_id
	item.source_data = record.duplicate(true)
	return item

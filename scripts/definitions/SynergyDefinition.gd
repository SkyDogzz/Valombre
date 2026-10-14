extends GameDefinition
class_name SynergyDefinition

@export var weapon_id: StringName
@export var relic_id: StringName
@export var effect_values: Dictionary = {}

static func create_resource(record_id: String, record: Dictionary) -> SynergyDefinition:
	var item := SynergyDefinition.new()
	item.id = StringName(record_id)
	item.display_name = str(record.get("name", record_id))
	item.weapon_id = StringName(str(record.get("weaponId", "")))
	item.relic_id = StringName(str(record.get("relicId", "")))
	item.effect_values = record.duplicate(true)
	item.values = record.duplicate(true)
	item.values["id"] = record_id
	item.source_data = record.duplicate(true)
	return item

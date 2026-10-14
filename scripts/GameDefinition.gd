extends Resource
class_name GameDefinition

@export var id: StringName
@export var display_name: String
@export var values: Dictionary = {}
@export var source_data: Dictionary = {}

static func from_record(record_id: String, record: Dictionary) -> GameDefinition:
	var definition := GameDefinition.new()
	definition.id = StringName(record_id)
	definition.display_name = str(record.get("name", record_id))
	definition.values = record.duplicate(true)
	definition.values["id"] = record_id
	definition.source_data = record.duplicate(true)
	return definition

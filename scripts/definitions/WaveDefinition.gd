extends GameDefinition
class_name WaveDefinition

@export var wave_number := 0
@export var groups: Array[Dictionary] = []

static func create_resource(record_id: String, record: Dictionary) -> WaveDefinition:
	var item := WaveDefinition.new()
	item.id = StringName(record_id)
	item.wave_number = int(record_id)
	item.display_name = "Vague %s" % record_id
	for group in record.get("groups", []):
		if group is Dictionary:
			item.groups.append(group.duplicate(true))
	item.values = {"groups": item.groups.duplicate(true), "id": record_id}
	item.source_data = record.duplicate(true)
	return item

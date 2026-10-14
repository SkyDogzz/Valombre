extends RefCounted
class_name ContentCatalog

const CONTENT_PATH := "res://data/CONTENT_DATA.json"
const REQUIRED_SECTIONS := {
	"states": TYPE_DICTIONARY,
	"difficulties": TYPE_DICTIONARY,
	"config": TYPE_DICTIONARY,
	"bosses": TYPE_DICTIONARY,
	"weapons": TYPE_DICTIONARY,
	"relics": TYPE_ARRAY,
	"upgrades": TYPE_ARRAY,
	"synergies": TYPE_ARRAY,
	"waves": TYPE_ARRAY,
}

var content: Dictionary = {}
var definitions: Dictionary = {}
var validation_errors: PackedStringArray = []

func load_content() -> bool:
	var file := FileAccess.open(CONTENT_PATH, FileAccess.READ)
	if file == null:
		validation_errors.append("Unable to open %s" % CONTENT_PATH)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		validation_errors.append("Content root must be a JSON object")
		return false
	content = parsed
	for section in REQUIRED_SECTIONS:
		if not content.has(section) or typeof(content[section]) != REQUIRED_SECTIONS[section]:
			validation_errors.append("Missing or invalid content section: %s" % section)
	if not content.has("config"):
		return false
	for key in ["player", "combat", "enemies", "arena"]:
		if not content["config"].has(key):
			validation_errors.append("Missing config group: %s" % key)
	_build_definitions("heroes", content.get("heroes", {}))
	_build_definitions("weapons", content.get("weapons", {}))
	_build_definitions("enemies", content.get("bestiary", {}))
	_build_definitions("bosses", content.get("bosses", {}))
	_build_definitions("elite_affixes", content.get("eliteAffixes", {}))
	_build_definitions("relics", content.get("relics", []))
	_build_definitions("upgrades", content.get("upgrades", []))
	_build_definitions("synergies", content.get("synergies", []))
	_build_definitions("waves", content.get("waves", []))
	return validation_errors.is_empty()

func _build_definitions(group_name: String, records: Variant) -> void:
	var group: Array[GameDefinition] = []
	if records is Dictionary:
		for record_id in records:
			if records[record_id] is Dictionary:
				group.append(GameDefinition.from_record(str(record_id), records[record_id]))
	elif records is Array:
		for index in records.size():
			if records[index] is Dictionary:
				var record_id := str(records[index].get("id", "%s_%02d" % [group_name, index + 1]))
				group.append(GameDefinition.from_record(record_id, records[index]))
	definitions[group_name] = group

func section(section_name: String) -> Dictionary:
	return content.get(section_name, {})

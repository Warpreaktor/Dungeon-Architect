class_name DeveloperMode
extends RefCounted

const SETTINGS_PATH: String = "user://editor_state.cfg"
const SECTION: String = "developer"
const LOADOUT_SECTION: String = "developer_loadouts"


static func is_available() -> bool:
	return OS.has_feature("editor")


static func is_enabled() -> bool:
	if not is_available():
		return false
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return false
	return bool(config.get_value(SECTION, "enabled", false))


static func set_enabled(enabled: bool) -> bool:
	if not is_available():
		return false
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SECTION, "enabled", enabled)
	return config.save(SETTINGS_PATH) == OK


static func _loadout_key(map_id: String, party_ids: Array[String]) -> String:
	return "%s__%s" % [map_id, "_".join(party_ids)]


static func loadout(map_id: String, party_ids: Array[String]) -> Dictionary:
	if not is_enabled() or map_id.is_empty():
		return {}
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return {}
	var value: Variant = config.get_value(LOADOUT_SECTION, _loadout_key(map_id, party_ids), {})
	return value.duplicate(true) if value is Dictionary else {}


static func save_loadout(map_id: String, party_ids: Array[String], snapshot: Dictionary) -> bool:
	if not is_enabled() or map_id.is_empty() or snapshot.is_empty():
		return false
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(LOADOUT_SECTION, _loadout_key(map_id, party_ids), snapshot)
	return config.save(SETTINGS_PATH) == OK

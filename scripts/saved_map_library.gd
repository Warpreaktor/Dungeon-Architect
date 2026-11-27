class_name SavedMapLibrary
extends RefCounted

const DIRECTORY := "user://maps"


static func load_all(directory: String = DIRECTORY) -> Dictionary:
	var result: Dictionary = {}
	if OfficialCampaignLibrary.is_packaged_path(directory):
		return result
	var folder: DirAccess = DirAccess.open(directory)
	if folder == null:
		return result
	var filenames: PackedStringArray = folder.get_files()
	filenames.sort()
	for filename in filenames:
		if not filename.ends_with(".json"):
			continue
		var file: FileAccess = FileAccess.open(directory.path_join(filename), FileAccess.READ)
		if file == null:
			continue
		var raw: Variant = JSON.parse_string(file.get_as_text())
		if not (raw is Dictionary):
			continue
		var map_ref: DungeonMap = DungeonMap.from_dict(raw)
		if map_ref == null or map_ref.map_id.is_empty() or OfficialCampaignLibrary.is_official_id(map_ref.map_id) or result.has(map_ref.map_id):
			continue
		result[map_ref.map_id] = map_ref
	return result


static func load_for_game(directory: String = DIRECTORY) -> Dictionary:
	var result: Dictionary = load_all(directory)
	result.merge(OfficialCampaignLibrary.load_maps(), true)
	return result

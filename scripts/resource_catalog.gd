class_name ResourceCatalog
extends RefCounted

const RESOURCE_EXTENSION: String = ".tres"


static func list_ids(directory: String) -> Array[String]:
	var ids: Array[String] = []
	for filename in ResourceLoader.list_directory(directory):
		if filename.ends_with(RESOURCE_EXTENSION):
			ids.append(filename.trim_suffix(RESOURCE_EXTENSION))
	ids.sort()
	return ids


static func load_by_id(directory: String, resource_id: String) -> Resource:
	if not is_valid_id(resource_id):
		return null
	var path: String = directory.path_join(resource_id + RESOURCE_EXTENSION)
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path)


static func is_valid_id(resource_id: String) -> bool:
	if resource_id.is_empty():
		return false
	const VALID_CHARS: String = "abcdefghijklmnopqrstuvwxyz0123456789_"
	for character in resource_id:
		if not VALID_CHARS.contains(character):
			return false
	return true

class_name ResourceCatalog
extends RefCounted

const RESOURCE_EXTENSION: String = ".tres"

static var _ids_by_directory: Dictionary = {}
static var _resources_by_directory: Dictionary = {}


static func list_ids(directory: String) -> Array[String]:
	if not _ids_by_directory.has(directory):
		var ids: Array[String] = []
		for filename in ResourceLoader.list_directory(directory):
			if filename.ends_with(RESOURCE_EXTENSION):
				ids.append(filename.trim_suffix(RESOURCE_EXTENSION))
		ids.sort()
		_ids_by_directory[directory] = ids
	var cached: Array[String] = _ids_by_directory[directory]
	return cached.duplicate()


static func load_by_id(directory: String, resource_id: String) -> Resource:
	if resource_id.is_empty():
		return null
	if not _resources_by_directory.has(directory):
		_resources_by_directory[directory] = {}
	var resources: Dictionary = _resources_by_directory[directory]
	if resources.has(resource_id):
		return resources[resource_id] as Resource
	if not is_valid_id(resource_id):
		return null
	var path: String = directory.path_join(resource_id + RESOURCE_EXTENSION)
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = ResourceLoader.load(path)
	if resource != null:
		resources[resource_id] = resource
	return resource


static func warm(directory: String) -> void:
	for resource_id in list_ids(directory):
		load_by_id(directory, resource_id)


static func is_valid_id(resource_id: String) -> bool:
	if resource_id.is_empty():
		return false
	const VALID_CHARS: String = "abcdefghijklmnopqrstuvwxyz0123456789_"
	for character in resource_id:
		if not VALID_CHARS.contains(character):
			return false
	return true

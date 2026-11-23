class_name CampaignLibrary
extends RefCounted

const DIRECTORY := "user://campaigns"
const FILE_SUFFIX := ".json"
const BACKUP_SUFFIX := ".json.bak"
const TEMP_SUFFIX := ".json.tmp"

var directory: String
var last_error: String = ""


func _init(library_directory: String = DIRECTORY) -> void:
	directory = library_directory


func create_campaign(name: String, first_map_id: String, maps_by_id: Dictionary) -> CampaignDefinition:
	last_error = ""
	var campaign: CampaignDefinition = CampaignDefinition.create(name, first_map_id)
	if campaign == null:
		last_error = "Невозможно создать кампанию: проверь название и стартовую карту."
		return null
	if not save_campaign(campaign, maps_by_id):
		return null
	return campaign


func save_campaign(campaign: CampaignDefinition, maps_by_id: Dictionary) -> bool:
	last_error = ""
	if campaign == null or not campaign.has_valid_maps(maps_by_id):
		last_error = "Неверные данные кампании или отсутствует одна из её карт."
		return false

	var existing: Dictionary = load_all(maps_by_id)
	if not last_error.is_empty():
		return false
	for other_id in existing:
		if other_id == campaign.campaign_id:
			continue
		var other: CampaignDefinition = existing[other_id]
		for map_id in campaign.map_ids:
			if other.map_ids.has(map_id):
				last_error = "Карта %s уже принадлежит кампании %s." % [map_id, other.display_name]
				return false

	if not DirAccess.dir_exists_absolute(directory):
		var mkdir_result: int = DirAccess.make_dir_recursive_absolute(directory)
		if mkdir_result != OK:
			last_error = "Не удалось создать папку кампаний: %s" % error_string(mkdir_result)
			return false

	var serialized: String = JSON.stringify(campaign.to_dict(), "\t")
	var main_path: String = _path(campaign.campaign_id, FILE_SUFFIX)
	var backup_path: String = _path(campaign.campaign_id, BACKUP_SUFFIX)
	var temp_path: String = _path(campaign.campaign_id, TEMP_SUFFIX)
	if FileAccess.file_exists(main_path) and FileAccess.get_file_as_string(main_path) == serialized:
		return true

	var writer: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if writer == null:
		last_error = "Не удалось открыть временный файл: %s" % error_string(FileAccess.get_open_error())
		return false
	writer.store_string(serialized)
	writer.flush()
	var write_error: int = writer.get_error()
	writer = null
	if write_error != OK:
		last_error = "Ошибка записи кампании: %s" % error_string(write_error)
		return false
	if FileAccess.get_file_as_string(temp_path) != serialized or _read_file(temp_path, campaign.campaign_id, maps_by_id) == null:
		last_error = "Проверка временного файла кампании не пройдена."
		return false

	if FileAccess.file_exists(main_path):
		if _read_file(main_path, campaign.campaign_id, maps_by_id) != null:
			if FileAccess.file_exists(backup_path):
				var remove_error: int = DirAccess.remove_absolute(backup_path)
				if remove_error != OK:
					last_error = "Не удалось обновить резервную копию: %s" % error_string(remove_error)
					return false
			var backup_error: int = DirAccess.rename_absolute(main_path, backup_path)
			if backup_error != OK:
				last_error = "Не удалось сохранить прежнюю версию кампании: %s" % error_string(backup_error)
				return false
		else:
			var remove_error: int = DirAccess.remove_absolute(main_path)
			if remove_error != OK:
				last_error = "Не удалось заменить повреждённый файл: %s" % error_string(remove_error)
				return false

	var promote_error: int = DirAccess.rename_absolute(temp_path, main_path)
	if promote_error != OK:
		if not FileAccess.file_exists(main_path) and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, main_path)
		last_error = "Не удалось завершить сохранение кампании: %s" % error_string(promote_error)
		return false
	return true


func load_all(maps_by_id: Dictionary) -> Dictionary:
	last_error = ""
	var result: Dictionary = {}
	if not DirAccess.dir_exists_absolute(directory):
		return result
	var folder: DirAccess = DirAccess.open(directory)
	if folder == null:
		last_error = "Не удалось прочитать папку кампаний."
		return {}
	var campaign_ids: Dictionary = {}
	for filename in folder.get_files():
		var campaign_id: String = ""
		if filename.ends_with(BACKUP_SUFFIX):
			campaign_id = filename.trim_suffix(BACKUP_SUFFIX)
		elif filename.ends_with(FILE_SUFFIX):
			campaign_id = filename.trim_suffix(FILE_SUFFIX)
		else:
			continue
		if not CampaignDefinition.valid_campaign_id(campaign_id):
			last_error = "Неверное имя файла кампании: %s" % filename
			return {}
		campaign_ids[campaign_id] = true
	var sorted_ids: Array = campaign_ids.keys()
	sorted_ids.sort()
	var map_owners: Dictionary = {}
	for campaign_id in sorted_ids:
		var campaign: CampaignDefinition = _read_campaign(campaign_id, maps_by_id)
		if campaign == null:
			last_error = "Кампания %s повреждена или ссылается на отсутствующую карту." % campaign_id
			return {}
		for map_id in campaign.map_ids:
			if map_owners.has(map_id):
				last_error = "Карта %s указана сразу в нескольких кампаниях." % map_id
				return {}
			map_owners[map_id] = campaign_id
		result[campaign_id] = campaign
	return result


func load_campaign(campaign_id: String, maps_by_id: Dictionary) -> CampaignDefinition:
	var campaigns: Dictionary = load_all(maps_by_id)
	if not last_error.is_empty():
		return null
	var candidate: Variant = campaigns.get(campaign_id)
	return candidate if candidate is CampaignDefinition else null


func campaign_for_map(map_id: String, maps_by_id: Dictionary) -> CampaignDefinition:
	var campaigns: Dictionary = load_all(maps_by_id)
	if not last_error.is_empty():
		return null
	for campaign in campaigns.values():
		if campaign.map_ids.has(map_id):
			return campaign
	return null


func _path(campaign_id: String, suffix: String) -> String:
	return directory.path_join(campaign_id + suffix)


func _read_campaign(campaign_id: String, maps_by_id: Dictionary) -> CampaignDefinition:
	var campaign: CampaignDefinition = _read_file(_path(campaign_id, FILE_SUFFIX), campaign_id, maps_by_id)
	if campaign != null:
		return campaign
	return _read_file(_path(campaign_id, BACKUP_SUFFIX), campaign_id, maps_by_id)


func _read_file(path: String, expected_id: String, maps_by_id: Dictionary) -> CampaignDefinition:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var campaign: CampaignDefinition = CampaignDefinition.from_dict(parsed)
	if campaign == null or campaign.campaign_id != expected_id or not campaign.has_valid_maps(maps_by_id):
		return null
	return campaign

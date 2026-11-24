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


func diagnose_graph(maps_by_id: Dictionary) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var candidates: Dictionary = {}
	if DirAccess.dir_exists_absolute(directory):
		var folder: DirAccess = DirAccess.open(directory)
		if folder == null:
			issues.append({"severity": "error", "campaign_id": "", "map_id": "", "message": "Невозможно прочитать каталог кампаний."})
			return issues
		for filename in folder.get_files():
			var campaign_id: String = ""
			if filename.ends_with(BACKUP_SUFFIX):
				campaign_id = filename.trim_suffix(BACKUP_SUFFIX)
			elif filename.ends_with(FILE_SUFFIX):
				campaign_id = filename.trim_suffix(FILE_SUFFIX)
			else:
				continue
			if not CampaignDefinition.valid_campaign_id(campaign_id):
				issues.append({"severity": "error", "campaign_id": "", "map_id": "", "message": "Неверное имя файла кампании: %s." % filename})
				continue
			candidates[campaign_id] = true
	var campaigns: Dictionary = {}
	var ids: Array = candidates.keys()
	ids.sort()
	for campaign_id in ids:
		var campaign: CampaignDefinition = _read_definition(_path(campaign_id, FILE_SUFFIX), campaign_id)
		if campaign == null:
			campaign = _read_definition(_path(campaign_id, BACKUP_SUFFIX), campaign_id)
		if campaign == null:
			issues.append({"severity": "error", "campaign_id": campaign_id, "map_id": "", "message": "Повреждённая структура кампании или несовпадение ID."})
			continue
		campaigns[campaign_id] = campaign
	issues.append_array(CampaignGraphDiagnostics.analyze(campaigns, maps_by_id))
	return issues


func _read_definition(path: String, expected_id: String) -> CampaignDefinition:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var campaign: CampaignDefinition = CampaignDefinition.from_dict(parsed)
	return campaign if campaign != null and campaign.campaign_id == expected_id else null


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


func attach_map(campaign_id: String, map_id: String, maps_by_id: Dictionary) -> bool:
	last_error = ""
	if not maps_by_id.has(map_id):
		last_error = "Целевая карта отсутствует в библиотеке."
		return false
	var campaigns: Dictionary = load_all(maps_by_id)
	if not last_error.is_empty():
		return false
	var campaign: CampaignDefinition = campaigns.get(campaign_id)
	if campaign == null:
		last_error = "Кампания не найдена."
		return false
	for other in campaigns.values():
		if other.campaign_id != campaign_id and other.map_ids.has(map_id):
			last_error = "Карта уже принадлежит другой кампании."
			return false
	if campaign.map_ids.has(map_id):
		return true
	if not campaign.add_map(map_id):
		last_error = "Не удалось добавить карту в кампанию."
		return false
	return save_campaign(campaign, maps_by_id)


func legacy_linked_maps(map_id: String, maps_by_id: Dictionary) -> Array[String]:
	var linked: Array[String] = []
	if not maps_by_id.has(map_id):
		return linked
	var visited: Dictionary = {map_id: true}
	var pending: Array[String] = [map_id]
	while not pending.is_empty():
		var current: String = pending.pop_front()
		linked.append(current)
		var neighbors: Array[String] = []
		for entity in (maps_by_id[current] as DungeonMap).entities:
			var target: String = DungeonMap.exit_target_id(entity)
			if maps_by_id.has(target):
				neighbors.append(target)
		for source_id in maps_by_id:
			if source_id == current:
				continue
			for entity in (maps_by_id[source_id] as DungeonMap).entities:
				if DungeonMap.exit_target_id(entity) == current:
					neighbors.append(source_id)
					break
		for neighbor in neighbors:
			if not visited.has(neighbor):
				visited[neighbor] = true
				pending.append(neighbor)
	linked.sort()
	return linked


func assemble_legacy_campaign(name: String, start_map_id: String, selected_map_ids: Array[String], maps_by_id: Dictionary, existing_campaign_id: String = "") -> CampaignDefinition:
	last_error = ""
	var campaigns: Dictionary = load_all(maps_by_id)
	if not last_error.is_empty():
		return null
	var selected: Dictionary = {}
	for map_id in selected_map_ids:
		if not maps_by_id.has(map_id) or selected.has(map_id):
			last_error = "Некорректный состав карт кампании."
			return null
		selected[map_id] = true
	var campaign: CampaignDefinition = campaigns.get(existing_campaign_id) if not existing_campaign_id.is_empty() else null
	if not existing_campaign_id.is_empty() and campaign == null:
		last_error = "Кампания для присоединения не найдена."
		return null
	if not selected.has(start_map_id) and (campaign == null or campaign.start_map_id != start_map_id):
		last_error = "Стартовая карта должна входить в выбранный состав."
		return null
	var owner_by_map: Dictionary = {}
	for existing in campaigns.values():
		for member_id in existing.map_ids:
			owner_by_map[member_id] = existing.campaign_id
	for map_id in selected:
		if owner_by_map.has(map_id) and (campaign == null or owner_by_map[map_id] != campaign.campaign_id):
			last_error = "Карта %s принадлежит другой кампании." % map_id
			return null
	var all_members: Dictionary = selected.duplicate()
	if campaign != null:
		for member_id in campaign.map_ids:
			all_members[member_id] = true
	for map_id in all_members:
		for entity in (maps_by_id[map_id] as DungeonMap).entities:
			var target: String = DungeonMap.exit_target_id(entity)
			if not target.is_empty() and maps_by_id.has(target) and not all_members.has(target):
				last_error = "С карты %s есть переход на %s вне выбранной кампании." % [map_id, target]
				return null
	for other in campaigns.values():
		if campaign != null and other.campaign_id == campaign.campaign_id:
			continue
		for member_id in other.map_ids:
			for entity in (maps_by_id[member_id] as DungeonMap).entities:
				if all_members.has(DungeonMap.exit_target_id(entity)):
					last_error = "В выбранные карты ведёт переход из другой кампании."
					return null
	if campaign == null:
		campaign = CampaignDefinition.create(name, start_map_id)
		if campaign == null:
			last_error = "Укажите название и стартовую карту кампании."
			return null
	else:
		if not campaign.map_ids.has(start_map_id):
			last_error = "Стартовая карта существующей кампании не может измениться при присоединении."
			return null
	for map_id in selected:
		if not campaign.map_ids.has(map_id):
			campaign.add_map(map_id)
	if not save_campaign(campaign, maps_by_id):
		return null
	return campaign


func incoming_links(target_map_id: String, maps_by_id: Dictionary, exclude_map_id: String = "") -> Array[String]:
	var sources: Array[String] = []
	for map_id in maps_by_id:
		if map_id == exclude_map_id:
			continue
		var dungeon: DungeonMap = maps_by_id[map_id]
		for entity in dungeon.entities:
			if DungeonMap.exit_target_id(entity) == target_map_id:
				if not sources.has(map_id):
					sources.append(map_id)
				break
	sources.sort()
	return sources


func detach_map(campaign_id: String, map_id: String, maps_by_id: Dictionary) -> bool:
	last_error = ""
	var campaign: CampaignDefinition = load_campaign(campaign_id, maps_by_id)
	if campaign == null:
		if last_error.is_empty():
			last_error = "Кампания не найдена."
		return false
	if map_id == campaign.start_map_id:
		last_error = "Сначала назначьте другую стартовую карту."
		return false
	if not campaign.map_ids.has(map_id):
		last_error = "Карта не входит в кампанию."
		return false
	var links: Array[String] = incoming_links(map_id, maps_by_id, map_id)
	if not links.is_empty():
		last_error = "На карту ведёт переход из %s. Сначала уберите связь." % links[0]
		return false
	if not campaign.remove_map(map_id):
		last_error = "Не удалось исключить карту."
		return false
	return save_campaign(campaign, maps_by_id)


func delete_campaign(campaign_id: String, maps_by_id: Dictionary) -> bool:
	last_error = ""
	if load_campaign(campaign_id, maps_by_id) == null:
		if last_error.is_empty():
			last_error = "Кампания не найдена."
		return false
	var main_path: String = _path(campaign_id, FILE_SUFFIX)
	var backup_path: String = _path(campaign_id, BACKUP_SUFFIX)
	var staged_path: String = _path(campaign_id, ".json.deleting")
	if FileAccess.file_exists(staged_path):
		last_error = "Незавершённая операция удаления кампании."
		return false
	if FileAccess.file_exists(main_path):
		var move_error: int = DirAccess.rename_absolute(main_path, staged_path)
		if move_error != OK:
			last_error = "Не удалось подготовить удаление: %s" % error_string(move_error)
			return false
	if FileAccess.file_exists(backup_path):
		var backup_error: int = DirAccess.remove_absolute(backup_path)
		if backup_error != OK:
			if FileAccess.file_exists(staged_path):
				DirAccess.rename_absolute(staged_path, main_path)
			last_error = "Не удалось удалить резервную копию: %s" % error_string(backup_error)
			return false
	if FileAccess.file_exists(staged_path):
		var final_error: int = DirAccess.remove_absolute(staged_path)
		if final_error != OK:
			DirAccess.rename_absolute(staged_path, main_path)
			last_error = "Не удалось удалить кампанию: %s" % error_string(final_error)
			return false
	return true


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

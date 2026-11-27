class_name OfficialCampaignLibrary
extends RefCounted

const DIRECTORY := "res://data/official_campaigns"
const ID_PREFIX := "official_"


static func is_official_id(content_id: String) -> bool:
	return content_id.begins_with(ID_PREFIX)


static func is_packaged_path(path: String) -> bool:
	var absolute_path: String = ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
	var root: String = ProjectSettings.globalize_path(DIRECTORY).replace("\\", "/").simplify_path()
	return absolute_path.to_lower() == root.to_lower() or absolute_path.to_lower().begins_with(root.to_lower() + "/")


static func load_definitions(directory: String = DIRECTORY) -> Dictionary:
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("index.json")))
	if not (index is Dictionary) or index.get("schema_version") != 1 or not (index.get("campaigns") is Array):
		push_error("Некорректный каталог официальных кампаний: %s" % directory)
		return {}
	var campaigns: Dictionary = {}
	var map_owners: Dictionary = {}
	for entry in index["campaigns"]:
		var campaign: CampaignDefinition = CampaignDefinition.from_dict(entry)
		if campaign == null or not is_official_id(campaign.campaign_id) or campaigns.has(campaign.campaign_id):
			push_error("Некорректная запись официальной кампании: %s" % str(entry))
			return {}
		for map_id in campaign.map_ids:
			if not CampaignDefinition.valid_campaign_id(map_id) or is_official_id(map_id) or map_owners.has(map_id):
				push_error("Некорректный ID карты официальной кампании: %s" % map_id)
				return {}
			map_owners[map_id] = campaign.campaign_id
		for index_id in range(campaign.map_ids.size()):
			campaign.map_ids[index_id] = ID_PREFIX + campaign.map_ids[index_id]
		campaign.start_map_id = ID_PREFIX + campaign.start_map_id
		campaigns[campaign.campaign_id] = campaign
	return campaigns


static func source_path(map_id: String) -> String:
	return DIRECTORY.path_join("maps").path_join(map_id + ".json")


static func source_campaign(map_id: String) -> CampaignDefinition:
	for campaign in load_definitions().values():
		if campaign.map_ids.has(ID_PREFIX + map_id):
			var source: CampaignDefinition = CampaignDefinition.from_dict(campaign.to_dict())
			for index in range(source.map_ids.size()):
				source.map_ids[index] = source.map_ids[index].trim_prefix(ID_PREFIX)
			source.start_map_id = source.start_map_id.trim_prefix(ID_PREFIX)
			return source
	return null


static func editable_source_id(path: String) -> String:
	if not DeveloperMode.is_enabled() or not is_packaged_path(path):
		return ""
	var map_id: String = path.get_file().get_basename()
	if not CampaignDefinition.valid_campaign_id(map_id) or is_official_id(map_id):
		return ""
	var absolute_path: String = ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
	var expected_path: String = ProjectSettings.globalize_path(source_path(map_id)).replace("\\", "/").simplify_path()
	var same_path: bool = absolute_path.nocasecmp_to(expected_path) == 0 if OS.has_feature("windows") else absolute_path == expected_path
	if not same_path or source_campaign(map_id) == null:
		return ""
	return map_id


static func editable_source_paths() -> Array[String]:
	var paths: Array[String] = []
	if not DeveloperMode.is_enabled():
		return paths
	for campaign in load_definitions().values():
		for map_id in campaign.map_ids:
			paths.append(source_path(map_id.trim_prefix(ID_PREFIX)))
	paths.sort()
	return paths


static func load_maps(directory: String = DIRECTORY) -> Dictionary:
	var result: Dictionary = {}
	var campaigns: Dictionary = load_definitions(directory)
	for campaign in campaigns.values():
		var campaign_maps: Dictionary = {}
		for map_id in campaign.map_ids:
			var source_id: String = map_id.trim_prefix(ID_PREFIX)
			var path: String = directory.path_join("maps").path_join(source_id + ".json")
			var dungeon: DungeonMap = DungeonMap.from_dict(JSON.parse_string(FileAccess.get_file_as_string(path)))
			if dungeon == null or dungeon.map_id != source_id:
				push_error("Не удалось прочитать официальную карту: %s" % path)
				break
			dungeon.map_id = map_id
			var valid_links: bool = true
			for entity in dungeon.entities:
				var target: String = DungeonMap.exit_target_id(entity)
				if target.is_empty():
					continue
				var official_target: String = ID_PREFIX + target
				if not campaign.map_ids.has(official_target):
					push_error("Переход за пределы официальной кампании: %s → %s" % [source_id, target])
					valid_links = false
					break
				entity["properties"]["target_map_id"] = official_target
			if not valid_links:
				break
			var spawn: Vector2i = dungeon.find_entity_position("player_spawn")
			if not DungeonMap.valid_arrival_cell(dungeon, spawn):
				push_error("Отсутствует доступная точка старта официальной карты: %s" % path)
				break
			campaign_maps[map_id] = dungeon
		if campaign.has_valid_maps(campaign_maps):
			result.merge(campaign_maps)
	return result


static func load_campaigns(maps_by_id: Dictionary, directory: String = DIRECTORY) -> Dictionary:
	var result: Dictionary = {}
	for campaign in load_definitions(directory).values():
		if campaign.has_valid_maps(maps_by_id):
			result[campaign.campaign_id] = campaign
	return result

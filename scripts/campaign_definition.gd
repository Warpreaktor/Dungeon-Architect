class_name CampaignDefinition
extends RefCounted

const FORMAT_VERSION := 1

var campaign_id: String = ""
var display_name: String = ""
var start_map_id: String = ""
var map_ids: Array[String] = []


static func create(name: String, first_map_id: String) -> CampaignDefinition:
	var campaign := CampaignDefinition.new()
	campaign.campaign_id = "campaign_" + Crypto.new().generate_random_bytes(16).hex_encode()
	campaign.display_name = name.strip_edges()
	campaign.start_map_id = first_map_id
	campaign.map_ids = [first_map_id]
	return campaign if campaign.has_valid_structure() else null


func rename(new_name: String) -> bool:
	var normalized: String = new_name.strip_edges()
	if normalized.is_empty():
		return false
	display_name = normalized
	return true


func add_map(map_id: String) -> bool:
	if map_id.is_empty() or map_ids.has(map_id):
		return false
	map_ids.append(map_id)
	return true


func remove_map(map_id: String) -> bool:
	if map_id == start_map_id or not map_ids.has(map_id):
		return false
	map_ids.erase(map_id)
	return true


func set_start_map(map_id: String) -> bool:
	if not map_ids.has(map_id):
		return false
	start_map_id = map_id
	return true


func has_valid_structure() -> bool:
	if not valid_campaign_id(campaign_id) or display_name.strip_edges().is_empty():
		return false
	if start_map_id.is_empty() or map_ids.is_empty() or not map_ids.has(start_map_id):
		return false
	var seen: Dictionary = {}
	for map_id in map_ids:
		if map_id.is_empty() or seen.has(map_id):
			return false
		seen[map_id] = true
	return true


func has_valid_maps(maps_by_id: Dictionary) -> bool:
	if not has_valid_structure():
		return false
	for map_id in map_ids:
		if not maps_by_id.has(map_id):
			return false
		var map_ref: Variant = maps_by_id[map_id]
		if not (map_ref is DungeonMap) or map_ref.map_id != map_id:
			return false
	return true


func to_dict() -> Dictionary:
	return {
		"schema_version": FORMAT_VERSION,
		"campaign_id": campaign_id,
		"name": display_name,
		"start_map_id": start_map_id,
		"map_ids": map_ids.duplicate()
	}


static func from_dict(value: Variant) -> CampaignDefinition:
	if not (value is Dictionary):
		return null
	var version: Variant = value.get("schema_version")
	if typeof(version) != TYPE_INT and typeof(version) != TYPE_FLOAT:
		return null
	if float(version) != float(FORMAT_VERSION):
		return null
	if not (value.get("campaign_id") is String) or not (value.get("name") is String):
		return null
	if not (value.get("start_map_id") is String) or not (value.get("map_ids") is Array):
		return null
	var campaign := CampaignDefinition.new()
	campaign.campaign_id = value["campaign_id"]
	campaign.display_name = value["name"]
	campaign.start_map_id = value["start_map_id"]
	for item in value["map_ids"]:
		if not (item is String):
			return null
		campaign.map_ids.append(item)
	return campaign if campaign.has_valid_structure() else null


static func valid_campaign_id(value: String) -> bool:
	if value.is_empty() or value.length() > 128:
		return false
	for index in range(value.length()):
		var character: int = value.unicode_at(index)
		if not ((character >= 48 and character <= 57)
			or (character >= 65 and character <= 90)
			or (character >= 97 and character <= 122)
			or character == 45 or character == 95):
			return false
	return true

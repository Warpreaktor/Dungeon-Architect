class_name LootProfileCatalog
extends RefCounted

const DIRECTORY: String = "res://data/loot_profiles"
static var _prepared: bool = false


static func get_profile(profile_id: String) -> LootProfile:
	return ResourceCatalog.load_by_id(DIRECTORY, profile_id) as LootProfile


static func list_ids() -> Array[String]:
	return ResourceCatalog.list_ids(DIRECTORY)


static func prepare() -> void:
	if _prepared:
		return
	for profile_id in list_ids():
		var profile: LootProfile = get_profile(profile_id)
		if profile != null:
			profile.prepare()
	_prepared = true


static func for_source(entity: Dictionary) -> LootProfile:
	var properties: Dictionary = entity.get("properties", {})
	var explicit_id: String = str(properties.get("loot_profile_id", ""))
	if not explicit_id.is_empty():
		var explicit_profile: LootProfile = get_profile(explicit_id)
		if explicit_profile != null:
			return explicit_profile
	var kind: String = str(entity.get("type", ""))
	if kind == "chest":
		var variant_profile: LootProfile = get_profile(DungeonMap.chest_profile_id(entity))
		if variant_profile != null:
			return variant_profile
	if kind == "monster":
		var highest_rank: int = MonsterDefinition.Rank.COMMON
		var selected_profile: LootProfile = null
		for monster_id in DungeonMap.monster_party_ids(entity):
			var monster: MonsterDefinition = MonsterCatalog.get_monster(monster_id)
			if monster == null or monster.rank < highest_rank:
				continue
			if monster.rank > highest_rank:
				highest_rank = monster.rank
				selected_profile = null
			if selected_profile == null and not monster.loot_profile_id.is_empty():
				selected_profile = get_profile(monster.loot_profile_id)
		if selected_profile != null:
			return selected_profile
		if highest_rank == MonsterDefinition.Rank.BOSS:
			kind = "boss"
		elif highest_rank == MonsterDefinition.Rank.ELITE:
			kind = "elite"
	return get_profile(kind)

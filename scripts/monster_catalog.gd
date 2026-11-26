class_name MonsterCatalog
extends RefCounted

## Ресурсы монстров определяют характеристики и иконки, сущности карты хранят ID.
const MAX_ENCOUNTER_PARTICIPANTS: int = 4
const DEFAULT_MONSTER_ID := "rabbit_symbiont"
const DEFINITIONS := {
	"rabbit_symbiont": preload("res://monsters/rabbit_symbiont.tres"),
	"hunter": preload("res://monsters/hunter.tres"),
	"giant_crab": preload("res://monsters/giant_crab.tres"),
	"lobar": preload("res://monsters/lobar.tres"),
	"kadavr": preload("res://monsters/kadavr.tres"),
	"skeleton": preload("res://monsters/skeleton.tres"),
	"fallen_hero": preload("res://monsters/fallen_hero.tres"),
	"rabbit_cadaver": preload("res://monsters/rabbit_cadaver.tres")
}

## Старые карты с прежними видами монстров продолжают загружаться.
const LEGACY_IDS := {
	"small_monster": "rabbit_symbiont",
	"skeleton_guard": "skeleton"
}


static func list_ids() -> Array[String]:
	var ids: Array[String] = []
	for monster_id in DEFINITIONS:
		ids.append(str(monster_id))
	ids.sort()
	return ids


static func list_placeable_ids() -> Array[String]:
	var ids: Array[String] = []
	for monster_id in list_ids():
		if not is_bond_companion(monster_id):
			ids.append(monster_id)
	return ids


static func has(monster_id: String) -> bool:
	return DEFINITIONS.has(monster_id)


static func resolve_id(monster_id: String) -> String:
	var resolved: String = str(LEGACY_IDS.get(monster_id, monster_id))
	return resolved if DEFINITIONS.has(resolved) else DEFAULT_MONSTER_ID


static func get_monster(monster_id: String) -> MonsterDefinition:
	return DEFINITIONS[resolve_id(monster_id)] as MonsterDefinition


static func from_entity(entity: Dictionary) -> MonsterDefinition:
	var properties: Dictionary = entity.get("properties", {})
	return get_monster(str(properties.get("monster_id", DEFAULT_MONSTER_ID)))


static func valid_encounter(monsters: Array[MonsterDefinition]) -> bool:
	if monsters.is_empty() or monsters.size() > MAX_ENCOUNTER_PARTICIPANTS:
		return false
	for monster in monsters:
		if monster == null or is_bond_companion(monster.monster_id):
			return false
		if is_exclusive_encounter(monster):
			if monsters.size() != 1:
				return false
			if monster.battle_bond != null:
				var companion_id: String = monster.battle_bond.companion_monster_id
				if companion_id == monster.monster_id or not has(companion_id):
					return false
	return true


static func is_bond_companion(monster_id: String) -> bool:
	return bond_owner(monster_id) != null


static func bond_owner(monster_id: String) -> MonsterDefinition:
	for definition in DEFINITIONS.values():
		var monster: MonsterDefinition = definition as MonsterDefinition
		if monster != null and monster.battle_bond != null and monster.battle_bond.companion_monster_id == monster_id:
			return monster
	return null


static func is_exclusive_encounter(monster: MonsterDefinition) -> bool:
	return monster != null and (monster.rank == MonsterDefinition.Rank.BOSS or monster.battle_bond != null)


static func normalize_legacy_encounter(monsters: Array[MonsterDefinition]) -> Array[MonsterDefinition]:
	var normal: Array[MonsterDefinition] = []
	for definition in monsters:
		if definition == null:
			continue
		var owner: MonsterDefinition = bond_owner(definition.monster_id)
		var monster: MonsterDefinition = owner if owner != null else definition
		if is_exclusive_encounter(monster):
			return [monster]
		if normal.size() < MAX_ENCOUNTER_PARTICIPANTS:
			normal.append(monster)
	if normal.is_empty():
		normal.append(get_monster(DEFAULT_MONSTER_ID))
	return normal

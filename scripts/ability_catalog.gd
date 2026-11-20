class_name AbilityCatalog
extends RefCounted

const ABILITY_DIRECTORY: String = "res://abilities"


## Общий приём выдаётся только при выполнении условия экипировки.
## Список расширяется новыми правилами без особых веток для героев.
const COMMON_EQUIPMENT_ABILITIES: Dictionary = {
	"guard": ItemDefinition.EquipmentSlot.SHIELD
}


static func known_ability_ids(participant: BattleParticipant) -> Array[String]:
	var ids: Array[String] = []
	if participant == null:
		return ids
	for id in participant.personal_ability_ids + participant.learned_ability_ids:
		if get_ability(id) != null and not ids.has(id):
			ids.append(id)
	for id in COMMON_EQUIPMENT_ABILITIES:
		if not ids.has(id) and _has_equipment(participant, int(COMMON_EQUIPMENT_ABILITIES[id])):
			ids.append(id)
	return ids


static func knows_ability(participant: BattleParticipant, ability_id: String) -> bool:
	return ability_id in known_ability_ids(participant)


static func _has_equipment(participant: BattleParticipant, slot: int) -> bool:
	if participant == null:
		return false
	match slot:
		ItemDefinition.EquipmentSlot.SHIELD:
			if participant.equipped_shield_id.is_empty():
				return false
			if participant._hero_snapshot != null:
				return participant._hero_snapshot.current_shield_durability(participant.equipped_shield_id) > 0
			return true
	return false


static func get_ability(ability_id: String) -> AbilityDefinition:
	return ResourceCatalog.load_by_id(ABILITY_DIRECTORY, ability_id) as AbilityDefinition


static func list_ids() -> Array[String]:
	return ResourceCatalog.list_ids(ABILITY_DIRECTORY)


static func validate_definitions(definitions: Array[AbilityDefinition]) -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for ability in definitions:
		if ability == null:
			errors.append("Пустой ресурс способности")
			continue
		var problem: String = ability.validation_error()
		if not problem.is_empty():
			errors.append("%s: %s" % [ability.ability_id, problem])
		if seen.has(ability.ability_id):
			errors.append("Повтор ID способности: %s" % ability.ability_id)
		seen[ability.ability_id] = true
	return errors


static func validate_catalog() -> Array[String]:
	var definitions: Array[AbilityDefinition] = []
	var errors: Array[String] = []
	for ability_id in list_ids():
		var definition: AbilityDefinition = get_ability(ability_id)
		if definition == null:
			errors.append("Не удалось загрузить: %s" % ability_id)
			continue
		if definition.ability_id != ability_id:
			errors.append("ID файла и ресурса различаются: %s" % ability_id)
		definitions.append(definition)
	errors.append_array(validate_definitions(definitions))
	return errors


static func available_abilities(participant: BattleParticipant) -> Array[AbilityDefinition]:
	var result: Array[AbilityDefinition] = []
	if participant == null:
		return result
	for ability_id in known_ability_ids(participant):
		var ability: AbilityDefinition = get_ability(ability_id)
		if ability != null:
			result.append(ability)
	return result


static func can_prepare(participant: BattleParticipant, ability_id: String) -> bool:
	if participant == null:
		return false
	if not knows_ability(participant, ability_id):
		return false
	var ability: AbilityDefinition = get_ability(ability_id)
	return ability != null and ability.validation_error().is_empty() and ability.unavailable_reason(participant).is_empty()


static func unavailable_reason(participant: BattleParticipant, ability_id: String) -> String:
	if participant == null or not knows_ability(participant, ability_id):
		return "Приём не изучен"
	var ability: AbilityDefinition = get_ability(ability_id)
	if ability == null:
		return "Неизвестный приём"
	var problem: String = ability.validation_error()
	return problem if not problem.is_empty() else ability.unavailable_reason(participant)

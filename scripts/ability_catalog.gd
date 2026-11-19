class_name AbilityCatalog
extends RefCounted

## Строгий реестр: неизвестный ID не заменяется случайным приёмом.
## Умения добавляются отдельными .tres, без кода под каждое действие.
const DEFINITIONS := {
	"basic_strike": preload("res://abilities/basic_strike.tres"),
	"guard": preload("res://abilities/guard.tres"),
	"rooster_crush": preload("res://abilities/rooster_crush.tres"),
	"volcha_wolf_lunge": preload("res://abilities/volcha_wolf_lunge.tres"),
	"volcha_strike_and_rebound": preload("res://abilities/volcha_strike_and_rebound.tres"),
	"volcha_wolf_instinct": preload("res://abilities/volcha_wolf_instinct.tres"),
	"volcha_broken_rhythm": preload("res://abilities/volcha_broken_rhythm.tres"),
	"volcha_cut_tendons": preload("res://abilities/volcha_cut_tendons.tres"),
	"hunter_shot": preload("res://abilities/hunter_shot.tres"),
	"rooster_windup": preload("res://abilities/rooster_windup.tres"),
	"hunter_aim": preload("res://abilities/hunter_aim.tres"),
	"lobar_charge": preload("res://abilities/lobar_charge.tres"),
	"lobar_brace": preload("res://abilities/lobar_brace.tres"),
	"crab_pincer": preload("res://abilities/crab_pincer.tres"),
	"kadavr_regen": preload("res://abilities/kadavr_regen.tres"),
	"kadavr_curse": preload("res://abilities/kadavr_curse.tres"),
	"rabbit_bite": preload("res://abilities/rabbit_bite.tres"),
	"rabbit_hide": preload("res://abilities/rabbit_hide.tres"),
	"rest": preload("res://abilities/rest.tres"),
	"wait": preload("res://abilities/wait.tres")
}


static func get_ability(ability_id: String) -> AbilityDefinition:
	return DEFINITIONS.get(ability_id) as AbilityDefinition


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
	for ability_id in DEFINITIONS:
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
	var seen: Dictionary = {}
	for ability_id in participant.personal_ability_ids + participant.learned_ability_ids:
		if seen.has(ability_id):
			continue
		seen[ability_id] = true
		var ability: AbilityDefinition = get_ability(ability_id)
		if ability != null:
			result.append(ability)
	return result


static func can_prepare(participant: BattleParticipant, ability_id: String) -> bool:
	if participant == null:
		return false
	if not (ability_id in participant.personal_ability_ids or ability_id in participant.learned_ability_ids):
		return false
	var ability: AbilityDefinition = get_ability(ability_id)
	return ability != null and ability.validation_error().is_empty() and ability.unavailable_reason(participant).is_empty()


static func unavailable_reason(participant: BattleParticipant, ability_id: String) -> String:
	if participant == null or not (ability_id in participant.personal_ability_ids or ability_id in participant.learned_ability_ids):
		return "Приём не изучен"
	var ability: AbilityDefinition = get_ability(ability_id)
	if ability == null:
		return "Неизвестный приём"
	var problem: String = ability.validation_error()
	return problem if not problem.is_empty() else ability.unavailable_reason(participant)

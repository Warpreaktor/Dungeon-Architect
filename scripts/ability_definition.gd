class_name AbilityDefinition
extends Resource

## Неизменяемый справочник способностей. HP, доступность и цепочки живут в BattleState.
enum Category { ATTACK, DEFENSE, SUPPORT, SPECIAL }
enum Target { SELF, ENEMY }

@export var ability_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category: Category = Category.ATTACK
@export var target: Target = Target.ENEMY
@export var requirements: Array[AbilityRequirementDefinition] = []
@export var effects: Array[AbilityEffectDefinition] = []


func validation_error() -> String:
	if ability_id.strip_edges().is_empty() or ability_id != ability_id.strip_edges():
		return "Некорректный ID способности"
	if display_name.strip_edges().is_empty():
		return "Отсутствует название способности"
	if effects.is_empty():
		return "Способность не содержит эффектов"
	for requirement in requirements:
		if requirement == null:
			return "Пустое требование"
		var requirement_error: String = requirement.validation_error()
		if not requirement_error.is_empty():
			return requirement_error
	for effect in effects:
		if effect == null:
			return "Пустой эффект"
		var effect_error: String = effect.validation_error()
		if not effect_error.is_empty():
			return effect_error
	return ""


func requirements_met(participant: BattleParticipant) -> bool:
	if participant == null or not participant.is_alive():
		return false
	for requirement in requirements:
		if requirement == null or not requirement.is_met(participant):
			return false
	return true

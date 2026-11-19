class_name AbilityDefinition
extends Resource

## Неизменяемый справочник способностей. HP, доступность и цепочки живут в BattleState.
enum Category { ATTACK, DEFENSE, SUPPORT, SPECIAL }
enum Target { SELF, ENEMY }
enum DamageDelivery { MELEE, RANGED, MAGIC }

@export var ability_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category: Category = Category.ATTACK
@export var target: Target = Target.ENEMY
## Сила применяется только к ближним атакующим эффектам.
@export var damage_delivery: DamageDelivery = DamageDelivery.MELEE
@export var requirements: Array[AbilityRequirementDefinition] = []
@export var effects: Array[AbilityEffectDefinition] = []
## Необязательные затраты для будущих способностей: {"mana": 4, "rage": 2}.
## Не расходуются при составлении алгоритма; только при выполнении.
@export var resource_costs: Dictionary = {}


func validation_error() -> String:
	if ability_id.strip_edges().is_empty() or ability_id != ability_id.strip_edges():
		return "Некорректный ID способности"
	if display_name.strip_edges().is_empty():
		return "Отсутствует название способности"
	if effects.is_empty():
		return "Способность не содержит эффектов"
	if damage_delivery < DamageDelivery.MELEE or damage_delivery > DamageDelivery.MAGIC:
		return "Некорректный вид урона"
	for resource_id in resource_costs:
		var cost: Variant = resource_costs[resource_id]
		if typeof(resource_id) != TYPE_STRING or str(resource_id).strip_edges().is_empty():
			return "Некорректный ID ресурса"
		if typeof(cost) != TYPE_INT or int(cost) <= 0:
			return "Стоимость ресурса должна быть положительным целым числом"
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


## Проверка выполняется перед каждой попыткой применения, до списания.
func resource_failure(participant: BattleParticipant) -> String:
	if participant == null:
		return "Нет участника боя"
	for resource_id in resource_costs:
		var needed: int = int(resource_costs[resource_id])
		if int(participant.resource_amounts.get(resource_id, 0)) < needed:
			return "Недостаточно ресурса «%s» (нужно %d)" % [resource_id, needed]
	return ""


func unavailable_reason(participant: BattleParticipant) -> String:
	if participant == null or not participant.is_alive():
		return "Участник боя недоступен"
	for requirement in requirements:
		if requirement == null:
			return "Некорректное требование"
		if not requirement.is_met(participant):
			return requirement.failure_reason()
	return resource_failure(participant)

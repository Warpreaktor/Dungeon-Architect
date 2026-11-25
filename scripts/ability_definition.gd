class_name AbilityDefinition
extends Resource

## Неизменяемый справочник способностей. HP, доступность и цепочки живут в BattleState.
enum Category { ATTACK, DEFENSE, SUPPORT, SPECIAL }
enum Target { SELF, ENEMY, ALLY, FRIENDLY }
enum DamageDelivery { MELEE, RANGED, MAGIC }

const UNLIMITED_RANGE: int = -1

@export var ability_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var description_data: Resource
@export var icon: Texture2D
@export var category: Category = Category.ATTACK
@export var target: Target = Target.ENEMY
@export_range(0, 999, 1) var minimum_range: int = 0
@export_range(-1, 999, 1) var maximum_range: int = UNLIMITED_RANGE
## Сила применяется только к ближним атакующим эффектам.
@export var damage_delivery: DamageDelivery = DamageDelivery.MELEE
@export var requirements: Array[AbilityRequirementDefinition] = []
@export var effects: Array[AbilityEffectDefinition] = []
## Необязательные затраты для будущих способностей: {"mana": 4, "rage": 2}.
## Не расходуются при составлении алгоритма; только при выполнении.
@export var resource_costs: Dictionary = {}
@export var affects_all_enemies: bool = false
@export_range(0, 20, 1) var cooldown_turns: int = 0
@export_range(-1, 100, 1) var energy_at_most_percent: int = -1


func validation_error() -> String:
	if ability_id.strip_edges().is_empty() or ability_id != ability_id.strip_edges():
		return "Некорректный ID способности"
	if display_name.strip_edges().is_empty():
		return "Отсутствует название способности"
	if effects.is_empty():
		return "Способность не содержит эффектов"
	if damage_delivery < DamageDelivery.MELEE or damage_delivery > DamageDelivery.MAGIC:
		return "Некорректный вид урона"
	if target < Target.SELF or target > Target.FRIENDLY:
		return "Некорректное правило цели"
	if minimum_range < 0 or (maximum_range != UNLIMITED_RANGE and maximum_range < minimum_range):
		return "Некорректная дальность"
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
	if int(participant.energy_cooldowns.get(ability_id, 0)) > 0:
		return "Способность восстанавливается"
	if energy_at_most_percent >= 0 and float(participant.current_energy()) > float(participant.max_energy) * float(energy_at_most_percent) / 100.0:
		return "Требуется низкий запас Энергии"
	for effect in effects:
		if effect.kind == AbilityEffectDefinition.Kind.MEDITATE and participant.current_energy() >= participant.max_energy:
			return "Энергия уже полная"
	for requirement in requirements:
		if requirement == null:
			return "Некорректное требование"
		if not requirement.is_met(participant):
			return requirement.failure_reason()
	return resource_failure(participant)


func get_description() -> String:
	var values: Dictionary = DescriptionTemplate.numeric_values(self)
	for resource_id in resource_costs:
		values["cost_" + str(resource_id)] = int(resource_costs[resource_id])
	values.merge(DescriptionTemplate.numeric_values(description_data, "data_"))
	for index in effects.size():
		var effect: AbilityEffectDefinition = effects[index]
		if effect == null:
			continue
		var prefix: String = "effect_%d_" % index
		values.merge(DescriptionTemplate.numeric_values(effect, prefix))
		values[prefix + "status_modifier"] = effect.effective_status_modifier()
		values[prefix + "duration_phases"] = DescriptionTemplate.phases(effect.duration_ticks)
		values[prefix + "status_duration"] = effect.status_duration_description()
		values[prefix + "stack_description"] = effect.stack_description()
		values[prefix + "armor_pierce_percent"] = effect.armor_pierce_fraction * BattleMath.PERCENT_SCALE
		values[prefix + "damage_multiplier"] = effect.effective_damage_multiplier()
		values[prefix + "hit_count_text"] = DescriptionTemplate.quantity(effect.hit_count, "удар", "удара", "ударов")
	return DescriptionTemplate.render(description, values)

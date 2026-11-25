class_name BattleContext
extends RefCounted

var participants: Dictionary = {}
var rng: RandomNumberGenerator
var current_tick: int = 0
var positions: Dictionary = {}
var redirects: Dictionary = {}
var counter_multiplier: float = 0.0
var counter_ability_id: String = ""
var focused_attacker_id: String = ""
var focused_target_id: String = ""
var focused_accuracy_bonus: int = 0


func _init(
		fighters: Dictionary = {},
		generator: RandomNumberGenerator = null,
		tick: int = 0,
		spatial_positions: Dictionary = {},
		active_redirects: Dictionary = {},
		active_counter_multiplier: float = 0.0,
		counter_id: String = "",
		marked_attacker_id: String = "",
		marked_target_id: String = "",
		marked_accuracy_bonus: int = 0
) -> void:
	participants = fighters
	rng = generator
	current_tick = tick
	positions = spatial_positions
	redirects = active_redirects
	counter_multiplier = active_counter_multiplier
	counter_ability_id = counter_id
	focused_attacker_id = marked_attacker_id
	focused_target_id = marked_target_id
	focused_accuracy_bonus = marked_accuracy_bonus


func get_participant(participant_id: String) -> BattleParticipant:
	return participants.get(participant_id) as BattleParticipant


func target_error(source_id: String, target_id: String, ability: AbilityDefinition) -> String:
	var source: BattleParticipant = get_participant(source_id)
	if source == null or not source.is_alive():
		return "Участник недоступен"
	if ability == null:
		return "Неизвестный приём"
	var target: BattleParticipant = get_participant(target_id)
	if target == null or not target.is_alive() or (target_id != source_id and not target.is_targetable):
		return "Цель недоступна"
	match ability.target:
		AbilityDefinition.Target.SELF:
			if source_id != target_id:
				return "Требуется цель: сам участник"
		AbilityDefinition.Target.ENEMY:
			if source_id == target_id or source.team_id == target.team_id:
				return "Недопустимая цель"
		AbilityDefinition.Target.ALLY:
			if source_id == target_id or source.team_id != target.team_id:
				return "Недопустимая цель"
		AbilityDefinition.Target.FRIENDLY:
			if source.team_id != target.team_id:
				return "Недопустимая цель"
		_:
			return "Неизвестное правило выбора цели"
	for effect in ability.effects:
		if effect.kind == AbilityEffectDefinition.Kind.DRAIN_ENERGY and target.current_energy() <= effect.energy_floor:
			return "У цели нет доступной Энергии"
		if effect.kind == AbilityEffectDefinition.Kind.TRANSFER_ENERGY and target.current_energy() >= target.max_energy:
			return "Энергия союзника уже полная"
		if effect.kind == AbilityEffectDefinition.Kind.DELAYED_DAMAGE and source.energy_delayed_attacks.has(target_id):
			return "На цели уже есть отложенная атака"
		if effect.kind == AbilityEffectDefinition.Kind.RESONANCE_SEAL and target.energy_resonance_charges > 0:
			return "Цель уже отмечена Печатью"
	if positions.has(source_id) and positions.has(target_id):
		var source_pos: Vector2i = positions[source_id]
		var target_pos: Vector2i = positions[target_id]
		var delta: Vector2i = target_pos - source_pos
		var steps: int = absi(delta.x) + absi(delta.y)
		if steps < ability.minimum_range or (
				ability.maximum_range != AbilityDefinition.UNLIMITED_RANGE
				and steps > ability.maximum_range
		):
			return "Цель вне дальности"
	return ""


func target_ids(source_id: String, ability: AbilityDefinition) -> Array[String]:
	var result: Array[String] = []
	for id in participants:
		var candidate_id: String = str(id)
		if target_error(source_id, candidate_id, ability).is_empty():
			result.append(candidate_id)
	result.sort()
	return result


func default_target_id(source_id: String, ability: AbilityDefinition) -> String:
	var candidates: Array[String] = target_ids(source_id, ability)
	return candidates[0] if not candidates.is_empty() else ""


func choose_target_id(source_id: String, ability: AbilityDefinition) -> String:
	var candidates: Array[String] = target_ids(source_id, ability)
	if candidates.is_empty():
		return ""
	if candidates.size() == 1 or rng == null:
		return candidates[0]
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func opponent_for(source_id: String) -> BattleParticipant:
	var source: BattleParticipant = get_participant(source_id)
	if source == null:
		return null
	for id in participants:
		var candidate: BattleParticipant = get_participant(str(id))
		if candidate != null and candidate.is_alive() and candidate.is_targetable and candidate.team_id != source.team_id:
			return candidate
	return null

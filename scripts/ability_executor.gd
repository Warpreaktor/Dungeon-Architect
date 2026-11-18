class_name AbilityExecutor
extends RefCounted

## Общий обработчик одного приёма. Не зависит от Control, кадров и Tween.
## Возвращает только факты; BattleState хранит события и исход схватки.


static func execute(state, actor_id: String, target_id: String, ability_id: String) -> Dictionary:
	var actor: BattleParticipant = state.get_participant(actor_id)
	var target: BattleParticipant = state.get_participant(target_id)
	var ability: AbilityDefinition = AbilityCatalog.get_ability(ability_id)
	if state.is_victory or state.is_defeat:
		return _failure("Бой уже завершён")
	if actor == null or not actor.is_alive():
		return _failure("Участник недоступен")
	if ability == null or not AbilityCatalog.can_prepare(actor, ability_id):
		return _failure("Способность недоступна")
	if ability.target == AbilityDefinition.Target.SELF:
		if target != actor:
			return _failure("Требуется цель: сам участник")
	elif target == null or target == actor or not target.is_alive() or target.team_id == actor.team_id:
		return _failure("Недопустимая цель")
	var event_list: Array[Dictionary] = []
	for effect in ability.effects:
		var recipient: BattleParticipant = actor if effect.recipient == AbilityEffectDefinition.Recipient.SELF else target
		if recipient == null:
			return _failure("Нет цели эффекта")
		match effect.kind:
			AbilityEffectDefinition.Kind.DAMAGE:
				var raw_damage: int = maxi(actor.attack + effect.amount - 1, 0)
				var bonus_percent: int = actor.block_attack_bonus_percent
				raw_damage = raw_damage * (100 + bonus_percent) / 100
				actor.block_attack_bonus_percent = 0
				event_list.append(apply_damage(actor, recipient, raw_damage, ability_id))
			AbilityEffectDefinition.Kind.BLOCK:
				recipient.prepare_block(effect.amount)
				event_list.append({"type": "block", "actor_id": actor_id, "target_id": recipient.participant_id,
					"ability_id": ability_id, "armor": recipient.block_armor,
					"damage_bonus_percent": recipient.block_attack_bonus_percent})
			AbilityEffectDefinition.Kind.HEAL:
				var healed: int = recipient.restore_health(effect.amount)
				event_list.append({"type": "heal", "actor_id": actor_id, "target_id": recipient.participant_id,
					"ability_id": ability_id, "healed": healed})
			AbilityEffectDefinition.Kind.APPLY_STATUS:
				recipient.statuses[effect.status_id] = {"amount": effect.amount, "ticks": effect.duration_ticks}
				event_list.append({"type": "status_applied", "actor_id": actor_id,
					"target_id": recipient.participant_id, "ability_id": ability_id, "status_id": effect.status_id,
					"duration_ticks": effect.duration_ticks})
			AbilityEffectDefinition.Kind.REMOVE_STATUS:
				var removed: bool = recipient.statuses.has(effect.status_id)
				recipient.statuses.erase(effect.status_id)
				event_list.append({"type": "status_removed", "actor_id": actor_id,
					"target_id": recipient.participant_id, "ability_id": ability_id, "status_id": effect.status_id,
					"removed": removed})
			AbilityEffectDefinition.Kind.WAIT:
				event_list.append({"type": "wait", "actor_id": actor_id, "target_id": recipient.participant_id,
					"ability_id": ability_id})
	state.events.append_array(event_list)
	state.update_outcome()
	return {"success": true, "reason": "", "events": event_list}


static func apply_damage(actor: BattleParticipant, target: BattleParticipant, amount: int, ability_id: String = "") -> Dictionary:
	var raw: int = maxi(amount, 0)
	# Статусы задают изменения чисел общими эффектами, а не отдельной логикой монстров.
	if actor.statuses.has("attack_down"):
		raw = maxi(raw - int(actor.statuses["attack_down"].get("amount", 0)), 0)
	var taken: int = target.receive_damage(raw)
	return {"type": "attack", "actor_id": actor.participant_id, "target_id": target.participant_id,
		"ability_id": ability_id, "damage": taken, "blocked": maxi(raw - taken, 0),
		"shield_blocked": target.last_shield_blocked, "shield_broken": target.last_shield_broken}


static func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason, "events": []}

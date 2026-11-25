class_name EnergyAbilityResolver
extends RefCounted


static func resolve(context: BattleContext, actor: BattleParticipant, target: BattleParticipant,
		ability: AbilityDefinition, effect: AbilityEffectDefinition, _energy_before: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	match effect.kind:
		AbilityEffectDefinition.Kind.DRAIN_ENERGY:
			if _spell_missed(context, actor, target):
				events.append({"type": "miss", "actor_id": actor.participant_id,
					"target_id": target.participant_id, "ability_id": ability.ability_id})
			else:
				var amount: int = mini(effect.amount, maxi(target.current_energy() - effect.energy_floor, 0))
				target.change_energy(-amount)
				var drained_received: int = actor.change_energy(amount)
				events.append({"type": "energy_drained", "actor_id": actor.participant_id,
					"target_id": target.participant_id, "ability_id": ability.ability_id,
					"amount": amount, "restored": drained_received})
		AbilityEffectDefinition.Kind.TRANSFER_ENERGY:
			var given: int = int(ability.resource_costs.get("energy", 0))
			var transferred_received: int = target.change_energy(given)
			events.append({"type": "energy_restored", "actor_id": actor.participant_id,
				"target_id": target.participant_id, "ability_id": ability.ability_id,
				"amount": transferred_received, "remaining": target.current_energy()})
		AbilityEffectDefinition.Kind.BARRIER:
			target.energy_barrier_hp = effect.amount
			events.append({"type": "energy_barrier", "actor_id": actor.participant_id,
				"target_id": target.participant_id, "ability_id": ability.ability_id,
				"amount": effect.amount})
		AbilityEffectDefinition.Kind.DELAYED_DAMAGE:
			actor.energy_delayed_attacks[target.participant_id] = {
				"turns": effect.duration_ticks, "damage": floori(float(effect.amount) * actor.energy_factor()),
				"ability_id": ability.ability_id
			}
			events.append({"type": "delayed_attack_prepared", "actor_id": actor.participant_id,
				"target_id": target.participant_id, "ability_id": ability.ability_id,
				"turns": effect.duration_ticks})
		AbilityEffectDefinition.Kind.MEDITATE:
			actor.energy_meditation_pending = effect.amount
			events.append({"type": "meditation_started", "actor_id": actor.participant_id,
				"target_id": actor.participant_id, "ability_id": ability.ability_id})
		AbilityEffectDefinition.Kind.RESONANCE_SEAL:
			if _spell_missed(context, actor, target):
				events.append({"type": "miss", "actor_id": actor.participant_id,
					"target_id": target.participant_id, "ability_id": ability.ability_id})
			else:
				target.energy_resonance_charges = effect.hit_count
				target.energy_resonance_turns = effect.duration_ticks
				target.energy_resonance_restore = effect.amount
				events.append({"type": "resonance_applied", "actor_id": actor.participant_id,
					"target_id": target.participant_id, "ability_id": ability.ability_id,
					"charges": effect.hit_count})
		AbilityEffectDefinition.Kind.HP_COST:
			var before: int = actor.health
			if actor._hero_snapshot != null:
				actor._hero_snapshot.health = maxi(actor._hero_snapshot.health - effect.amount, 0)
				actor.refresh_from_hero()
			else:
				actor.health = maxi(actor.health - effect.amount, 0)
			events.append({"type": "health_spent", "actor_id": actor.participant_id,
				"target_id": actor.participant_id, "ability_id": ability.ability_id,
				"damage": before - actor.health, "hp_after": actor.health, "hp_max": actor.max_health})
	return events


static func _spell_missed(context: BattleContext, actor: BattleParticipant, target: BattleParticipant) -> bool:
	var dodge: int = target.dodge_chance_against(actor)
	return context.rng != null and context.rng.randf() < float(dodge) / float(BattleMath.PERCENT_SCALE)


static func resolve_area(context: BattleContext, actor: BattleParticipant,
		ability: AbilityDefinition, energy_before: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var targets: Array[String] = context.target_ids(actor.participant_id, ability)
	var resonance_triggered: Dictionary = {}
	for target_id in targets:
		var target: BattleParticipant = context.get_participant(target_id)
		if target == null or not target.is_alive():
			continue
		var last_hit: Dictionary = {}
		for effect in ability.effects:
			match effect.kind:
				AbilityEffectDefinition.Kind.DAMAGE:
					var raw: int = AbilityExecutor.preview_damage(actor, ability, effect, target, -1, energy_before)
					last_hit = AbilityExecutor.apply_damage(actor, target, raw, ability.ability_id,
						context.rng, effect.armor_pierce_fraction, effect.accuracy_offset_percent)
					result.append(last_hit)
					if not bool(last_hit.get("dodged", false)) and not resonance_triggered.has(target_id):
						var bonus: Dictionary = on_hit(actor, target)
						if not bonus.is_empty():
							resonance_triggered[target_id] = true
							result.append(bonus)
				AbilityEffectDefinition.Kind.APPLY_STATUS:
					if not target.is_alive():
						continue
					if effect.requires_health_damage and int(last_hit.get("damage", 0)) <= 0:
						continue
					if effect.requires_hit and (last_hit.is_empty() or bool(last_hit.get("dodged", false))):
						continue
					target.apply_status(effect, context.current_tick)
					result.append({"type": "status_applied", "actor_id": actor.participant_id,
						"target_id": target_id, "ability_id": ability.ability_id,
						"status_id": effect.status_id, "duration_ticks": effect.duration_ticks})
	actor.block_armor = 0
	actor.block_attack_bonus_percent = 0
	return result


static func on_hit(actor: BattleParticipant, target: BattleParticipant) -> Dictionary:
	if target.energy_resonance_charges <= 0:
		return {}
	target.energy_resonance_charges -= 1
	var gained: int = actor.change_energy(target.energy_resonance_restore)
	return {"type": "energy_restored", "actor_id": actor.participant_id,
		"target_id": actor.participant_id, "amount": gained,
		"remaining": actor.current_energy(), "charges": target.energy_resonance_charges}


static func at_turn_start(context: BattleContext, actor: BattleParticipant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if actor.energy_barrier_hp > 0:
		actor.energy_barrier_hp = 0
		result.append({"type": "energy_barrier_expired", "actor_id": actor.participant_id,
			"target_id": actor.participant_id})
	if actor.energy_meditation_pending > 0:
		var restored: int = actor.change_energy(actor.energy_meditation_pending)
		actor.energy_meditation_pending = 0
		result.append({"type": "energy_restored", "actor_id": actor.participant_id,
			"target_id": actor.participant_id, "amount": restored,
			"remaining": actor.current_energy()})
	for target_id in actor.energy_delayed_attacks.keys():
		var attack: Dictionary = actor.energy_delayed_attacks[target_id]
		attack["turns"] = int(attack.get("turns", 0)) - 1
		if int(attack["turns"]) > 0:
			actor.energy_delayed_attacks[target_id] = attack
			continue
		actor.energy_delayed_attacks.erase(target_id)
		var target: BattleParticipant = context.get_participant(str(target_id))
		if target == null or not target.is_alive():
			continue
		result.append(AbilityExecutor.apply_damage(actor, target, int(attack.get("damage", 0)),
			str(attack.get("ability_id", "")), context.rng))
	return result


static func at_turn_end(actor: BattleParticipant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in actor.energy_cooldowns.keys():
		var remaining: int = int(actor.energy_cooldowns[key]) - 1
		if remaining <= 0:
			actor.energy_cooldowns.erase(key)
		else:
			actor.energy_cooldowns[key] = remaining
	if actor.energy_resonance_turns > 0:
		actor.energy_resonance_turns -= 1
		if actor.energy_resonance_turns == 0:
			actor.energy_resonance_charges = 0
			actor.energy_resonance_restore = 0
	if actor.current_energy() < 0:
		var lost: int = actor.energy_debt_damage()
		result.append({"type": "status_tick", "actor_id": actor.participant_id,
			"target_id": actor.participant_id, "status_id": "energy_exhaustion",
			"damage": lost, "hp_after": actor.health, "hp_max": actor.max_health})
	return result

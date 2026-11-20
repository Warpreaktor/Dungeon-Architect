extends SceneTree

const FIXTURE_HEALTH: int = 1000


static func _actor(id: String, team: String, abilities: Array[String]) -> BattleParticipant:
	var actor := BattleParticipant.new()
	actor.participant_id = id
	actor.team_id = team
	actor.max_health = FIXTURE_HEALTH
	actor.health = FIXTURE_HEALTH
	actor.personal_ability_ids = abilities
	return actor


static func _ability(id: String, target: int, kind: int) -> AbilityDefinition:
	var ability := AbilityDefinition.new()
	ability.ability_id = id
	ability.display_name = id
	ability.target = target
	var effect := AbilityEffectDefinition.new()
	effect.kind = kind
	effect.recipient = AbilityEffectDefinition.Recipient.SELF if target == AbilityDefinition.Target.SELF else AbilityEffectDefinition.Recipient.TARGET
	ability.effects.append(effect)
	return ability


func _initialize() -> void:
	var block: AbilityDefinition = _ability("fixture_block", AbilityDefinition.Target.SELF, AbilityEffectDefinition.Kind.BLOCK)
	var strike: AbilityDefinition = _ability("fixture_attack", AbilityDefinition.Target.ENEMY, AbilityEffectDefinition.Kind.DAMAGE)
	var battle := BattleState.new()
	var actor: BattleParticipant = _actor("source", "allies", [block.ability_id, strike.ability_id])
	var enemy: BattleParticipant = _actor("target", "enemies", [])
	battle.participants = {actor.participant_id: actor, enemy.participant_id: enemy}

	assert(battle.execute_definition(actor.participant_id, actor.participant_id, block).success)
	var raised_block: int = actor.block_armor
	assert(raised_block > 0)
	battle.end_phase()
	assert(actor.block_armor == raised_block)

	var result: Dictionary = battle.execute_definition(actor.participant_id, enemy.participant_id, strike)
	assert(result.success)
	assert(actor.block_armor == 0)
	assert(actor.block_attack_bonus_percent == 0)
	assert(result.events.size() >= 2)
	assert(result.events[0].type == "block_consumed")
	assert(result.events[0].target_id == actor.participant_id)
	assert(result.events[0].armor == actor.block_armor)
	assert(result.events[1].type == "attack")

	var next_attack: Dictionary = battle.execute_definition(actor.participant_id, enemy.participant_id, strike)
	assert(next_attack.success)
	for event in next_attack.events:
		assert(event.type != "block_consumed")
	quit()

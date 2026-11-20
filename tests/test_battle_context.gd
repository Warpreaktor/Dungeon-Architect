extends SceneTree


static func _fighter(id: String, team: String, hp: int) -> BattleParticipant:
	var participant := BattleParticipant.new()
	participant.participant_id = id
	participant.team_id = team
	participant.max_health = hp
	participant.health = hp
	participant.strength = 4
	participant.personal_ability_ids = ["basic_strike"]
	return participant


func _initialize() -> void:
	var battle := BattleState.new()
	battle.participants = {
		"knight": _fighter("knight", "allies", 20),
		"squire": _fighter("squire", "allies", 10),
		"goblin": _fighter("goblin", "monsters", 20),
	}
	var context: BattleContext = battle.create_context()
	var strike: AbilityDefinition = AbilityCatalog.get_ability("basic_strike")
	assert(context.get_participant("goblin") != null)
	assert(context.get_participant("missing") == null)
	assert(context.target_ids("knight", strike) == ["goblin"])
	assert(context.default_target_id("knight", strike) == "goblin")
	assert(not context.target_error("knight", "knight", strike).is_empty())
	assert(not context.target_error("knight", "squire", strike).is_empty())
	assert(not context.target_error("knight", "missing", strike).is_empty())
	var bad_hit: Dictionary = battle.execute_ability("knight", "knight", "basic_strike")
	assert(not bad_hit.success)
	assert(battle.events.is_empty())
	assert(not battle.execute_ability("knight", "missing", "basic_strike").success)

	battle.get_participant("knight").accuracy_bonus = BattleMath.PERCENT_SCALE
	var hp: int = battle.get_participant("goblin").health
	var hit: Dictionary = battle.execute_ability("knight", "goblin", "basic_strike")
	assert(hit.success)
	assert(hit.events[0].actor_id == "knight")
	assert(hit.events[0].target_id == "goblin")
	assert(battle.get_participant("goblin").health < hp)

	var ally_heal := AbilityDefinition.new()
	ally_heal.ability_id = "test_ally_heal"
	ally_heal.display_name = "Ally heal"
	ally_heal.target = AbilityDefinition.Target.ALLY
	var heal := AbilityEffectDefinition.new()
	heal.kind = AbilityEffectDefinition.Kind.HEAL
	heal.recipient = AbilityEffectDefinition.Recipient.TARGET
	heal.amount = 2
	ally_heal.effects.append(heal)
	battle.get_participant("knight").personal_ability_ids.append(ally_heal.ability_id)
	battle.get_participant("squire").health = 5
	context = battle.create_context()
	assert(context.target_ids("knight", ally_heal) == ["squire"])
	assert(battle.execute_definition("knight", "squire", ally_heal).success)
	assert(battle.get_participant("squire").health == 7)
	assert(not battle.execute_definition("knight", "knight", ally_heal).success)
	assert(not battle.execute_definition("knight", "goblin", ally_heal).success)

	strike.maximum_range = 2
	battle.positions = {"knight": Vector2i.ZERO, "goblin": Vector2i(2, 1)}
	context = battle.create_context()
	assert(context.target_error("knight", "goblin", strike) == "Цель вне дальности")
	assert(context.target_ids("knight", strike).is_empty())
	strike.maximum_range = 3
	assert(context.target_error("knight", "goblin", strike).is_empty())
	strike.minimum_range = 4
	assert(context.target_error("knight", "goblin", strike) == "Цель вне дальности")
	strike.minimum_range = 0
	battle.positions.clear()
	assert(battle.create_context().target_error("knight", "goblin", strike).is_empty())
	strike.maximum_range = AbilityDefinition.UNLIMITED_RANGE
	assert(AbilityCatalog.validate_catalog().is_empty())
	assert(AbilityCatalog.all_ability_ids().has("petushan_spur_under_rib"))

	var combat_hero := HeroState.new(HeroCatalog.get_hero("petushan"))
	assert(combat_hero.max_health == combat_hero.definition.max_health)
	var hero_actor := BattleParticipant.from_hero(combat_hero)
	assert(hero_actor.melee_attack_value() == combat_hero.melee_attack_value())
	assert(hero_actor.ranged_attack_value() == combat_hero.ranged_attack_value())
	assert(hero_actor.accuracy_percent() + BattleMath.PERCENT_SCALE ==
		BattleMath.RULES.base_accuracy_percent + hero_actor.agility)

	var baseline: int = AbilityExecutor.preview_damage(hero_actor, strike, strike.effects[0])
	hero_actor.statuses["different_status_name"] = {
		"stat": AbilityEffectDefinition.Stat.ATTACK_POWER,
		"modifier": -2,
		"stacks": 1,
	}
	assert(AbilityExecutor.preview_damage(hero_actor, strike, strike.effects[0]) == maxi(baseline - 2, 0))
	quit()

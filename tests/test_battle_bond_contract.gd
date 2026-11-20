extends SceneTree


func _initialize() -> void:
	var boss: MonsterDefinition = MonsterCatalog.get_monster("rabbit_symbiont")
	assert(boss.battle_bond != null)
	var bond: BattleBondDefinition = boss.battle_bond
	var session := CombatSession.new(boss, HeroState.new())
	var state: BattleState = session.battle_state
	var guardian: BattleParticipant = state.get_enemy()
	var commander: BattleParticipant = state.get_participant(state.support_enemy_id)
	assert(guardian.definition_id == bond.companion_monster_id)
	assert(commander.definition_id == boss.monster_id)
	assert(state.bond_mounted)
	assert(not commander.is_targetable)
	assert(guardian.is_alive() and commander.is_alive())

	var accuracy_before: int = guardian.accuracy_bonus
	assert(bool(state.execute_ability(commander.participant_id, state.hero_id, bond.command_ability_id).get("success")))
	assert(state.bond_marked_target_id == state.hero_id)
	assert(state.get_hero().statuses.has(bond.marked_status_id))
	assert(guardian.accuracy_bonus == accuracy_before)
	assert(bool(state.execute_ability(commander.participant_id, state.hero_id, bond.command_ability_id).get("success")))
	assert(state.bond_marked_target_id == state.hero_id)
	assert(state.get_hero().statuses.has(bond.marked_status_id))
	assert(guardian.accuracy_bonus == accuracy_before)

	var initial_health: int = commander.health
	var initial_cursor: int = commander.action_cursor
	assert(bool(state.execute_ability(commander.participant_id, commander.participant_id, bond.split_ability_id).get("success")))
	assert(not state.bond_mounted)
	assert(commander.is_targetable)
	assert(commander.action_chain.has(bond.ranged_ability_id))
	assert(commander.action_chain.has(bond.rejoin_ability_id))
	assert(not commander.action_chain.has(bond.heal_ability_id))
	assert(commander.health == initial_health and commander.action_cursor == initial_cursor)
	assert(bool(state.execute_ability(commander.participant_id, commander.participant_id, bond.rejoin_ability_id).get("success")))
	assert(state.bond_mounted)
	assert(not commander.is_targetable)
	assert(commander.action_chain.has(bond.heal_ability_id))
	assert(commander.action_chain.has(bond.split_ability_id))
	assert(commander.health == initial_health and commander.action_cursor == initial_cursor)

	guardian.receive_damage(guardian.max_health / 4)
	var injured: int = guardian.health
	assert(bool(state.execute_ability(commander.participant_id, guardian.participant_id, bond.heal_ability_id).get("success")))
	assert(guardian.health > injured)
	assert(guardian.health <= guardian.max_health)

	assert(bool(state.execute_ability(guardian.participant_id, guardian.participant_id, bond.protect_ability_id).get("success")))
	assert(state.intercept_targets.has(commander.participant_id))
	assert(bool(state.execute_ability(commander.participant_id, commander.participant_id, bond.split_ability_id).get("success")))
	var hero: BattleParticipant = state.get_hero()
	hero.personal_ability_ids.append("basic_strike")
	var attack: Dictionary = state.execute_ability(hero.participant_id, commander.participant_id, "basic_strike")
	assert(bool(attack.get("success")))
	var attack_events: Array = attack.get("events", [])
	assert(attack_events.any(func(e: Dictionary) -> bool: return str(e.get("type", "")) == "attack_intercepted"))
	assert(not state.intercept_targets.has(commander.participant_id))

	guardian.health = 0
	state.update_outcome()
	assert(commander.is_alive())
	assert(commander.is_targetable)
	assert(not state.is_victory)
	assert(not state.bond_mounted)
	assert(state.bond_marked_target_id == state.hero_id)
	assert(not bool(state.execute_ability(commander.participant_id, commander.participant_id, bond.rejoin_ability_id).get("success")))
	commander.health = 0
	state.update_outcome()
	assert(state.is_victory)
	assert(state.bond_marked_target_id.is_empty())
	assert(not state.get_hero().statuses.has(bond.marked_status_id))
	quit()

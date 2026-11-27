extends SceneTree


func _heroes() -> Array[HeroState]:
	var heroes: Array[HeroState] = []
	for id in ["volcha", "petushan", "burolom", "luma"]:
		heroes.append(HeroState.new(HeroCatalog.get_hero(id)))
	return heroes


func _initialize() -> void:
	_test_individual_tactics()
	var skeleton: MonsterDefinition = MonsterCatalog.get_monster("skeleton")
	var hunter: MonsterDefinition = MonsterCatalog.get_monster("hunter")
	var boss: MonsterDefinition = MonsterCatalog.get_monster("rabbit_symbiont")
	var kadavr: MonsterDefinition = MonsterCatalog.get_monster("kadavr")
	var definitions: Array[MonsterDefinition] = [skeleton, hunter, skeleton, skeleton]
	var heroes: Array[HeroState] = _heroes()
	var combat: CombatSession = CombatSession.for_encounter(definitions, heroes[0], 1831, heroes)
	var replay: CombatSession = CombatSession.for_encounter(definitions, heroes[0], 1831, heroes)
	assert(combat != null and replay != null)
	var battle: BattleState = combat.battle_state
	var ids: Array[String] = battle.enemy_ids()
	assert(ids == ["enemy", "enemy_support", "enemy_3", "enemy_4"])
	assert(battle.hero_ids().size() == 4 and battle.visible_enemy_ids() == ids)
	for index in range(ids.size()):
		var id: String = ids[index]
		var actor: BattleParticipant = battle.get_participant(id)
		assert(battle.enemy_definition_for(id) == definitions[index])
		assert(actor.definition_id == definitions[index].monster_id)
		assert(actor.health == definitions[index].max_health)
		assert(not actor.action_chain.is_empty())
		assert(actor.action_chain == replay.battle_state.get_participant(id).action_chain)
		assert(actor.equipped_weapon_id == replay.battle_state.get_participant(id).equipped_weapon_id)
	assert(battle.rng.state == replay.battle_state.rng.state)
	assert(battle.add_enemy(skeleton) == null)
	var third: BattleParticipant = battle.get_participant(ids[2])
	var fourth: BattleParticipant = battle.get_participant(ids[3])
	var fourth_chain: Array[String] = fourth.action_chain.duplicate()
	third.action_chain.clear()
	third.health -= 1
	assert(fourth.action_chain == fourth_chain and fourth.health == skeleton.max_health)
	assert(battle._runtime_for(ids[2]).initial_chain == replay.battle_state.get_participant(ids[2]).action_chain)
	battle._runtime_for(ids[2]).intermission_usage["wait"] = 1
	assert(battle._runtime_for(ids[3]).intermission_usage.is_empty())
	third.action_chain = battle._runtime_for(ids[2]).initial_chain.duplicate()
	var attack: AbilityDefinition = AbilityCatalog.get_ability("basic_strike")
	for index in range(ids.size()):
		var id: String = ids[index]
		assert(battle.create_context().target_ids(id, attack).size() == 4)
		assert(battle.create_context().target_ids(battle.hero_id, attack).has(id))
		battle.get_participant(id).health = 0
		battle.update_outcome()
		assert(battle.is_victory == (index == ids.size() - 1))
		assert(not battle.create_context().target_ids(battle.hero_id, attack).has(id))
	assert(MonsterCatalog.valid_encounter([skeleton, skeleton, skeleton, skeleton]))
	assert(not MonsterCatalog.valid_encounter([skeleton, skeleton, skeleton, skeleton, skeleton]))
	assert(CombatSession.for_encounter([boss, skeleton]) == null)
	assert(CombatSession.for_encounter([skeleton, boss]) == null)
	assert(CombatSession.for_encounter([kadavr, skeleton]) == null)
	assert(CombatSession.for_encounter([MonsterCatalog.get_monster(boss.battle_bond.companion_monster_id)]) == null)
	var bonded: BattleState = CombatSession.for_encounter([boss], heroes[0], 1831, heroes).battle_state
	assert(bonded.enemy_ids().size() == 2 and bonded.visible_enemy_ids().size() == 1)
	assert(bonded.add_enemy(skeleton) == null)
	var bond: BattleBondDefinition = boss.battle_bond
	var marked_id: String = bonded.hero_ids()[3]
	assert(bonded.execute_ability(bonded.bond_commander_id, marked_id, bond.command_ability_id).get("success", false))
	assert(bonded.create_context().choose_target_id(bonded.bond_guardian_id, attack) == marked_id)
	bonded.get_participant(marked_id).health = 0
	bonded.update_outcome()
	assert(bonded.bond_marked_target_id.is_empty())
	assert(bonded.create_context().choose_target_id(bonded.bond_guardian_id, attack) in bonded.living_hero_ids())
	var dungeon := DungeonMap.create_blank(5, 5)
	assert(dungeon.place_entity("monster", 2, 2, {"monster_id": boss.monster_id}))
	var entity: Dictionary = dungeon.entities_at(2, 2)[0]
	var entity_id: String = str(entity["id"])
	assert(not dungeon.set_monster_party(entity_id, [boss.monster_id, skeleton.monster_id]))
	assert(not dungeon.set_monster_party(entity_id, [skeleton.monster_id, boss.monster_id]))
	assert(DungeonMap.monster_party_ids(entity) == [boss.monster_id])
	entity["properties"]["monster_id"] = skeleton.monster_id
	entity["properties"]["monster_ids"] = [boss.monster_id]
	var restored: DungeonMap = DungeonMap.from_dict(JSON.parse_string(JSON.stringify(dungeon.to_dict())))
	var restored_entity: Dictionary = restored.entities_at(2, 2)[0]
	assert(DungeonMap.monster_party_ids(restored_entity) == [boss.monster_id])
	assert(restored_entity["properties"]["monster_id"] == boss.monster_id)
	assert(not restored_entity["properties"].has("monster_ids"))
	print("Four enemy core: independent actors, deterministic draws, targets, victory and exclusive bosses OK")
	quit()


func _test_individual_tactics() -> void:
	var monster := MonsterDefinition.new()
	monster.monster_id = "tactics_fixture"
	monster.max_health = 100
	monster.max_energy = 100
	monster.agility = 3
	monster.personal_ability_ids = ["basic_strike", "guard"]
	monster.guaranteed_card_ids = ["basic_strike"]
	monster.random_card_count = 0
	var wounded := MonsterTacticProfile.new()
	wounded.profile_id = "wounded"
	wounded.maximum_health_percent = 50
	wounded.card_ids = ["guard"]
	monster.ai_profiles = [wounded]
	var recovery := MonsterIntermissionAction.new()
	recovery.ability_id = "wait"
	recovery.maximum_health_percent = 50
	monster.intermission_actions = [recovery]
	var heroes: Array[HeroState] = _heroes()
	var state: BattleState = BattleState.begin_for_encounter([monster, monster, monster, monster], heroes, 841)
	var ids: Array[String] = state.enemy_ids()
	state.get_participant(ids[2]).health = 40
	state.get_participant(ids[3]).health = 40
	state._reconfigure_enemy_for_phase()
	for index in range(ids.size()):
		var actor: BattleParticipant = state.get_participant(ids[index])
		assert(state._runtime_for(ids[index]).profile_id == ("wounded" if index >= 2 else ""))
		assert(actor.action_chain == (["guard"] if index >= 2 else ["basic_strike"]))
	state.get_participant(ids[2]).health = 100
	state._reconfigure_enemy_for_phase()
	assert(state.get_participant(ids[2]).action_chain == ["basic_strike"])
	assert(state.get_participant(ids[3]).action_chain == ["guard"])
	state.flow.stage = BattleFlow.Stage.BETWEEN_PHASES
	state.get_participant(ids[2]).health = 40
	state._run_enemy_intermission_for(ids[2])
	assert(state._runtime_for(ids[2]).intermission_usage.get(recovery.identity(), 0) == 1)
	assert(state._runtime_for(ids[3]).intermission_usage.is_empty())
	state._run_enemy_intermission_for(ids[3])
	assert(state._runtime_for(ids[3]).intermission_usage.get(recovery.identity(), 0) == 1)
	state._run_enemy_intermission_for(ids[2])
	assert(state._runtime_for(ids[2]).intermission_usage.get(recovery.identity(), 0) == 1)

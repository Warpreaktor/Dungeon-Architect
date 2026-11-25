extends SceneTree


func _initialize() -> void:
	var definition: MonsterDefinition = MonsterCatalog.get_monster("kadavr")
	assert(definition.rank == MonsterDefinition.Rank.BOSS)
	assert(definition.icon != null and definition.portrait != null)
	assert(MonsterCatalog.list_placeable_ids().has(definition.monster_id))
	assert(MonsterCatalog.get_monster("rabbit_cadaver").fury_rules == null)
	assert(definition.ai_profiles.is_empty())
	var dungeon := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("monster", 3, 2, {"monster_id": definition.monster_id}))
	var entity: Dictionary = dungeon.entities_at(3, 2)[0]
	assert(MonsterCatalog.from_entity(entity) == definition)
	assert(LootProfileCatalog.for_source(entity) == LootProfileCatalog.get_profile("boss"))
	var restored: DungeonMap = DungeonMap.from_dict(dungeon.to_dict())
	assert(MonsterCatalog.from_entity(restored.entities_at(3, 2)[0]) == definition)
	var party: Array[HeroState] = []
	for id in ["volcha", "petushan", "burolom", "luma"]:
		party.append(HeroState.new(HeroCatalog.get_hero(id)))
		var encounter: BattleState = BattleState.begin_for_party(definition, party, 53)
		assert(encounter.get_enemy().max_health == definition.max_health)
		assert(encounter.get_enemy().health == definition.max_health)
		var support: BattleParticipant = encounter.add_support_enemy(definition)
		assert(support.max_health == definition.max_health and support.health == definition.max_health)
	party[2].health = 0
	party[3].health = 0
	var survivors: BattleState = BattleState.begin_for_party(definition, party, 53)
	assert(survivors.living_hero_ids().size() == 2)
	assert(survivors.get_enemy().max_health == definition.max_health)
	assert(survivors.get_enemy().health == definition.max_health)
	party[2] = HeroState.new(HeroCatalog.get_hero("burolom"))
	party[3] = HeroState.new(HeroCatalog.get_hero("luma"))
	var state: BattleState = BattleState.begin_for_party(definition, party, 53)
	var boss: BattleParticipant = state.get_enemy()
	var rules: MonsterFuryRules = definition.fury_rules
	var context := BattleContext.new(state.participants)
	assert(boss.action_chain == definition.guaranteed_card_ids)
	for ability_id in definition.personal_ability_ids:
		var ability: AbilityDefinition = AbilityCatalog.get_ability(ability_id)
		assert(ability != null and ability.icon != null and ability.validation_error().is_empty())
		assert(DescriptionTemplate.unresolved_tokens(ability.get_description()).is_empty())
	assert(not AbilityCatalog.can_prepare(boss, "kadavr_unleashed"))
	assert(not AbilityExecutor.execute(context, "enemy", "hero", "kadavr_unleashed").success)
	var search: AbilityDefinition = AbilityCatalog.get_ability("kadavr_search")
	assert(AbilityExecutor.execute(context, "enemy", "enemy", search.ability_id).success)
	assert(boss.block_armor == search.effects[0].amount)
	assert(boss.fury_guard_armed)
	var hero: BattleParticipant = state.get_hero()
	var hit := AbilityDefinition.new()
	hit.ability_id = "test_boss_hit"
	hit.display_name = "Удар"
	var damage := AbilityEffectDefinition.new()
	damage.amount = 20
	damage.hit_count = 2
	hit.effects = [damage]
	hero.personal_ability_ids.append(hit.ability_id)
	assert(AbilityExecutor.execute_definition(context, "hero", "enemy", hit).success)
	assert(boss.fury() == mini(rules.round_gain_cap, rules.gain_on_health_damage + rules.gain_on_guard_hit))
	assert(not boss.fury_guard_armed)
	assert(AbilityExecutor.execute_definition(context, "hero", "enemy", hit).success)
	assert(boss.fury() == rules.round_gain_cap)
	assert(state.start_round_combat().success)
	state.prepare_next_round()
	assert(boss.fury_gained_this_round == 0)
	boss.gain_fury(rules.maximum)
	assert(boss.is_fury_unleashed())
	var last_order: AbilityDefinition = AbilityCatalog.get_ability("kadavr_last_order")
	assert(boss.preview_block_armor(last_order.effects[0].amount) == last_order.effects[0].amount - rules.block_penalty)
	var swing: AbilityDefinition = AbilityCatalog.get_ability("kadavr_despair_swing")
	var swing_result: Dictionary = AbilityExecutor.execute(context, "enemy", "hero", swing.ability_id)
	assert(swing_result.success)
	var targets: Dictionary = {}
	for event in swing_result.events:
		if event.type == "attack":
			targets[event.target_id] = true
	assert(targets.size() == swing.effects[0].distinct_targets)
	var ultimate: AbilityDefinition = AbilityCatalog.get_ability("kadavr_unleashed")
	var result: Dictionary = AbilityExecutor.execute(context, "enemy", "hero", ultimate.ability_id)
	assert(result.success)
	targets.clear()
	var hits: int = 0
	for event in result.events:
		if event.type == "attack":
			hits += 1
			targets[event.target_id] = true
	assert(hits == ultimate.effects[0].hit_count)
	assert(targets.size() == ultimate.effects[0].distinct_targets)
	assert(boss.fury() == 0 and not boss.is_fury_unleashed())
	var solo: BattleState = BattleState.begin(definition, party[0], 54)
	var solo_boss: BattleParticipant = solo.get_enemy()
	var solo_context := BattleContext.new(solo.participants)
	solo_boss.resource_amounts["fury"] = rules.maximum
	solo_boss.health -= 20
	var spasm: AbilityDefinition = AbilityCatalog.get_ability("kadavr_regen")
	var spasm_result: Dictionary = AbilityExecutor.execute(solo_context, "enemy", "hero", spasm.ability_id)
	assert(spasm_result.success)
	var dealt: int = 0
	var healed: int = 0
	for event in spasm_result.events:
		if event.type == "attack":
			dealt += int(event.hp_damage)
		elif event.type == "heal":
			healed += int(event.healed)
	assert(healed == mini(floori(dealt * spasm.damage_heal_ratio), spasm.damage_heal_cap))
	assert(solo_boss.fury() == rules.maximum - spasm.fury_spend_after_cast)
	assert(not solo_boss.is_fury_unleashed())
	var grip: AbilityDefinition = AbilityCatalog.get_ability("kadavr_curse")
	solo_boss.resource_amounts["fury"] = rules.maximum
	var grip_result: Dictionary = AbilityExecutor.execute(solo_context, "enemy", "hero", grip.ability_id)
	assert(grip_result.success)
	assert(grip_result.events.filter(func(event: Dictionary) -> bool: return event.type == "attack").size() == grip.effects[0].fury_hit_count)
	var victim: BattleParticipant = solo.get_hero()
	assert(victim.statuses.has(grip.effects[1].status_id))
	assert(victim.status_modifier(AbilityEffectDefinition.Stat.AGILITY) == grip.effects[1].status_modifier)
	for _turn in range(grip.effects[1].duration_ticks):
		victim.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(not victim.statuses.has(grip.effects[1].status_id))
	var solo_ultimate: BattleState = BattleState.begin(definition, party[0], 55)
	var solo_rage: BattleParticipant = solo_ultimate.get_enemy()
	solo_rage.resource_amounts["fury"] = rules.maximum
	var solo_result: Dictionary = AbilityExecutor.execute(BattleContext.new(solo_ultimate.participants), "enemy", "hero", ultimate.ability_id)
	assert(solo_result.success)
	assert(solo_result.events.filter(func(event: Dictionary) -> bool: return event.type == "attack").size() == ultimate.effects[0].hit_count)
	var missed_state: BattleState = BattleState.begin(definition, party[0], 56)
	var missed_boss: BattleParticipant = missed_state.get_enemy()
	missed_boss.accuracy_bonus = -100
	missed_state.get_hero().base_dodge_percent = 100
	var miss: Dictionary = AbilityExecutor.execute(missed_state.create_context(), "enemy", "hero", grip.ability_id)
	assert(miss.success)
	assert(missed_boss.fury() == rules.gain_on_missed_action)
	assert(not missed_state.get_hero().statuses.has(grip.effects[1].status_id))
	var blocked_state: BattleState = BattleState.begin(definition, party[0], 57)
	var blocked_boss: BattleParticipant = blocked_state.get_enemy()
	blocked_state.get_hero().block_armor = 100
	var blocked: Dictionary = AbilityExecutor.execute(BattleContext.new(blocked_state.participants), "enemy", "hero", grip.ability_id)
	assert(blocked.success)
	assert(blocked_boss.fury() == rules.gain_on_blocked_action)
	assert(not blocked_state.get_hero().statuses.has(grip.effects[1].status_id))
	assert(definition.max_health == BattleParticipant.from_monster(definition).max_health)
	print("Kadavr boss: OK")
	quit()

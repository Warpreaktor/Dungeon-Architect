extends SceneTree


func _initialize() -> void:
	for hero_id in HeroCatalog.list_ids():
		var definition: HeroDefinition = HeroCatalog.get_hero(hero_id)
		var hero := HeroState.new(definition)
		assert(not definition.personal_ability_ids.is_empty())
		var special: String = definition.personal_ability_ids[0]
		assert(hero.can_select_action(special))
		var state := BattleState.begin(MonsterCatalog.get_monster("skeleton"), hero)
		var actor: BattleParticipant = state.get_hero()
		assert(AbilityCatalog.round_hero_ability_ids(actor).has(special))
		for index in range(1, definition.personal_ability_ids.size()):
			var id: String = definition.personal_ability_ids[index]
			assert(AbilityCatalog.knows_ability(actor, id))
			assert(AbilityCatalog.is_personal_ability_locked(actor, id))
			assert(not hero.can_select_action(id))
			assert(not AbilityCatalog.can_prepare(actor, id))
			assert(not BattleChainPlanner.validate([id], actor, false).is_empty())
			var old_slots: Array[String] = hero.get_saved_action_slots()
			old_slots[0] = id
			assert(not hero.save_action_slots(old_slots))
			actor.action_chain = [id]
			assert(not AbilityCatalog.round_hero_ability_ids(actor).has(id))
			actor.learned_ability_ids.append(id)
			assert(not AbilityExecutor.execute(state.create_context(), "hero", "enemy", id).success)
			var snapshot: Dictionary = hero.to_snapshot()
			snapshot["saved_action_slots"] = old_slots
			var restored: HeroState = HeroState.from_snapshot(snapshot)
			assert(restored != null and not restored.get_saved_action_slots().has(id))
		actor.health = 1
		assert(is_equal_approx(AbilityCatalog.passive_damage_multiplier(actor), 1.0))
	var enemy: BattleParticipant = BattleParticipant.from_monster(MonsterCatalog.get_monster("skeleton"))
	for id in enemy.personal_ability_ids:
		assert(not AbilityCatalog.is_personal_ability_locked(enemy, id))
	quit()

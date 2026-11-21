extends SceneTree

## DA-4.08: базовый блок, разрушение щита, досрочный отдых, резервирование.
func _initialize() -> void:
	# Без щита блок всегда работает и выдаёт +25%.
	var wolf := HeroState.new(HeroCatalog.get_hero("petushan"))
	wolf.learned_ability_ids.append_array(["guard", "basic_strike"])
	var battle := BattleState.begin(MonsterCatalog.get_monster("lobar"), wolf)
	var actor: BattleParticipant = battle.get_hero()
	assert(AbilityCatalog.can_prepare(actor, "guard"))
	assert(battle.execute_ability("hero", "hero", "guard").success)
	assert(actor.block_armor == 2 and actor.block_attack_bonus_percent == 25)
	var no_shield_hit: Dictionary = AbilityExecutor.apply_damage(battle.get_enemy(), actor, 5)
	assert(no_shield_hit.block_absorbed == 2)
	assert(no_shield_hit.shield_blocked == 0)
	assert(no_shield_hit.damage == 3)

	# Щит с бронёй 5 и остатком прочности 1 полностью защищает ЭТОТ
	# удар, но разрушен для следующего блока.
	var item: ItemDefinition = ItemCatalog.get_item("spiked_shield")
	var shield_hero := HeroState.new(HeroCatalog.get_hero("petushan"))
	shield_hero.register_shield(item)
	assert(shield_hero.equip_item(item))
	shield_hero.shield_durabilities[item.item_id] = [1]
	var shield_battle := BattleState.begin(MonsterCatalog.get_monster("lobar"), shield_hero)
	var protected: BattleParticipant = shield_battle.get_hero()
	assert(shield_battle.execute_ability("hero", "hero", "guard").success)
	assert(protected.block_armor == 5)
	var impact: Dictionary = AbilityExecutor.apply_damage(shield_battle.get_enemy(), protected, 8)
	assert(impact.block_absorbed == 5 and impact.shield_blocked == 5)
	assert(impact.damage == 3 and impact.shield_broken == "spiked_shield")
	assert(protected.equipped_shield_id.is_empty())
	assert(shield_battle.execute_ability("hero", "hero", "guard").success)
	assert(protected.block_armor == 2 and protected.block_attack_bonus_percent == 50)

	# Прочность уходит на полную силу удара по щиту, а не только на 5
	# поглощённых HP. Блок без щита после разрушения не исчезает.
	var shield2 := HeroState.new(HeroCatalog.get_hero("petushan"))
	shield2.register_shield(item)
	assert(shield2.equip_item(item))
	var wear := BattleState.begin(MonsterCatalog.get_monster("lobar"), shield2)
	var defender: BattleParticipant = wear.get_hero()
	assert(wear.execute_ability("hero", "hero", "guard").success)
	var initial: int = defender._hero_snapshot.current_shield_durability(item.item_id)
	var hit: Dictionary = AbilityExecutor.apply_damage(wear.get_enemy(), defender, 7)
	assert(hit.shield_blocked == 5 and hit.damage == 2)
	assert(defender._hero_snapshot.current_shield_durability(item.item_id) == initial - 7)

	# Даже если в старых данных есть базовая защита, она не применяется.
	var armored := HeroState.new(HeroCatalog.get_hero("petushan"))
	armored.base_defense = 3
	armored.register_shield(item)
	assert(armored.equip_item(item))
	var capped := BattleState.begin(MonsterCatalog.get_monster("lobar"), armored)
	var capped_actor: BattleParticipant = capped.get_hero()
	assert(capped.execute_ability("hero", "hero", "guard").success)
	var capped_hit: Dictionary = AbilityExecutor.apply_damage(capped.get_enemy(), capped_actor, 10)
	assert(capped_hit.block_absorbed == item.defense_bonus)
	assert(capped_hit.damage == 10 - item.defense_bonus)
	assert(capped_actor._hero_snapshot.current_shield_durability(item.item_id) == item.max_durability - 10)

	# Несколько эффектов оплачиваются единожды, не хватает запаса —
	# ни HP, ни эффекты и ни ресурсы не меняются.
	var paid := AbilityDefinition.new()
	paid.ability_id = "paid_test"
	paid.display_name = "Проверочный приём"
	paid.target = AbilityDefinition.Target.ENEMY
	paid.resource_costs = {"focus": 4}
	var damage := AbilityEffectDefinition.new()
	damage.kind = AbilityEffectDefinition.Kind.DAMAGE
	damage.recipient = AbilityEffectDefinition.Recipient.TARGET
	var healing := AbilityEffectDefinition.new()
	healing.kind = AbilityEffectDefinition.Kind.HEAL
	healing.recipient = AbilityEffectDefinition.Recipient.SELF
	healing.amount = 2
	paid.effects = [damage, healing]
	var user: BattleParticipant = battle.get_hero()
	user.personal_ability_ids.append("paid_test")
	user.resource_amounts = {"focus": 6}
	var first: Dictionary = battle.execute_definition("hero", "enemy", paid)
	assert(first.success)
	assert(user.resource_amounts["focus"] == 2)
	assert(first.events.size() == 3) # расход, урон, лечение
	var enemy_hp: int = battle.get_enemy().health
	var event_count: int = battle.events.size()
	var failed: Dictionary = battle.execute_definition("hero", "enemy", paid)
	assert(not failed.success and failed.reason.contains("focus"))
	assert(user.resource_amounts["focus"] == 2)
	assert(battle.get_enemy().health == enemy_hp and battle.events.size() == event_count)
	var bad_target: Dictionary = battle.execute_definition("hero", "hero", paid)
	assert(not bad_target.success and user.resource_amounts["focus"] == 2)
	paid.resource_costs = {"focus": -1}
	assert(not paid.validation_error().is_empty())

	# Устаревшая способность в готовой цепочке не срывает всю фазу.
	var rest_battle := BattleState.begin(MonsterCatalog.get_monster("lobar"), wolf)
	assert(rest_battle.run_phase(["guard", "basic_strike", "guard"], ["guard", "basic_strike"]).success)
	rest_battle.get_hero().personal_ability_ids.erase("basic_strike")
	var sequence: Dictionary = rest_battle.run_phase(["guard", "basic_strike", "guard"], ["guard", "basic_strike"])
	assert(sequence.success)
	var saw_rest: bool = false
	for event in sequence.events:
		if event.type == "rest" and event.actor_id == "hero":
			saw_rest = true
	assert(saw_rest)
	assert(rest_battle.flow.stage == BattleFlow.Stage.BETWEEN_PHASES)
	assert(rest_battle.get_hero().block_attack_bonus_percent >= 50)

	assert(not rest_battle.configure_hero_chain(["guard", "guard", "guard"]).success)
	assert(rest_battle.get_hero().action_chain == ["guard", "basic_strike", "guard"])

	var reorder_battle := BattleState.begin(MonsterCatalog.get_monster("lobar"), wolf)
	var original: Array[String] = ["guard", "basic_strike", "guard"]
	assert(reorder_battle.run_phase(original, ["guard", "basic_strike"]).success)
	var reordered: Array[String] = ["guard", "guard", "basic_strike"]
	assert(reorder_battle.configure_hero_chain(reordered).success)
	assert(reorder_battle.get_hero().action_cursor == 0)
	assert(reorder_battle.run_phase(reordered, ["guard", "basic_strike"]).success)
	assert(not bool(reorder_battle.last_phase_events[0].get("hero_reload", false)))
	var last_tick: Dictionary = {}
	for event in reorder_battle.last_phase_events:
		if event.type == "tick":
			last_tick = event
	assert(bool(last_tick.get("hero_reload", false)))
	assert(not reorder_battle.configure_hero_chain(["guard", "guard"]).success)
	quit()

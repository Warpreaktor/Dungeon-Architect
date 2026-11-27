extends SceneTree


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	for hero_id in HeroCatalog.list_ids():
		var hero := HeroState.new(HeroCatalog.get_hero(hero_id))
		var saved: Array[String] = hero.get_saved_action_slots()
		var special: String = hero.definition.personal_ability_ids[0]
		var weapon_ids: Array[String] = ItemCatalog.equipment_ids()
		weapon_ids.append_array(ItemCatalog.STARTER_ONLY_EQUIPMENT_IDS)
		for item_id in weapon_ids:
			var weapon: ItemDefinition = ItemCatalog.get_item(item_id)
			if weapon.equipment_slot != ItemDefinition.EquipmentSlot.WEAPON:
				continue
			if hero.equipped_weapon_id != item_id:
				assert(hero.equip_item(weapon))
			var state := BattleState.begin(MonsterCatalog.get_monster("skeleton"), hero, 42)
			var actor: BattleParticipant = state.get_hero()
			var strike_id: String = MonsterWeaponStrike.ability_id(item_id)
			var strike: AbilityDefinition = AbilityCatalog.get_ability(strike_id)
			assert(strike != null and strike.validation_error().is_empty())
			assert(strike.icon == (weapon.monster_attack_icon if weapon.monster_attack_icon != null else weapon.icon))
			assert(AbilityCatalog.round_hero_ability_ids(actor) == [special, strike_id])
			assert(AbilityCatalog.can_prepare(actor, strike_id))
			assert(not AbilityCatalog.uses_hero_action_slot(strike_id))
			assert(not hero.can_select_action(strike_id))
			assert(hero.get_saved_action_slots() == saved)
			assert(not hero.learned_ability_ids.has(strike_id))
			var expected: int = actor.ranged_attack() if weapon.weapon_kind == ItemDefinition.WeaponKind.RANGED else actor.melee_attack()
			assert(AbilityExecutor.preview_damage(actor, strike, strike.effects[0]) == expected)
			assert(AbilityExecutor.execute(state.create_context(), "hero", "enemy", strike_id).success)
			for id in hero.definition.personal_ability_ids.slice(1):
				assert(not AbilityCatalog.round_hero_ability_ids(actor).has(id))
		assert(hero.unequip_item(hero.equipped_weapon_id))
		var unarmed := BattleParticipant.from_hero(hero)
		assert(AbilityCatalog.equipped_weapon_ability_id(unarmed).is_empty())
		assert(AbilityCatalog.known_ability_ids(unarmed).all(func(id: String) -> bool: return not MonsterWeaponStrike.is_weapon_strike(id)))

	var wolf := HeroState.new(HeroCatalog.get_hero("volcha"))
	wolf.agility = 100
	assert(wolf.equip_item(ItemCatalog.get_item("sword")))
	var rooster := HeroState.new(HeroCatalog.get_hero("petushan"))
	assert(rooster.equip_item(ItemCatalog.get_item("dagger")))
	var sword_id: String = MonsterWeaponStrike.ability_id("sword")
	var dagger_id: String = MonsterWeaponStrike.ability_id("dagger")
	var party: Array[HeroState] = [wolf, rooster]
	var combat := CombatSession.new(MonsterCatalog.get_monster("skeleton"), wolf, null, 42, party)
	var state: BattleState = combat.battle_state
	var actor: BattleParticipant = state.get_hero()
	var other: BattleParticipant = state.get_participant("hero_2")
	assert(AbilityCatalog.round_hero_ability_ids(actor).has(sword_id))
	assert(not AbilityCatalog.round_hero_ability_ids(actor).has(dagger_id))
	assert(AbilityCatalog.round_hero_ability_ids(other).has(dagger_id))
	assert(not AbilityCatalog.round_hero_ability_ids(other).has(sword_id))
	var view := (load("res://scenes/battle_view.tscn") as PackedScene).instantiate() as BattleView
	root.add_child(view)
	view.begin(combat, wolf)
	var index: int = view._hero_chain.find(sword_id)
	assert(index >= 0)
	var slot: BattleAbilitySlot = view._sequence_slots.get_child(index) as BattleAbilitySlot
	assert(not slot.disabled and not slot._slot_number.visible)
	assert(state.prepare_next_round() == "hero")
	assert(not state.run_round_turn("enemy", dagger_id).success)
	assert(state.run_round_turn("enemy", sword_id).success)
	view.queue_free()

	assert(wolf.equip_item(ItemCatalog.get_item("battle_axe")))
	var next := BattleState.begin(MonsterCatalog.get_monster("skeleton"), wolf, 42)
	var next_actor: BattleParticipant = next.get_hero()
	var axe_id: String = MonsterWeaponStrike.ability_id("battle_axe")
	next_actor.learned_ability_ids.append(sword_id)
	assert(not AbilityCatalog.knows_ability(next_actor, sword_id))
	assert(not AbilityExecutor.execute(next.create_context(), "hero", "enemy", sword_id).success)
	assert(AbilityCatalog.round_hero_ability_ids(next_actor).has(axe_id))
	var profile := BattleArsenalView.new()
	root.add_child(profile)
	profile.open_for(wolf)
	var found: bool = false
	for child in profile._skills_grid.get_children():
		var card := child as BattleAbilitySlot
		if card._slot_name.text == AbilityCatalog.get_ability(axe_id).display_name:
			found = true
			assert(not card._slot_number.visible)
	assert(found)
	profile.queue_free()
	quit()

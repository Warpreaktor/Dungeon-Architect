extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rooster := HeroState.new(HeroCatalog.get_hero("petushan"))
	var wolf := HeroState.new(HeroCatalog.get_hero("volcha"))
	rooster.agility = 100
	wolf.agility = 90
	wolf.bonus_action_slots = 2
	var chosen: Array[String] = ["petushan_feathers_up", "petushan_peck_while_hot", "petushan_last_crow"]
	var wolf_chosen: Array[String] = ["volcha_cut_tendons", "volcha_wolf_lunge", "volcha_last_fang", "", "volcha_hunting_instinct"]
	assert(rooster.save_action_slots(chosen))
	assert(wolf.save_action_slots(wolf_chosen))
	var shield: ItemDefinition = ItemCatalog.get_item("spiked_shield")
	rooster.register_shield(shield)
	assert(rooster.equip_item(shield))
	assert(not rooster.save_action_slots(["guard", "", ""]))
	rooster.shield_durabilities[shield.item_id] = [1]
	var party: Array[HeroState] = [rooster, wolf]
	var combat := CombatSession.new(MonsterCatalog.get_monster("skeleton"), rooster, null, 4277, party)
	var state: BattleState = combat.battle_state
	var actor: BattleParticipant = state.get_hero()
	var expected: Array[String] = chosen.duplicate()
	expected.append("guard")
	var view := (load("res://scenes/battle_view.tscn") as PackedScene).instantiate() as BattleView
	root.add_child(view)
	view.begin(combat, rooster)
	assert(state.round_combat_active)
	assert(view._hero_chain == expected)
	assert(view._sequence_slots.get_child_count() == rooster.action_slot_capacity() + 2)
	assert(not view._hero_chain.has("petushan_red_comb"))
	assert(not view._hero_chain.has("petushan_rooster_whirlwind"))
	assert(not (view._sequence_slots.get_child(3) as BattleAbilitySlot)._slot_number.visible)
	assert(not (view._sequence_slots.get_child(4) as BattleAbilitySlot)._slot_number.visible)
	view._select_hero_view("hero_2")
	assert(view._hero_chain == ["volcha_cut_tendons", "volcha_wolf_lunge", "volcha_last_fang", "volcha_hunting_instinct"])
	assert(view._sequence_slots.get_child_count() == 5)
	assert(not view._hero_chain.has("guard"))
	view._select_hero_view("hero")
	assert(state.prepare_next_round() == "hero")
	var energy: int = actor.current_energy()
	var enemy_hp: int = state.get_enemy().health
	var events_before: int = state.events.size()
	assert(not state.run_round_turn("enemy", "petushan_rooster_whirlwind").success)
	assert(not state.execute_ability("hero", "enemy", "petushan_rooster_whirlwind").success)
	assert(not state.configure_hero_chain(["petushan_rooster_whirlwind"]).success)
	assert(state.round_turn_count == 0 and state.events.size() == events_before)
	assert(actor.current_energy() == energy and state.get_enemy().health == enemy_hp)
	assert(rooster.save_action_slots(["petushan_rooster_whirlwind", "", ""]))
	assert(AbilityCatalog.round_hero_ability_ids(actor) == expected)
	assert(state.run_round_turn("hero", "guard").success)
	AbilityExecutor.apply_damage(state.get_enemy(), actor, 6)
	assert(actor.equipped_shield_id.is_empty())
	view._refresh_chain_slots()
	assert(view._hero_chain == chosen)
	assert(view._sequence_slots.get_child_count() == chosen.size() + 1)
	assert(state.prepare_next_round() == "hero_2")
	assert(not state.run_round_turn("enemy", "volcha_broken_rhythm").success)
	assert(state.run_round_turn("", "rest").success)
	view.queue_free()
	var next := BattleState.begin(MonsterCatalog.get_monster("skeleton"), rooster, 4277)
	assert(AbilityCatalog.round_hero_ability_ids(next.get_hero()).has("petushan_rooster_whirlwind"))
	assert(not AbilityCatalog.round_hero_ability_ids(next.get_hero()).has("petushan_peck_while_hot"))
	var unprepared := HeroState.new(HeroCatalog.get_hero("petushan"))
	unprepared.energy = 0
	assert(unprepared.save_action_slots(["", "", ""]))
	var profile := BattleArsenalView.new()
	root.add_child(profile)
	profile.open_for(unprepared)
	profile._toggle_ability("petushan_last_crow")
	assert(unprepared.get_saved_action_slots() == ["petushan_last_crow", "", ""])
	assert(profile._slots_label.text.ends_with("1 / 3"))
	profile.dismiss()
	profile.queue_free()
	var saved: HeroState = HeroState.from_snapshot(unprepared.to_snapshot())
	assert(saved != null and saved.get_saved_action_slots() == unprepared.get_saved_action_slots())
	quit()

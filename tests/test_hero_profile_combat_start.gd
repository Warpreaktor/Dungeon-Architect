extends SceneTree


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	for hero_id in ["petushan", "volcha"]:
		var hero := HeroState.new(HeroCatalog.get_hero(hero_id))
		assert(hero.get_saved_action_slots() == hero.definition.personal_ability_ids.slice(0, hero.action_slot_capacity()))
		var member := PartyPortraitSlot.new()
		root.add_child(member)
		member.display_member(hero)
		var selected: Array[HeroState] = []
		member.character_requested.connect(func(value: HeroState) -> void: selected.append(value))
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		member._on_portrait_input(event)
		assert(selected.size() == 1 and selected[0] == hero)
		member.queue_free()
		var combat := CombatSession.new(MonsterCatalog.get_monster("skeleton"), hero)
		var view := (load("res://scenes/battle_view.tscn") as PackedScene).instantiate() as BattleView
		root.add_child(view)
		view.begin(combat, hero)
		assert(view._manual_started)
		assert(combat.battle_state.manual_combat_active)
		assert(not view.has_node("%PunchButton"))
		assert(view._hero_chain == hero.get_saved_action_slots())
		view.queue_free()
		if hero_id == "petushan":
			assert(hero.save_action_slots(["", "", ""]))
			var empty_battle := CombatSession.new(MonsterCatalog.get_monster("skeleton"), hero)
			var empty_view := (load("res://scenes/battle_view.tscn") as PackedScene).instantiate() as BattleView
			root.add_child(empty_view)
			empty_view.begin(empty_battle, hero)
			assert(empty_view._manual_started)
			assert(empty_view._hero_chain.is_empty())
			assert(empty_battle.battle_state.manual_available_slots().is_empty())
			empty_view.queue_free()
	quit()

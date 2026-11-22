extends SceneTree


func _initialize() -> void:
	var hero := HeroState.new()
	var prepared: Array[String] = []
	for index in range(hero.action_slot_capacity()):
		prepared.append("basic_strike")
	assert(hero.save_action_slots(prepared))
	var combat := CombatSession.new(MonsterCatalog.get_monster(MonsterCatalog.DEFAULT_MONSTER_ID), hero)
	var scene: PackedScene = load("res://scenes/battle_view.tscn")
	var view: BattleView = scene.instantiate() as BattleView
	root.add_child(view)
	view.begin(combat, hero)
	assert(view._manual_started)
	assert(combat.battle_state.manual_combat_active)
	assert(combat.battle_state.flow.phase_number == 0)
	assert(view._sequence_slots.get_child_count() == prepared.size() + 1)
	view._on_slot_selected(0)
	assert(view._selected_manual_slot == 0)
	var ability: AbilityDefinition = AbilityCatalog.get_ability(prepared[0])
	var valid_targets: Array[String] = combat.battle_state.create_context().target_ids("hero", ability)
	assert(not valid_targets.is_empty())
	assert(not view.has_node("%PunchButton"))
	assert(view._target_outlines[valid_targets[0]].visible)
	view._on_target_portrait_input(_tap_event(), "hero")
	assert(combat.battle_state.flow.completed_ticks == 0)
	view._on_target_portrait_input(_tap_event(), valid_targets[0])
	assert(combat.battle_state.flow.completed_ticks == 1)
	assert(combat.battle_state.manual_used_slots == [0])
	assert(view._is_playing_back)
	view._on_target_portrait_input(_tap_event(), valid_targets[0])
	assert(combat.battle_state.flow.completed_ticks == 1)
	view.queue_free()

	var rest_combat := CombatSession.new(MonsterCatalog.get_monster("giant_crab"), hero)
	var rest_view: BattleView = scene.instantiate() as BattleView
	root.add_child(rest_view)
	rest_view.begin(rest_combat, hero)
	var rest_card: BattleAbilitySlot = rest_view._sequence_slots.get_child(prepared.size()) as BattleAbilitySlot
	assert(not rest_card.disabled)
	rest_card._notify_selection()
	assert(rest_combat.battle_state.flow.completed_ticks == 1)
	assert(rest_combat.battle_state.get_hero().completed_phases == 1)
	assert(rest_combat.battle_state.manual_available_slots() == [0, 1, 2])
	assert(rest_view._is_playing_back)
	var hero_reload: bool = false
	for event in rest_combat.battle_state.last_phase_events:
		if event.get("type") == "reload" and event.get("actor_id") == "hero" and event.get("target_id") == "hero":
			hero_reload = true
	assert(hero_reload)
	rest_view.queue_free()
	quit()


func _tap_event() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event

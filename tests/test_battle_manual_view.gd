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
	assert(not view._manual_started)
	view._on_punch_pressed()
	assert(view._manual_started)
	assert(combat.battle_state.manual_combat_active)
	assert(combat.battle_state.flow.phase_number == 0)
	assert(view._sequence_slots.get_child_count() == prepared.size() + 1)
	view._on_slot_selected(0)
	assert(view._selected_manual_slot == 0)
	var ability: AbilityDefinition = AbilityCatalog.get_ability(prepared[0])
	var valid_targets: Array[String] = combat.battle_state.create_context().target_ids("hero", ability)
	assert(not valid_targets.is_empty())
	assert(not view._punch_button.visible)
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
	quit()


func _tap_event() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event

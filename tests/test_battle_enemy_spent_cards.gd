extends SceneTree


func _initialize() -> void:
	var definition: MonsterDefinition = MonsterCatalog.get_monster("skeleton")
	var hero := HeroState.new()
	var combat := CombatSession.new(definition, hero, definition, 1234)
	var scene: PackedScene = load("res://scenes/battle_view.tscn")
	var view: BattleView = scene.instantiate() as BattleView
	root.add_child(view)
	view.begin(combat, hero)

	var first_id: String = combat.battle_state.get_enemy().action_chain[0]
	view._display_phase_event({"type": "action_start", "actor_id": "enemy", "slot_index": 0, "ability_id": first_id})
	var first: BattleAbilitySlot = view._enemy_sequence_slots.get_child(0) as BattleAbilitySlot
	assert(first.modulate == BattleAbilitySlot.SPENT_MODULATE)
	assert(view._enemy_played.has(0))
	view._refresh_enemy_slots()
	first = view._enemy_sequence_slots.get_child(0) as BattleAbilitySlot
	assert(first.modulate == BattleAbilitySlot.SPENT_MODULATE)
	view._display_phase_event({"type": "reload", "actor_id": "enemy"})
	assert(view._enemy_played.is_empty())
	assert(first.modulate == Color.WHITE)

	var support: BattleParticipant = combat.battle_state.get_participant(BattleState.SUPPORT_ENEMY_ID)
	var support_id: String = support.action_chain[0]
	view._display_phase_event({"type": "action_start", "actor_id": BattleState.SUPPORT_ENEMY_ID,
		"slot_index": 0, "ability_id": support_id})
	var support_slot: Button = view._support_enemy_view._slots.get_child(0) as Button
	assert(support_slot.modulate == BattleAbilitySlot.SPENT_MODULATE)
	assert(view._support_enemy_view._played.has(0))
	view._display_phase_event({"type": "reload", "actor_id": BattleState.SUPPORT_ENEMY_ID})
	assert(view._support_enemy_view._played.is_empty())
	assert(support_slot.modulate == Color.WHITE)
	view.queue_free()
	quit()

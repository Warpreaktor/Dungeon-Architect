extends SceneTree


func _initialize() -> void:
	var hero := HeroState.new(HeroCatalog.get_hero("volcha"))
	hero.agility = 100
	var prepared: Array[String] = ["volcha_wolf_lunge", "volcha_strike_and_rebound", "volcha_cut_tendons"]
	assert(hero.save_action_slots(prepared))
	var monster: MonsterDefinition = MonsterCatalog.get_monster("skeleton")
	var combat := CombatSession.new(monster, hero)
	var scene: PackedScene = load("res://scenes/battle_view.tscn")
	var view: BattleView = scene.instantiate() as BattleView
	root.add_child(view)
	view.begin(combat, hero)
	view._continue_round()
	assert(view._round_mode and combat.battle_state.round_combat_active)
	assert(view._sequence_slots.get_child_count() == prepared.size() + 1)
	assert(view._hero_chain == prepared)
	view._on_slot_selected(0)
	assert(view._selected_round_ability_id == prepared[0])
	assert(not view.has_node("%PunchButton"))
	assert(view._target_outlines["enemy"].visible)
	view._on_target_portrait_input(_tap_event(), "hero")
	assert(combat.battle_state.round_turn_count == 0)
	view._on_target_portrait_input(_tap_event(), "enemy")
	assert(combat.battle_state.round_turn_count == 1)
	assert(view._is_playing_back)
	view._on_target_portrait_input(_tap_event(), "enemy")
	assert(combat.battle_state.round_turn_count == 1)
	view.queue_free()

	var resting := HeroState.new(HeroCatalog.get_hero("volcha"))
	resting.agility = 100
	resting.energy = 1
	assert(resting.save_action_slots(["", "", ""]))
	var rest_combat := CombatSession.new(monster, resting)
	var rest_view: BattleView = scene.instantiate() as BattleView
	root.add_child(rest_view)
	rest_view.begin(rest_combat, resting)
	rest_view._continue_round()
	assert(rest_view._sequence_slots.get_child_count() == 1)
	var rest_card: BattleAbilitySlot = rest_view._sequence_slots.get_child(0) as BattleAbilitySlot
	assert(not rest_card.disabled)
	rest_card._notify_selection()
	assert(rest_combat.battle_state.round_turn_count == 1)
	assert(rest_combat.battle_state.get_hero().current_energy() > 1)
	assert(rest_combat.battle_state.events.any(func(event: Dictionary) -> bool:
		return event.get("type") == "rest" and event.get("actor_id") == "hero"))
	assert(rest_view._is_playing_back)
	rest_view.queue_free()
	quit()


func _tap_event() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event

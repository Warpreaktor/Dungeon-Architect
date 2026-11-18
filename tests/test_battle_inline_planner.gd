extends SceneTree

## Три слота, сохранение раскладки и ограничения редактора в бою.
func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var scene: PackedScene = load("res://scenes/battle_view.tscn") as PackedScene
	var hero := HeroState.new(HeroCatalog.get_hero("volcha"))
	var monster: MonsterDefinition = MonsterCatalog.get_monster("lobar")
	var combat := CombatSession.new(monster, hero)
	var view: BattleView = scene.instantiate() as BattleView
	root.add_child(view)
	view.begin(combat, hero)
	var slots: HBoxContainer = view.get_node("%SequenceSlots") as HBoxContainer
	var play: Button = view.get_node("%PunchButton") as Button
	assert(slots.get_child_count() == 3)
	assert(play.disabled)
	assert(not view.has_node("%SequenceHint"))
	assert(view.find_children("*", "AcceptDialog", true, false).is_empty())
	assert(hero.get_saved_action_slots() == ["", "", ""])

	view._on_slot_selected(0)
	var picker: PanelContainer = view.get_node("AbilityPicker") as PanelContainer
	assert(picker.visible)
	view._choose_ability(0, "basic_strike")
	assert(not picker.visible)
	assert(not play.disabled)
	view._choose_ability(2, "wolf_feint")
	assert(slots.get_child_count() == 3)
	assert(view._draft_actions() == ["basic_strike", "wolf_feint"])
	assert((slots.get_child(0) as Button).tooltip_text.contains("Урон:"))
	assert(not (slots.get_child(2) as Button).tooltip_text.is_empty())
	assert(view._commit_draft())
	assert(hero.get_saved_action_slots() == ["basic_strike", "", "wolf_feint"])
	assert(combat.battle_state.get_hero().action_chain == ["basic_strike", "wolf_feint"])

	# При повторной встрече тот же HeroState восстанавливает и пустую среднюю позицию.
	view.queue_free()
	var repeat: BattleView = scene.instantiate() as BattleView
	root.add_child(repeat)
	var next_combat := CombatSession.new(monster, hero)
	repeat.begin(next_combat, hero)
	assert(repeat._planner_editing == ["basic_strike", "", "wolf_feint"])
	assert(not (repeat.get_node("%PunchButton") as Button).disabled)
	assert((repeat.get_node("%SequenceSlots") as HBoxContainer).get_child_count() == 3)

	# Изменение без разрешения в обычной паузе невозможно.
	assert(next_combat.battle_state.flow.start_phase())
	assert(next_combat.battle_state.flow.complete_phase())
	repeat._refresh_phase_controls()
	repeat._choose_ability(0, "guard")
	assert(repeat._planner_editing == ["basic_strike", "", "wolf_feint"])
	assert(hero.get_saved_action_slots() == ["basic_strike", "", "wolf_feint"])

	# При отмене перенастройки последний утверждённый вариант сохраняется.
	next_combat.battle_state.flow.reconfiguration_tokens = 1
	repeat._refresh_phase_controls()
	repeat._on_guard_pressed()
	assert(next_combat.battle_state.flow.stage == BattleFlow.Stage.RECONFIGURING)
	repeat._choose_ability(0, "guard")
	assert(repeat._planner_editing[0] == "guard")
	repeat._on_guard_pressed()
	assert(next_combat.battle_state.flow.stage == BattleFlow.Stage.BETWEEN_PHASES)
	assert(hero.get_saved_action_slots() == ["basic_strike", "", "wolf_feint"])
	assert(repeat._planner_editing == ["basic_strike", "", "wolf_feint"])
	repeat.queue_free()
	quit()

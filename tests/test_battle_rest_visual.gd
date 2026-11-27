extends SceneTree

func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var scene: PackedScene = load("res://scenes/battle_view.tscn") as PackedScene
	var hero := HeroState.new(HeroCatalog.get_hero("volcha"))
	assert(not hero.save_action_slots(["wolf_feint", "guard", "basic_strike"]))
	var view: BattleView = scene.instantiate() as BattleView
	root.add_child(view)
	view.begin(CombatSession.new(MonsterCatalog.get_monster("hunter"), hero), hero)
	assert(hero.get_saved_action_slots() == [hero.definition.personal_ability_ids[0], "", ""])
	assert((view.get_node("%HeroDefenseValue") as Label).text == "0")
	assert((view.get_node("%EnemyDefenseValue") as Label).text == "0")
	view._display_phase_event({"type": "block", "actor_id": "enemy", "target_id": "enemy", "armor": 2})
	assert((view.get_node("%EnemyDefenseValue") as Label).text == "2")
	view._set_block_display("enemy", 0)
	assert((view.get_node("%EnemyDefenseValue") as Label).text == "0")
	var yours: HBoxContainer = view.get_node("%SequenceSlots") as HBoxContainer
	var theirs: HBoxContainer = view.get_node("%EnemySequenceSlots") as HBoxContainer
	assert(yours.get_child_count() == 2)
	assert(theirs.get_child_count() == view._enemy_chain.size())
	var hero_rest: BattleAbilitySlot = yours.get_child(1) as BattleAbilitySlot
	assert(not hero_rest.disabled)
	assert(hero_rest.tooltip_text.contains("Отдых"))
	assert(not hero_rest._slot_number.visible)
	assert(hero_rest.get_node("SlotMargin/Row/SlotIcon").texture == BattleAbilitySlot.REST_ICON)
	view._highlight_slots(-1, -1, true, true)
	assert(hero_rest.has_theme_stylebox_override("disabled"))
	assert(view._hero_chain.size() == 1)
	view.queue_free()
	quit()

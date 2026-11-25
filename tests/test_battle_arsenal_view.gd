extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var hero := HeroState.new(HeroCatalog.get_hero("petushan"))
	var view := BattleArsenalView.new()
	root.add_child(view)
	var initial: Array[String] = hero.get_saved_action_slots()
	assert(initial.size() == 3)
	assert(hero.definition.personal_ability_ids.size() == 10)
	view.open_for(hero)
	assert(view._profile_content.visible)
	assert(view._arsenal_content.visible)
	assert(view._skills_grid.get_child_count() == 10)
	view._toggle_ability("petushan_red_comb")
	assert(hero.get_saved_action_slots() == initial)
	view._toggle_ability(initial[0])
	assert(hero.get_saved_action_slots() == [initial[1], initial[2], ""])
	view._toggle_ability("petushan_feathers_up")
	assert(hero.get_saved_action_slots() == [initial[1], initial[2], "petushan_feathers_up"])
	view._toggle_ability(initial[1])
	view._toggle_ability(initial[2])
	view._toggle_ability("petushan_feathers_up")
	assert(hero.get_saved_action_slots() == ["", "", ""])
	view.dismiss()
	view.open_for(hero)
	assert(view._skills_grid.get_child_count() == 10)
	assert(hero.get_saved_action_slots() == ["", "", ""])
	view.dismiss()
	var second := HeroState.new(HeroCatalog.get_hero("petushan"))
	view.open_for(second)
	assert(second.get_saved_action_slots() == initial)
	view.dismiss()
	view.queue_free()
	quit()

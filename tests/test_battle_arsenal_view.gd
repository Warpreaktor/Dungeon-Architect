extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var hero := HeroState.new(HeroCatalog.get_hero("petushan"))
	var actor := BattleParticipant.from_hero(hero)
	var available: Array[AbilityDefinition] = AbilityCatalog.available_abilities(actor)
	assert(not available.is_empty())
	var ability_id: String = ""
	for ability in available:
		if AbilityCatalog.can_prepare(actor, ability.ability_id):
			ability_id = ability.ability_id
			break
	assert(not ability_id.is_empty())

	var view := BattleArsenalView.new()
	root.add_child(view)
	var initial: Array[String] = hero.get_saved_action_slots()
	assert(initial == hero.definition.personal_ability_ids)
	view.open_for(hero, null, true)
	assert(view._profile_content.visible)
	view._show_tab(false)
	assert(view._arsenal_content.visible)
	view._assign_ability(0, ability_id)
	assert(hero.get_saved_action_slots() == initial)
	view.dismiss()
	assert(hero.get_saved_action_slots() == initial)

	view.open_for(hero)
	view._assign_ability(0, ability_id)
	view._move_slot(0, 1)
	view._save()
	assert(hero.get_saved_action_slots()[1] == ability_id)
	assert(not view.visible)

	var second := HeroState.new(HeroCatalog.get_hero("petushan"))
	view.open_for(second, BattleParticipant.from_hero(second))
	assert(view._draft == second.definition.personal_ability_ids)
	view.dismiss()
	assert(hero.get_saved_action_slots()[1] == ability_id)
	view.queue_free()
	quit()

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
	view.open_for(hero)
	view._choose(ability_id)
	assert(hero.get_saved_action_slots()[0] == "")
	view.dismiss()
	assert(hero.get_saved_action_slots()[0] == "")

	view.open_for(hero)
	view._choose(ability_id)
	view._swap_slot(1)
	view._save()
	assert(hero.get_saved_action_slots()[0] == "")
	assert(hero.get_saved_action_slots()[1] == ability_id)
	assert(not view.visible)

	var second := HeroState.new(HeroCatalog.get_hero("petushan"))
	view.open_for(second, BattleParticipant.from_hero(second))
	assert(view._draft[1] == "")
	view.dismiss()
	assert(hero.get_saved_action_slots()[1] == ability_id)
	view.queue_free()
	quit()

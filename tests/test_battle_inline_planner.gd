extends SceneTree


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var hero := HeroState.new(HeroCatalog.get_hero("volcha"))
	var initial: Array[String] = hero.get_saved_action_slots()
	assert(initial == [hero.definition.personal_ability_ids[0], "", ""])
	var monster := MonsterCatalog.get_monster("lobar")
	var scene: PackedScene = load("res://scenes/battle_view.tscn") as PackedScene
	var view := scene.instantiate() as BattleView
	root.add_child(view)
	view.begin(CombatSession.new(monster, hero), hero)
	assert(view._round_mode and view._combat.battle_state.round_combat_active)
	assert(not view.has_node("%PunchButton"))
	assert(view._sequence_slots.get_child_count() == 2)
	assert(view._hero_chain == [initial[0]])
	assert(hero.get_saved_action_slots() == initial)
	view.queue_free()
	quit()

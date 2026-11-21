extends SceneTree


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var hero := HeroState.new(HeroCatalog.get_hero("volcha"))
	var initial: Array[String] = hero.get_saved_action_slots()
	assert(initial == hero.definition.personal_ability_ids)
	var monster := MonsterCatalog.get_monster("lobar")
	var scene: PackedScene = load("res://scenes/battle_view.tscn") as PackedScene
	var view := scene.instantiate() as BattleView
	root.add_child(view)
	view.begin(CombatSession.new(monster, hero), hero)
	assert(view._manual_started)
	assert(not view.has_node("%PunchButton"))
	assert(view._sequence_slots.get_child_count() == hero.action_slot_capacity() + 1)
	assert(view._hero_chain == initial)
	assert(hero.get_saved_action_slots() == initial)
	view.queue_free()
	quit()

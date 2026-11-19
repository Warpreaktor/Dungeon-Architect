extends SceneTree

## Дополнительный слот отдыха есть у обоих участников и не редактируется.
func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var scene: PackedScene = load("res://scenes/battle_view.tscn") as PackedScene
	var hero := HeroState.new(HeroCatalog.get_hero("volcha"))
	var view: BattleView = scene.instantiate() as BattleView
	root.add_child(view)
	view.begin(CombatSession.new(MonsterCatalog.get_monster("hunter"), hero), hero)
	var yours: HBoxContainer = view.get_node("%SequenceSlots") as HBoxContainer
	var theirs: HBoxContainer = view.get_node("%EnemySequenceSlots") as HBoxContainer
	assert(yours.get_child_count() == 4)
	assert(theirs.get_child_count() == 3)
	var hero_rest: BattleAbilitySlot = yours.get_child(3) as BattleAbilitySlot
	var enemy_rest: BattleAbilitySlot = theirs.get_child(2) as BattleAbilitySlot
	assert(hero_rest.disabled and enemy_rest.disabled)
	assert(hero_rest.tooltip_text.contains("Отдых") and enemy_rest.tooltip_text.contains("Отдых"))
	view._highlight_slots(-1, -1, true, true)
	assert(hero_rest.has_theme_stylebox_override("disabled"))
	assert(enemy_rest.has_theme_stylebox_override("disabled"))
	assert(view._planner_editing.size() == 3)
	view.queue_free()
	quit()

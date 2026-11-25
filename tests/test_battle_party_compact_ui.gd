extends SceneTree


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var scene: PackedScene = load("res://scenes/battle_view.tscn")
	var view: BattleView = scene.instantiate() as BattleView
	root.add_child(view)
	await process_frame
	assert(view._hero_party is HBoxContainer)
	assert(view._hero_party.get_parent().name == "HeroSide")
	assert(view._enemy_party.get_parent().name == "EnemySide")
	assert(not (view.get_node("OuterMargin/Main/Battlefield/HeroSide/HeroTeamLabel") as Label).visible)
	assert(not (view.get_node("OuterMargin/Main/Battlefield/EnemySide/EnemyTeamLabel") as Label).visible)
	for node_path in [
		"OuterMargin/Main/Battlefield/HeroSide/HeroParty/HeroCard/HeroMargin/HeroColumn/HeroStats",
		"OuterMargin/Main/Battlefield/HeroSide/HeroParty/HeroCard/HeroMargin/HeroColumn/HeroPrecisionStats",
		"OuterMargin/Main/Battlefield/EnemySide/EnemyParty/EnemyCard/EnemyMargin/EnemyStack/EnemyColumn/EnemyStats",
		"OuterMargin/Main/Battlefield/EnemySide/EnemyParty/EnemyCard/EnemyMargin/EnemyStack/EnemyColumn/EnemyPrecisionStats"
	]:
		assert(not (view.get_node(node_path) as Control).visible)

	var party: Array[HeroState] = []
	for hero_id in ["volcha", "petushan", "burolom", "luma"]:
		party.append(HeroState.new(HeroCatalog.get_hero(hero_id)))
	var combat := CombatSession.new(MonsterCatalog.get_monster("skeleton"), party[0], null, 7742, party)
	view.begin(combat, party[0])
	await process_frame
	assert(view._turn_frame_overlays.has("hero"))
	assert((view._turn_frame_overlays["hero"] as Control).visible)
	assert(view._turn_frame_overlays.has("enemy"))
	view._equalize_hero_cards()
	assert(view._hero_party.alignment == BoxContainer.ALIGNMENT_CENTER)
	assert((view.get_node("OuterMargin/Main/Battlefield/HeroSide/HeroParty/HeroCard") as Control).custom_minimum_size.x <= 202.0)
	for actor_id in ["hero_2", "hero_3", "hero_4"]:
		assert((view._extra_hero_views[actor_id] as BattleSupportEnemyView).visible)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	view._on_target_portrait_input(click, "hero_3")
	assert(view._hero_profile.visible)
	assert(view._hero_profile._read_only)
	assert(view._hero_profile._actor == combat.battle_state.get_participant("hero_3"))
	var previous: Array[String] = party[2].get_saved_action_slots()
	view._hero_profile._toggle_ability("basic_strike")
	assert(party[2].get_saved_action_slots() == previous)
	view._hero_profile.dismiss()
	view._on_target_portrait_input(click, "enemy")
	assert(not view._hero_profile.visible)

	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.position = Vector2(15.0, 15.0)
	touch.pressed = true
	view._on_target_portrait_input(touch, "hero_4")
	assert(not view._hero_profile.visible)
	view._on_inspection_long_press()
	assert(view._hero_profile.visible)
	assert(view._hero_profile._actor == combat.battle_state.get_participant("hero_4"))
	touch.pressed = false
	view._on_target_portrait_input(touch, "hero_4")
	assert(view._inspection_touch_index < 0)
	view._hero_profile.dismiss()

	touch.pressed = true
	view._on_target_portrait_input(touch, "hero_2")
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(66.0, 65.0)
	view._on_target_portrait_input(drag, "hero_2")
	assert(view._inspection_touch_index < 0)
	view._on_inspection_long_press()
	assert(not view._hero_profile.visible)

	touch.position = Vector2(15.0, 15.0)
	view._on_target_portrait_input(touch, "hero_2")
	touch.pressed = false
	view._on_target_portrait_input(touch, "hero_2")
	assert(not view._hero_profile.visible)

	view._support_hero_view.hide()
	for actor_id in ["hero_3", "hero_4"]:
		(view._extra_hero_views[actor_id] as Control).hide()
	view._equalize_hero_cards()
	assert((view.get_node("OuterMargin/Main/Battlefield/HeroSide/HeroParty/HeroCard") as Control).custom_minimum_size.x >= 160.0)
	view.queue_free()
	await process_frame
	quit()

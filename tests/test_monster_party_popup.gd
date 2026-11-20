extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var popup := load("res://scenes/chest_contents_popup.tscn").instantiate() as ChestContentsPopup
	root.add_child(popup)
	await process_frame
	var ids: Array[String] = MonsterCatalog.list_placeable_ids()
	assert(not ids.is_empty())
	for monster_id in MonsterCatalog.list_ids():
		var monster: MonsterDefinition = MonsterCatalog.get_monster(monster_id)
		if monster.battle_bond == null:
			continue
		var companion_id: String = monster.battle_bond.companion_monster_id
		if companion_id.is_empty():
			continue
		assert(MonsterCatalog.has(companion_id))
		assert(not ids.has(companion_id))

	var first: String = ids[0]
	var second: String = ids[1] if ids.size() > 1 else first
	popup.configure("monster", [], 1, true, false, false, {}, [first, second])
	var party_row := popup.get_node("ContentMargin/Content/MonsterParty") as VBoxContainer
	var secondary := popup.get_node("ContentMargin/Content/MonsterParty/SecondaryMonster") as OptionButton
	assert(party_row.visible)
	assert(str(secondary.get_selected_metadata()) == second)
	var saved: Array = []
	popup.monster_configuration_changed.connect(func(_id: String, party: Array[String], _loot: Array[String], _gold: int, _random: bool, _hidden: bool, _quantities: Dictionary) -> void:
		saved.append(party))
	popup.call("_save")
	assert(saved.size() == 1)
	assert(saved[0] == [first, second])
	popup.configure("chest", [], 1)
	assert(not party_row.visible)
	popup.queue_free()
	quit()

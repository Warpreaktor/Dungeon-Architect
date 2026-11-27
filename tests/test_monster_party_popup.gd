extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _choose(popup: ChestContentsPopup, slot_index: int, monster_id: String) -> void:
	var button: MenuButton = popup._monster_slot_buttons[slot_index] as MenuButton
	var menu: PopupMenu = button.get_popup()
	for index in range(menu.item_count):
		if str(menu.get_item_metadata(index)) == monster_id:
			menu.id_pressed.emit(menu.get_item_id(index))
			return
	assert(false, "Monster option missing: " + monster_id)


func _run() -> void:
	var popup: ChestContentsPopup = load("res://scenes/chest_contents_popup.tscn").instantiate()
	root.add_child(popup)
	await process_frame
	var saved: Array = []
	popup.monster_configuration_changed.connect(func(_id: String, party: Array[String], loot: Array[String], _gold: int, _random: bool, _hidden: bool, quantities: Dictionary, _reward_level: int) -> void:
		saved.append({"party": party, "loot": loot, "quantities": quantities}))
	popup.configure("monster", ["gold"], 17, true, false, true, {"gold": 17}, ["skeleton", "hunter"])
	assert(popup._monster_party.visible)
	assert(popup._monster_slot_buttons.size() == 4)
	assert(popup._monster_slot_buttons[0].disabled)
	assert(popup._monster_slot_buttons[0].icon == MonsterCatalog.get_monster("skeleton").icon)
	assert(popup._monster_slot_buttons[1].icon == MonsterCatalog.get_monster("hunter").icon)
	for index in range(1, 4):
		var button: MenuButton = popup._monster_slot_buttons[index] as MenuButton
		assert(not button.disabled)
		var menu: PopupMenu = button.get_popup()
		for item_index in range(1, menu.item_count):
			var monster_id: String = str(menu.get_item_metadata(item_index))
			assert(MonsterCatalog.has(monster_id))
			assert(not MonsterCatalog.is_bond_companion(monster_id))
			assert(not MonsterCatalog.is_exclusive_encounter(MonsterCatalog.get_monster(monster_id)))
			assert(menu.get_item_icon(item_index) == MonsterCatalog.get_monster(monster_id).icon)
	_choose(popup, 2, "skeleton")
	_choose(popup, 3, "lobar")
	assert(popup._selected_monster_party() == ["skeleton", "hunter", "skeleton", "lobar"])
	_choose(popup, 1, "")
	assert(popup._monster_slot_buttons[1].icon == null)
	assert(popup._selected_monster_party() == ["skeleton", "skeleton", "lobar"])
	_choose(popup, 1, "hunter")
	assert(saved.is_empty())
	popup._save()
	assert(saved.size() == 1)
	assert(saved[0]["party"] == ["skeleton", "hunter", "skeleton", "lobar"])
	assert(saved[0]["loot"] == ["gold"] and saved[0]["quantities"] == {"gold": 17})
	popup.configure("monster", [], 1, true, false, false, {}, ["skeleton"])
	_choose(popup, 3, "hunter")
	popup.get_node("%CancelButton").pressed.emit()
	assert(saved.size() == 1)
	popup.configure("monster", [], 1, true, false, false, {}, ["skeleton"])
	assert(popup._selected_monster_party() == ["skeleton"])
	for monster_id in MonsterCatalog.list_placeable_ids():
		if not MonsterCatalog.is_exclusive_encounter(MonsterCatalog.get_monster(monster_id)):
			continue
		popup.configure("boss", [], 1, true, true, false, {}, [monster_id])
		for index in range(1, 4):
			assert(popup._monster_slot_buttons[index].disabled)
			assert(popup._monster_slot_buttons[index].icon == null)
			_choose(popup, index, "skeleton")
		assert(popup._selected_monster_party() == [monster_id])
	popup.configure("chest", [], 1)
	assert(not popup._monster_party.visible)
	assert(popup._loot_preview.visible and popup._loot_preview.text.contains("Золото"))
	popup.configure("chest", [], 1, false, true, false, {}, [], {"type": "chest", "properties": {"loot_profile_id": "weapon_rack", "loot_level": 2}})
	assert(popup.reward_level() == 2)
	assert(popup._loot_preview.text.contains("Оружие") and not popup._loot_preview.text.contains("Золото"))
	popup.configure_exit({"id": "exit", "type": "stairs_down", "properties": {"loot_mode": "random", "loot_level": 3}})
	assert(popup.reward_level() == 3 and popup._random_check.button_pressed)
	assert(not popup._hidden_check.visible and popup._loot_preview.visible)
	popup.queue_free()
	await process_frame
	await _test_editor_history()
	print("Monster party popup: four icon slots, exclusive bosses, JSON, history and autosave OK")
	quit()


func _test_editor_history() -> void:
	var storage = load("res://tests/editor_test_storage.gd").new()
	var editor: Node = load("res://scenes/editor.tscn").instantiate()
	storage.configure(editor)
	root.add_child(editor)
	await process_frame
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("monster", 3, 2, {"monster_id": "skeleton"}))
	var entity: Dictionary = dungeon.entities_at(3, 2)[0]
	var entity_id: String = str(entity["id"])
	assert(dungeon.set_monster_loot(entity_id, ["gold"], 17, false, true, {"gold": 17}))
	editor.call("_set_map", dungeon)
	await process_frame
	var before: Dictionary = dungeon.to_dict().duplicate(true)
	var path: String = storage.directory.path_join(dungeon.map_id + ".json")
	editor.call("_on_monster_tapped", entity_id)
	var popup: ChestContentsPopup = editor.get("_monster_loot_popup")
	_choose(popup, 1, "hunter")
	_choose(popup, 2, "skeleton")
	_choose(popup, 3, "lobar")
	assert(dungeon.to_dict() == before and editor.get("_undo_stack").is_empty())
	popup._reward_level.select(2)
	popup.get_node("%CancelButton").pressed.emit()
	assert(dungeon.to_dict() == before and editor.get("_undo_stack").is_empty())
	editor.call("_on_monster_tapped", entity_id)
	assert(popup._selected_monster_party() == ["skeleton"])
	assert(popup.reward_level() == 1)
	popup._reward_level.select(2)
	_choose(popup, 1, "hunter")
	_choose(popup, 2, "skeleton")
	_choose(popup, 3, "lobar")
	popup.get_node("%SaveButton").pressed.emit()
	var after: Dictionary = dungeon.to_dict().duplicate(true)
	assert(DungeonMap.loot_level(dungeon.entities_at(3, 2)[0]) == 3)
	assert(DungeonMap.monster_party_ids(dungeon.entities_at(3, 2)[0]) == ["skeleton", "hunter", "skeleton", "lobar"])
	assert(dungeon.entities_at(3, 2).size() == 1)
	assert(DungeonMap.monster_item_quantities(dungeon.entities_at(3, 2)[0]) == {"gold": 17})
	assert(DungeonMap.is_entity_hidden(dungeon.entities_at(3, 2)[0]))
	assert(editor.get("_undo_stack").size() == 1)
	_assert_saved(editor, path, after)
	editor.call("_on_monster_tapped", entity_id)
	assert(popup._selected_monster_party() == ["skeleton", "hunter", "skeleton", "lobar"])
	assert(popup.reward_level() == 3)
	popup.get_node("%SaveButton").pressed.emit()
	assert(editor.get("_undo_stack").size() == 1)
	editor.call("_undo_edit")
	assert(dungeon.to_dict() == before and editor.get("_redo_stack").size() == 1)
	_assert_saved(editor, path, before)
	editor.call("_redo_edit")
	assert(dungeon.to_dict() == after and editor.get("_undo_stack").size() == 1)
	_assert_saved(editor, path, after)
	var reloaded: DungeonMap = DungeonMap.from_dict(JSON.parse_string(FileAccess.get_file_as_string(path)))
	assert(reloaded != null and DungeonMap.monster_party_ids(reloaded.entities_at(3, 2)[0]) == ["skeleton", "hunter", "skeleton", "lobar"])
	assert(DungeonMap.monster_item_quantities(reloaded.entities_at(3, 2)[0]) == {"gold": 17})
	assert(DungeonMap.loot_level(reloaded.entities_at(3, 2)[0]) == 3)
	editor.queue_free()
	await process_frame
	storage.cleanup()


func _assert_saved(editor: Node, path: String, expected: Dictionary) -> void:
	assert(not editor.get("is_dirty"))
	assert(FileAccess.file_exists(path))
	assert(JSON.parse_string(FileAccess.get_file_as_string(path)) == JSON.parse_string(JSON.stringify(expected)))

extends SceneTree

## Компоновка и привязка команд редактора не должны ломать карту и режимы.
func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var editor_scene: PackedScene = load("res://scenes/editor.tscn")
	var editor: Node = editor_scene.instantiate()
	root.add_child(editor)
	await process_frame

	var toolbar := editor.get_node("EditorLayout/EditorHeader/EditorToolbar") as HBoxContainer
	assert(toolbar != null)
	var file_menu := toolbar.get_node("FileMenu") as MenuButton
	var settings_menu := toolbar.get_node("SettingsMenu") as MenuButton
	var layers_menu := toolbar.get_node("LayersMenu") as MenuButton
	var issues_button := toolbar.get_node("IssuesToggle") as Button
	assert(file_menu != null and settings_menu != null and layers_menu != null)
	assert(issues_button != null and not issues_button.visible)
	assert(settings_menu.get_index() == file_menu.get_index() + 1)
	assert(settings_menu.get_popup().get_item_index(1) >= 0)
	var brand := toolbar.get_node("EditorBrand") as Label
	assert(brand != null)
	assert(brand.autowrap_mode == TextServer.AUTOWRAP_OFF)
	assert(brand.tooltip_text == "DUNGEON / ARCHITECT")
	assert(file_menu.get_popup().get_item_index(2) >= 0) # Новая карта
	assert(file_menu.get_popup().get_item_index(5) >= 0) # Экспорт JSON
	assert(not toolbar.has_node("TestingMenu"))

	var workspace := editor.get_node("EditorLayout/EditorWorkspace") as HBoxContainer
	var palette := workspace.get_node("PalettePanel") as PanelContainer
	var map_view := workspace.get_node("MapViewport") as Control
	assert(palette != null and map_view != null)
	assert(workspace.get_child_count() == 2)
	assert(workspace.get_child(0) == map_view)
	assert(workspace.get_child(1) == palette)
	assert(map_view.get_node("ViewportActions") != null)
	var palette_content := palette.get_node("PaletteScroll/PaletteContent") as VBoxContainer
	assert(palette_content != null)
	assert(palette_content.get_node("ToolsSection/Header") != null)
	assert(palette_content.get_node("MonstersSection/Header") != null)
	var boss_grid := palette_content.get_node("BossesSection/Content/BossesGrid") as GridContainer
	assert(boss_grid != null)
	var expected_bosses: int = 0
	for monster_id in MonsterCatalog.list_placeable_ids():
		if MonsterCatalog.get_monster(monster_id).rank == MonsterDefinition.Rank.BOSS:
			expected_bosses += 1
	assert(boss_grid.get_child_count() == expected_bosses)
	var palette_buttons: Dictionary = editor.get("_palette_buttons")
	assert((palette_buttons["monster:kadavr"] as Button).get_parent() == boss_grid)
	assert((palette_buttons["monster:rabbit_symbiont"] as Button).get_parent() == boss_grid)
	assert(not palette_buttons.has("monster:rabbit_cadaver"))
	assert((palette_buttons["monster:kadavr"] as Button).icon == MonsterCatalog.get_monster("kadavr").icon)
	var bosses_header := palette_content.get_node("BossesSection/Header") as Button
	var bosses_content := palette_content.get_node("BossesSection/Content") as Control
	bosses_header.pressed.emit()
	assert(not bosses_content.visible)
	bosses_header.pressed.emit()
	assert(bosses_content.visible)

	var settings_dialog := editor.get_node("MapSettingsDialog") as AcceptDialog
	var tabs := settings_dialog.get_node("SettingsTabs") as TabContainer
	assert(tabs.get_tab_count() == 2)
	assert(tabs.get_tab_title(1) == "Тестирование")
	var test_hero_select := tabs.get_node("Тестирование/TestProperties/TestHeroSelect") as OptionButton
	assert(test_hero_select != null and test_hero_select.item_count == HeroCatalog.list_ids().size())
	var second_hero_select := tabs.get_node("Тестирование/TestProperties/TestSecondHeroSelect") as OptionButton
	assert(second_hero_select != null and second_hero_select.item_count == HeroCatalog.list_ids().size() + 1)
	var third_hero_select := tabs.get_node("Тестирование/TestProperties/TestThirdHeroSelect") as OptionButton
	assert(third_hero_select != null and third_hero_select.item_count == HeroCatalog.list_ids().size() + 1)
	assert(settings_menu.get_popup().get_item_index(2) >= 0)
	assert(tabs.get_tab_title(0) == "Свойства карты")
	var properties := tabs.get_node("Свойства карты/MapProperties") as VBoxContainer
	assert(properties != null and properties.get_child_count() == 4)
	var name_caption := properties.get_child(0) as Label
	var size_caption := properties.get_child(2) as Label
	var name_row := properties.get_node("MapNameRow") as HBoxContainer
	assert(name_row != null and name_row.get_child_count() == 2)
	var name_input := name_row.get_node("MapName") as LineEdit
	var random_button := name_row.get_node("RandomMapName") as Button
	assert(random_button != null and random_button.icon != null)
	var size_label := properties.get_node("MapSize") as Label
	assert(name_input != null and size_label != null)
	assert(name_caption.text == "Название карты" and size_caption.text == "Размер карты")
	assert(name_caption.autowrap_mode == TextServer.AUTOWRAP_OFF)
	assert(size_caption.autowrap_mode == TextServer.AUTOWRAP_OFF)
	assert(size_label.autowrap_mode == TextServer.AUTOWRAP_OFF)
	assert(name_input.size_flags_vertical == Control.SIZE_SHRINK_BEGIN)
	assert(name_input.custom_minimum_size.y == 44)
	assert(size_label.text.contains("только просмотр"))
	var current_map := editor.get("map_data") as DungeonMap
	assert(name_input.text == current_map.display_name)
	assert(size_label.text.begins_with("%d × %d" % [current_map.width, current_map.height]))
	editor.call("_on_settings_option_selected", 1)
	assert(settings_dialog.visible)
	settings_dialog.hide()
	name_input.text = "Карта из окна настроек"
	name_input.text_changed.emit(name_input.text)
	assert(current_map.display_name == name_input.text)
	assert(bool(editor.get("is_dirty")))
	var old_name := name_input.text
	var old_id: String = current_map.map_id
	random_button.pressed.emit()
	assert(name_input.text != old_name)
	assert(current_map.display_name == name_input.text)
	assert(current_map.map_id == old_id)
	assert(bool(editor.get("is_dirty")))

	var reach_index := layers_menu.get_popup().get_item_index(1)
	var grid_index := layers_menu.get_popup().get_item_index(2)
	assert(not layers_menu.get_popup().is_item_checked(reach_index))
	editor.call("_on_view_option_selected", 1)
	assert(layers_menu.get_popup().is_item_checked(reach_index))
	editor.call("_on_view_option_selected", 1)
	assert(not layers_menu.get_popup().is_item_checked(reach_index))
	assert(layers_menu.get_popup().is_item_checked(grid_index))
	editor.call("_on_view_option_selected", 2)
	assert(not layers_menu.get_popup().is_item_checked(grid_index))

	var issues_dialog := editor.get_node("IssuesDialog") as PopupPanel
	editor.call("_on_view_option_selected", 1)
	assert(issues_button.visible)
	editor.call("_open_issues_dialog")
	assert(issues_dialog.visible)
	editor.call("_on_view_option_selected", 1)
	assert(not issues_button.visible and not issues_dialog.visible)

	var canvas: DungeonCanvas = editor.get("_canvas") as DungeonCanvas
	assert(canvas != null)
	for monster_id in MonsterCatalog.list_ids():
		assert(canvas._monster_icons[monster_id] == MonsterCatalog.get_monster(monster_id).icon)
	for legacy_id in MonsterCatalog.LEGACY_IDS:
		assert(canvas._monster_icons[legacy_id] == MonsterCatalog.get_monster(legacy_id).icon)
	for trap_id in TrapCatalog.list_ids():
		var trap: TrapDefinition = TrapCatalog.get_trap(trap_id)
		assert(canvas._trap_icons[trap_id] == trap.icon)
		assert(canvas._door_trap_icons.has(trap_id) == trap.can_attach_to("door"))
	var snapshot: Dictionary = canvas.capture_edit_state()
	var edit_cell := Vector2i(1, 1)
	var original_entities: Array = current_map.entities_at(edit_cell.x, edit_cell.y).duplicate(true)
	current_map.set_terrain(edit_cell.x, edit_cell.y, "wall")
	assert(current_map.set_terrain(edit_cell.x, edit_cell.y, "floor"))
	assert(current_map.place_entity("trigger", edit_cell.x, edit_cell.y))
	var changed: Dictionary = canvas.capture_edit_state()
	assert(current_map.entities_at(edit_cell.x, edit_cell.y).size() == 1)
	canvas.restore_edit_state(snapshot)
	assert(current_map.entities_at(edit_cell.x, edit_cell.y) == original_entities)
	canvas.restore_edit_state(changed)
	assert(current_map.entities_at(edit_cell.x, edit_cell.y).size() == 1)
	editor.queue_free()
	print("Editor UI: map settings dialog, compact panels and diagnostics OK")
	quit()

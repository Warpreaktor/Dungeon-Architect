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
	var layers_menu := toolbar.get_node("LayersMenu") as MenuButton
	var testing_menu := toolbar.get_node("TestingMenu") as MenuButton
	assert(file_menu != null and layers_menu != null and testing_menu != null)
	assert(file_menu.get_popup().get_item_index(2) >= 0) # Новая карта
	assert(file_menu.get_popup().get_item_index(5) >= 0) # Экспорт JSON
	assert(testing_menu.get_popup().get_item_index(1) >= 0) # Открытая карта

	var workspace := editor.get_node("EditorLayout/EditorWorkspace") as HBoxContainer
	var palette := workspace.get_node("PalettePanel") as PanelContainer
	var inspector := workspace.get_node("InspectorPanel") as PanelContainer
	var map_view := workspace.get_node("MapViewport") as Control
	assert(palette != null and inspector != null and map_view != null)
	assert(workspace.get_child(0) == palette)
	assert(workspace.get_child(1) == map_view)
	assert(workspace.get_child(2) == inspector)
	assert(map_view.get_node("ViewportActions") != null)

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

	var before := inspector.visible
	editor.call("_toggle_inspector_panel")
	assert(inspector.visible != before)
	editor.call("_toggle_inspector_panel")
	assert(inspector.visible == before)

	editor.queue_free()
	print("Editor UI: menus, panels, overlays OK")
	quit()

extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/game_system_menu.tscn")
	var menu: GameSystemMenu = scene.instantiate() as GameSystemMenu
	root.add_child(menu)
	var settings_button: Button = menu.get_node("Center/Card/Margins/Content/TestSettingsButton") as Button
	var leave_button: Button = menu.get_node("Center/Card/Margins/Content/LeaveButton") as Button
	var popup: PopupPanel = menu.get_node("SettingsPopup") as PopupPanel
	var changes: Array[bool] = []
	var console_changes: Array[bool] = []
	menu.test_open_map_changed.connect(func(enabled: bool) -> void: changes.append(enabled))
	menu.console_changed.connect(func(enabled: bool) -> void: console_changes.append(enabled))

	menu.open_for(false, true, false)
	assert(settings_button.visible)
	assert(leave_button.text == "Выйти в редактор")
	assert(not popup.visible)
	assert(menu._open_map_button.button_pressed)
	assert(not menu._console_button.button_pressed)
	settings_button.pressed.emit()
	assert(popup.visible)
	menu._open_map_button.set_pressed(false)
	menu._console_button.set_pressed(true)
	assert(changes == [false])
	assert(console_changes == [true])
	menu.dismiss()
	assert(not popup.visible)

	menu.open_for(false, false, true)
	assert(not popup.visible)
	assert(not menu._open_map_button.button_pressed)
	assert(menu._console_button.button_pressed)
	menu.dismiss()
	menu.open_for(true)
	assert(settings_button.visible)
	assert(leave_button.text == "Главное меню")
	menu.queue_free()
	print("Game menu: separate settings and live options OK")
	quit()

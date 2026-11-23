extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var editor: Node = load("res://scenes/editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	var map: DungeonMap = DungeonMap.create_blank(7, 7)
	assert(map.place_entity("player_spawn", 1, 2))
	assert(map.place_entity("monster", 2, 2))
	editor.call("_set_map", map)
	editor.call("_start_play_mode")
	var session: GameSession = editor.get("game_session") as GameSession
	assert(session != null)
	assert(not session.move_by(1, 0))
	assert(session.has_pending_encounter())
	editor.call("_start_combat")
	await create_timer(0.5).timeout
	var battle: BattleView = editor.get("_battle_view") as BattleView
	assert(battle != null)
	var menu_button: Button = battle.get_node("BattleMenuButton") as Button
	assert(menu_button.visible and menu_button.text.is_empty())
	assert(menu_button.icon == load("res://assets/hud/menu.png"))
	assert(menu_button.custom_minimum_size == Vector2(44, 44))
	var menu: GameSystemMenu = editor.get("_game_system_menu") as GameSystemMenu
	menu_button.pressed.emit()
	assert(menu.visible)
	assert((menu.get_node("Center/Card/Margins/Content/LeaveButton") as Button).text == "Выйти в редактор")
	editor.call("_close_game_system_menu")
	assert(not menu.visible)
	assert(editor.get("_combat_active"))
	menu_button.pressed.emit()
	assert(menu.visible)
	editor.call("_leave_from_game_system_menu")
	assert(not editor.get("is_play_mode"))
	assert(not editor.get("_combat_active"))
	assert(editor.get("_battle_view") == null)
	assert(editor.get("game_session") == null)
	assert(editor.get("map_data") == map)
	assert(not menu.visible)
	editor.queue_free()
	print("Editor battle menu: return to editor during combat OK")
	quit()

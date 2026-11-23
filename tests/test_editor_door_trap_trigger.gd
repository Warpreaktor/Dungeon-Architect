extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var editor: Node = load("res://scenes/editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	var map := DungeonMap.create_blank(7, 7)
	assert(map.place_entity("player_spawn", 1, 2))
	assert(map.place_entity("door", 2, 2))
	var door: Dictionary = map.entities_at(2, 2)[0]
	assert(map.attach_door_trap(str(door["id"]), "door_crossbow"))
	assert(map.set_message_at(2, 2, "Дверь открыта!"))
	editor.call("_set_map", map)
	editor.call("_start_play_mode")
	var session: GameSession = editor.get("game_session") as GameSession
	assert(session != null)
	session._receive_item("key", 1)
	var original_hp: int = session.hero.health
	editor.call("_try_move_player", 1, 0)
	var dialogue: GameDialogueView = editor.get("_game_dialogue") as GameDialogueView
	assert(dialogue.visible)
	assert(editor.get("_active_game_message")["activation"] == "door_trap")
	assert(session.player_pos == Vector2i(1, 2))
	assert(session.hero.health == original_hp)
	assert(not session.is_entity_removed(door))
	assert(int(session.carried_items["key"]) == 1)
	editor.call("_try_move_player", 1, 0)
	assert(session.hero.health == original_hp)
	dialogue.dismiss_by_player()
	await create_timer(0.6).timeout
	assert(session.hero.health == original_hp - TrapCatalog.get_trap("door_crossbow").direct_damage)
	assert(session.player_pos == Vector2i(2, 2))
	assert(session.is_entity_removed(door))
	assert(session.is_trap_disarmed(door))
	assert(dialogue.visible)
	assert(editor.get("_active_game_message")["activation"] == "door_open")
	assert(editor.get("_active_game_message")["text"] == "Дверь открыта!")
	dialogue.dismiss_by_player()
	assert(not dialogue.visible)
	editor.queue_free()
	print("Editor door trap: trap dialog, shot, door and authored dialog OK")
	quit()

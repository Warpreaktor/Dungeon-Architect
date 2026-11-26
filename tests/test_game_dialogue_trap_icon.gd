extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var view: GameDialogueView = load("res://scenes/game_dialogue_view.tscn").instantiate()
	root.add_child(view)
	await process_frame
	view.show_event({
		"text": "Стоило тебе открыть дверь, как скрытый арбалет выпустил болт прямо в тебя!",
		"icon_type": "trap",
		"icon_id": "door_crossbow",
		"loot": []
	})
	var holder: CenterContainer = view.get_node("Center/Card/Margins/Content/EventIconHolder") as CenterContainer
	var icon: TextureRect = view.get_node("Center/Card/Margins/Content/EventIconHolder/EventIconPanel/EventIconMargin/EventIcon") as TextureRect
	assert(holder.visible)
	assert(icon.texture == TrapCatalog.get_trap("door_crossbow").icon)
	view.dismiss()
	view.show_event({"text": "Обычное послание"})
	assert(not holder.visible)
	var dungeon := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("chest", 3, 2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 611
	var session: GameSession = GameSession.start_for(dungeon, "volcha", false, rng)
	assert(session.move_by(1, 0))
	var event: Dictionary = session.take_message_events()[0]
	assert(event["loot"][0]["instances"].size() == 1)
	var original_event: Dictionary = event.duplicate(true)
	var before: Dictionary = session.party_state_snapshot()
	for index in range(3):
		view.show_event(event)
		assert(view._loot_rows.get_child_count() == event["loot"].size())
		view.dismiss()
	assert(event == original_event)
	assert(session.party_state_snapshot() == before)
	view.queue_free()
	print("Game dialogue trap icon: event icon is visible only for trap messages")
	quit()

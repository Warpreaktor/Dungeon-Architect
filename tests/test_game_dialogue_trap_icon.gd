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
	view.queue_free()
	print("Game dialogue trap icon: event icon is visible only for trap messages")
	quit()

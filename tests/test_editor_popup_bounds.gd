extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous_size: Vector2i = root.size
	root.size = Vector2i(800, 520)
	var monster_popup: ChestContentsPopup = load("res://scenes/chest_contents_popup.tscn").instantiate()
	root.add_child(monster_popup)
	await process_frame
	var monster_ids: Array[String] = [MonsterCatalog.DEFAULT_MONSTER_ID]
	var loot: Array[String] = []
	monster_popup.configure("monster", loot, 0, true, false, false, {}, monster_ids)
	var selector: OptionButton = monster_popup.get_node("ContentMargin/Content/MonsterParty/SecondaryMonster")
	assert(selector.get_theme_constant("icon_max_width") == 32)
	assert(selector.get_popup().get_theme_constant("icon_max_width") == 32)
	assert(selector.item_count > 1)
	selector.select(1)
	await process_frame
	assert(selector.get_combined_minimum_size().y <= 70)
	monster_popup.popup_centered_clamped(Vector2i(470, 630), 0.9)
	await process_frame
	var loot_scroll: ScrollContainer = monster_popup.get_node("ContentMargin/Content/LootScroll")
	assert(loot_scroll.custom_minimum_size.y == 0)
	assert((loot_scroll.size_flags_vertical & Control.SIZE_EXPAND) != 0)
	assert(monster_popup.size.y <= root.size.y)
	var buttons: HBoxContainer = monster_popup.get_node("ContentMargin/Content/Buttons")
	assert(buttons.position.y + buttons.size.y <= monster_popup.size.y)
	monster_popup.hide()
	monster_popup.queue_free()

	var door_popup: DoorPropertiesPopup = load("res://scenes/door_properties_popup.tscn").instantiate()
	root.add_child(door_popup)
	await process_frame
	door_popup.configure("door", "key", "door_crossbow")
	door_popup.popup_centered_clamped(Vector2i(510, 460), 0.9)
	await process_frame
	assert(door_popup.size.y <= root.size.y)
	var door_content: VBoxContainer = door_popup.get_child(0).get_child(0)
	assert(door_content.get_child(0) is ScrollContainer)
	assert(door_content.get_child(1) is HBoxContainer)
	door_popup.hide()
	door_popup.queue_free()

	var message_popup: MessageEditorPopup = load("res://scenes/message_editor_popup.tscn").instantiate()
	root.add_child(message_popup)
	await process_frame
	message_popup.configure(Vector2i(1, 1), "Сообщение", "monster")
	message_popup.popup_centered_clamped(Vector2i(540, 390), 0.9)
	await process_frame
	assert(message_popup.size.y <= root.size.y)
	assert(message_popup.get_node("Margins/Body/MessageInput").custom_minimum_size.y == 0)
	message_popup.hide()
	message_popup.queue_free()
	root.size = previous_size
	print("Editor popups: scrollable content and accessible actions OK")
	quit()

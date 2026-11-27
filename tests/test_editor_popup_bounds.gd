extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous_size: Vector2i = root.size
	root.size = Vector2i(800, 520)
	var monster_popup: ChestContentsPopup = load("res://scenes/chest_contents_popup.tscn").instantiate()
	root.add_child(monster_popup)
	var monster_ids: Array[String] = ["skeleton", "hunter", "lobar", "skeleton"]
	var loot: Array[String] = []
	monster_popup.configure("monster", loot, 0, true, true, false, {}, monster_ids)
	assert(monster_popup._monster_slot_buttons.size() == 4)
	for index in range(1, 4):
		var selector: MenuButton = monster_popup._monster_slot_buttons[index] as MenuButton
		assert(selector.get_theme_constant("icon_max_width") == 44)
		assert(selector.get_popup().get_theme_constant("icon_max_width") == 32)
		assert(selector.get_popup().item_count > 1)
		assert(selector.get_combined_minimum_size().y <= 70)
	monster_popup.popup_centered_clamped(Vector2i(470, 630), 0.9)
	await process_frame
	await process_frame
	await process_frame
	var loot_scroll: ScrollContainer = monster_popup.get_node("ContentMargin/Content/LootScroll")
	assert(loot_scroll.custom_minimum_size.y == 0)
	assert((loot_scroll.size_flags_vertical & Control.SIZE_EXPAND) != 0)
	_assert_popup_bounds(monster_popup)
	var slots: HBoxContainer = monster_popup._monster_slots
	for button in monster_popup._monster_slot_buttons:
		assert(button.position.x + button.size.x <= slots.size.x + 1.0)
	assert(loot_scroll.is_ancestor_of(monster_popup._monster_party))
	assert(loot_scroll.is_ancestor_of(monster_popup._loot_preview))
	assert(loot_scroll.is_ancestor_of(monster_popup._rows))
	assert(loot_scroll.get_v_scroll_bar().max_value > loot_scroll.get_v_scroll_bar().page)
	monster_popup._toggle_group("Оружие")
	await process_frame
	await process_frame
	_assert_popup_bounds(monster_popup)
	loot_scroll.scroll_vertical = int(loot_scroll.get_v_scroll_bar().max_value)
	monster_popup.hide()
	monster_popup.configure("monster", loot, 0, true, true, false, {}, monster_ids)
	monster_popup.popup_centered_clamped(Vector2i(470, 630), 0.9)
	await process_frame
	await process_frame
	_assert_popup_bounds(monster_popup)
	assert(loot_scroll.scroll_vertical == 0)
	monster_popup.hide()
	monster_popup.configure("chest", loot, 0)
	monster_popup.popup_centered_clamped(Vector2i(470, 530), 0.9)
	await process_frame
	await process_frame
	_assert_popup_bounds(monster_popup)
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

	var trap_popup := TrapPropertiesPopup.new()
	root.add_child(trap_popup)
	await process_frame
	trap_popup.configure({"id": "trap", "type": "trap", "properties": {"trap_id": "spikes"}})
	trap_popup.popup_centered_clamped(Vector2i(400, 200), 0.9)
	await process_frame
	assert(trap_popup.size.y <= root.size.y)
	var trap_content: VBoxContainer = trap_popup.get_child(0).get_child(0)
	assert(trap_content.get_child(0) is ScrollContainer)
	var trap_actions: HBoxContainer = trap_content.get_child(1)
	assert(trap_actions.position.y + trap_actions.size.y <= trap_popup.size.y)
	trap_popup.hide()
	trap_popup.queue_free()

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


func _assert_popup_bounds(popup: ChestContentsPopup) -> void:
	var viewport_bounds := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	assert(viewport_bounds.grow(1.0).encloses(Rect2(Vector2(popup.position), Vector2(popup.size))))
	var popup_bounds := Rect2(Vector2.ZERO, Vector2(popup.size))
	for button_name in ["%SaveButton", "%CancelButton"]:
		var button: Button = popup.get_node(button_name)
		assert(popup_bounds.grow(1.0).encloses(button.get_global_rect()))
		assert(not popup._scroll.is_ancestor_of(button))

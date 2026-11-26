extends SceneTree


func _initialize() -> void:
	call_deferred("_verify")


func _settle() -> void:
	for index in range(4):
		await process_frame


func _mouse(picker: HeroSelection, point: Vector2, pressed: bool, double_click: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = pressed
	event.double_click = double_click
	picker._input(event)


func _touch(picker: HeroSelection, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	picker._input(event)


func _drag(picker: HeroSelection, point: Vector2, touch: bool) -> void:
	if touch:
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = point
		picker._input(event)
	else:
		var event := InputEventMouseMotion.new()
		event.position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		picker._input(event)


func _point(picker: HeroSelection, id: String) -> Vector2:
	return (picker._catalog.tiles[id] as HeroCatalogTile).get_global_rect().get_center()


func _wait_flight(picker: HeroSelection) -> void:
	await create_timer(0.35).timeout
	await _settle()
	assert(picker._drag_layer.card == null and picker._transfer_id.is_empty())


func _test_gestures(picker: HeroSelection, definitions: Array[HeroDefinition]) -> void:
	var small: Array[HeroDefinition] = []
	for index in range(GameSession.MAX_PARTY_SIZE):
		small.append(definitions[index])
	picker.set_heroes(small)
	await _settle()
	assert(picker._preview.get_node_or_null("Content/Toggle") == null)
	var first: String = small[0].hero_id
	var point: Vector2 = _point(picker, first)
	_mouse(picker, point, true)
	_mouse(picker, point, false)
	assert(picker.selected_party().is_empty() and picker._focused_id == first)
	_mouse(picker, point, true, true)
	_mouse(picker, point, false)
	assert(picker.selected_party() == [first])
	assert(not picker._catalog.tiles[first].visible)
	assert(picker._drag_layer.card != null and picker._party_bar._contents[0].modulate.a == 0.0)
	picker._catalog.hero_add_requested.emit(first)
	assert(picker.selected_party() == [first])
	await _wait_flight(picker)
	assert(picker._party_bar._contents[0].modulate.a == 1.0)

	var second: String = small[1].hero_id
	point = _point(picker, second)
	var target: Vector2 = picker._party_bar.target_rect(1).get_center()
	_mouse(picker, point, true)
	_drag(picker, target, false)
	assert(picker._gesture == HeroSelection.Gesture.DRAG and picker._drag_layer.card != null)
	assert(not picker._catalog.tiles[second].visible and picker.selected_party() == [first])
	assert(picker._party_bar._highlights[1].visible)
	var flying_card: Control = picker._drag_layer.card
	_mouse(picker, target, false)
	assert(picker.selected_party() == [first, second] and picker._drag_layer.card == flying_card)
	assert(picker._party_bar._contents[1].modulate.a == 0.0)
	await _wait_flight(picker)
	assert(picker._party_bar._contents[1].modulate.a == 1.0)

	var third: String = small[2].hero_id
	point = _point(picker, third)
	target = picker._party_bar.target_rect(2).get_center()
	_touch(picker, point, true)
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.position = point
	emulated.pressed = true
	picker._input(emulated)
	_drag(picker, target, true)
	assert(picker._gesture == HeroSelection.Gesture.DRAG)
	_touch(picker, target, false, true)
	emulated.pressed = false
	emulated.position = target
	picker._input(emulated)
	assert(picker.selected_party() == [first, second] and picker._gesture == HeroSelection.Gesture.NONE)
	assert(picker._catalog.tiles[third].visible and picker._catalog.tiles[third].modulate.a == 0.0)
	await _wait_flight(picker)
	assert(picker._catalog.tiles[third].modulate.a == 1.0)
	point = _point(picker, third)
	_touch(picker, point, true)
	_drag(picker, target, true)
	_touch(picker, target, false)
	assert(picker.selected_party() == [first, second, third])
	await _wait_flight(picker)

	var fourth: String = small[3].hero_id
	point = _point(picker, fourth)
	_touch(picker, point, true)
	_drag(picker, Vector2(2, 2), true)
	_touch(picker, Vector2(2, 2), false)
	assert(picker.selected_party() == [first, second, third])
	await _wait_flight(picker)
	point = _point(picker, fourth)
	_touch(picker, point, true)
	_drag(picker, picker._party_bar.target_rect(3).get_center(), true)
	_touch(picker, picker._party_bar.target_rect(3).get_center(), false)
	assert(picker.selected_party() == [first, second, third, fourth])
	assert(not picker._party_bar.accepts_drop(target))
	await _wait_flight(picker)

	point = picker._party_bar.target_rect(1).get_center()
	target = picker._party_bar.target_rect(0).get_center()
	_mouse(picker, point, true)
	_drag(picker, target, false)
	assert(picker._party_bar._contents[1].modulate.a == 0.0)
	_mouse(picker, target, false)
	assert(picker.selected_party() == [second, first, third, fourth])
	await _wait_flight(picker)
	point = picker._party_bar.target_rect(0).get_center()
	target = picker._catalog.scroll.get_global_rect().get_center()
	_touch(picker, point, true)
	_drag(picker, target, true)
	_touch(picker, target, false, true)
	assert(picker.selected_party() == [second, first, third, fourth])
	await _wait_flight(picker)
	assert(picker._party_bar._contents[0].modulate.a == 1.0)
	_mouse(picker, point, true)
	_drag(picker, target, false)
	_mouse(picker, target, false)
	assert(picker.selected_party() == [first, third, fourth])
	assert(picker._catalog.tiles[second].visible and picker._catalog.tiles[second].modulate.a == 0.0)
	await _wait_flight(picker)
	assert(picker._catalog.tiles[second].modulate.a == 1.0)
	picker._party_bar._remove_buttons[0].pressed.emit()
	assert(picker.selected_party() == [third, fourth])
	assert(picker._catalog.tiles[first].visible and picker._catalog.tiles[first].modulate.a == 0.0)
	picker.hide()
	assert(picker._drag_layer.card == null and picker._catalog.tiles[first].modulate.a == 1.0)
	picker.show()

	picker.set_heroes(definitions)
	root.size = Vector2i(900, 540)
	await _settle()
	point = _point(picker, first)
	assert(picker._catalog.scroll.get_v_scroll_bar().max_value > picker._catalog.scroll.get_v_scroll_bar().page)
	_touch(picker, point, true)
	picker._started_at = Time.get_ticks_msec()
	_drag(picker, point - Vector2(0, 60), true)
	assert(picker._gesture == HeroSelection.Gesture.SCROLL)
	_touch(picker, point - Vector2(0, 60), false)
	assert(picker.selected_party().is_empty() and picker._catalog.scroll.scroll_vertical > 0)
	picker._catalog.scroll.scroll_vertical = 0
	await _settle()
	point = _point(picker, first)
	target = picker._party_bar.target_rect(0).get_center()
	_touch(picker, point, true)
	picker._started_at -= HeroSelection.TOUCH_HOLD_MS
	_drag(picker, target, true)
	assert(picker._gesture == HeroSelection.Gesture.DRAG)
	_touch(picker, target, false)
	assert(picker.selected_party() == [first])
	picker.reset_selection()
	root.size = Vector2i(480, 540)
	await _settle()
	assert(picker._separate_page and picker._catalog.visible)
	point = _point(picker, first)
	_touch(picker, point, true)
	_touch(picker, point, false)
	assert(picker.selected_party().is_empty() and picker._catalog.visible)
	_touch(picker, point, true)
	_touch(picker, point, false)
	assert(picker.selected_party() == [first] and picker._catalog.visible)
	root.size = Vector2i(1280, 800)
	picker.reset_selection()
	await _settle()


func _verify() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 800)
	var picker: HeroSelection = load("res://scenes/hero_selection.tscn").instantiate() as HeroSelection
	root.add_child(picker)
	picker.show()
	assert(picker._catalog.tiles.size() == HeroCatalog.list_ids().size())
	var definitions: Array[HeroDefinition] = []
	for hero_id in HeroCatalog.list_ids():
		definitions.append(HeroCatalog.get_hero(hero_id))
	assert(definitions.size() > 0)
	while definitions.size() < 25:
		var hero := definitions[0].duplicate() as HeroDefinition
		hero.hero_id = "catalog_hero_%02d" % definitions.size()
		hero.display_name = "Персонаж %02d" % definitions.size()
		definitions.append(hero)
	await _test_gestures(picker, definitions)
	picker.set_heroes(definitions)
	await _settle()
	assert(picker._catalog.tiles.size() == definitions.size())
	assert(picker._catalog.count.text == "Герои: %d из %d" % [definitions.size(), definitions.size()])
	assert(picker._catalog.grid.columns >= 4)
	for tile in picker._catalog.tiles.values():
		assert(tile.size.x <= HeroCatalogGrid.TILE_MAX + 1.0)
	assert(picker._catalog.visible and picker._preview.visible)
	assert(picker._party_bar.portraits.size() == GameSession.MAX_PARTY_SIZE)
	assert(picker.selected_party().is_empty() and picker._start_button.disabled)
	var original: Array[String] = []
	for index in range(GameSession.MAX_PARTY_SIZE):
		var id: String = definitions[index].hero_id
		picker._catalog.tiles[id].pressed.emit()
		assert(picker._preview.hero_name.text == definitions[index].display_name)
		assert(picker.selected_party() == original)
		picker._catalog.hero_add_requested.emit(id)
		original.append(id)
		assert(picker.selected_party() == original)
		assert(picker._party_bar.portraits[index].texture == definitions[index].portrait)
		assert(not picker._catalog.tiles[id].visible)
		await _wait_flight(picker)
	assert(not picker._start_button.disabled)
	var extra: HeroDefinition = definitions[GameSession.MAX_PARTY_SIZE]
	picker._catalog.tiles[extra.hero_id].pressed.emit()
	assert(picker._preview.hero_name.text == extra.display_name)
	assert(not picker._can_add_hero(extra.hero_id))
	picker._catalog.hero_add_requested.emit(extra.hero_id)
	assert(picker.selected_party() == original)
	picker._catalog.search.text = extra.display_name.to_upper()
	picker._catalog.search.text_changed.emit(picker._catalog.search.text)
	assert(picker._catalog.tiles[extra.hero_id].visible)
	assert(not picker._catalog.tiles[original[0]].visible)
	assert(picker.selected_party() == original)
	picker._party_bar._remove_buttons[0].pressed.emit()
	original.pop_front()
	assert(picker.selected_party() == original)
	assert(picker._can_add_hero(extra.hero_id))
	picker._catalog.hero_add_requested.emit(extra.hero_id)
	original.append(extra.hero_id)
	assert(picker.selected_party() == original)
	var emitted: Array = []
	picker.party_chosen.connect(func(ids: Array[String]) -> void: emitted.append(ids.duplicate()))
	picker._start_button.pressed.emit()
	assert(emitted == [original])
	picker._catalog.reset_filter()
	for window_size in [Vector2i(1280, 800), Vector2i(900, 540), Vector2i(600, 900), Vector2i(480, 540)]:
		root.size = window_size
		await _settle()
		assert(picker._party_bar.is_visible_in_tree() and picker._start_button.is_visible_in_tree())
		assert(picker.get_global_rect().encloses(picker._party_bar.get_global_rect()))
		assert(picker.get_global_rect().encloses(picker._start_button.get_global_rect()))
		assert(root.get_visible_rect().encloses(picker._start_button.get_global_rect()))
		assert(picker.selected_party() == original)
		if picker._separate_page:
			picker._show_catalog()
			await _settle()
			assert(picker._catalog.visible and not picker._preview.visible)
			picker._catalog.tiles[definitions[GameSession.MAX_PARTY_SIZE + 1].hero_id].pressed.emit()
			await _settle()
			assert(not picker._catalog.visible and picker._preview.visible)
		else:
			assert(picker._catalog.visible and picker._preview.visible)
			assert(picker._body.vertical == (picker.size.x < 740.0))
	picker.reset_selection()
	assert(picker.selected_party().is_empty() and picker._start_button.disabled)
	assert(picker._catalog.search.text.is_empty())
	picker.hide()
	assert(picker._drag_layer.card == null and picker._transfer_id.is_empty())
	picker.queue_free()
	await process_frame
	print("Hero selection: adaptive catalog, 25 heroes, search, preview and ordered party OK")
	quit()

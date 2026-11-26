extends SceneTree


func _initialize() -> void:
	call_deferred("_verify")


func _settle() -> void:
	for index in range(4):
		await process_frame


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
		picker._preview.toggle_button.pressed.emit()
		original.append(id)
		assert(picker.selected_party() == original)
		assert(picker._party_bar.portraits[index].texture == definitions[index].portrait)
	assert(not picker._start_button.disabled)
	var extra: HeroDefinition = definitions[GameSession.MAX_PARTY_SIZE]
	picker._catalog.tiles[extra.hero_id].pressed.emit()
	assert(picker._preview.hero_name.text == extra.display_name)
	assert(picker._preview.toggle_button.disabled)
	picker._toggle_focused()
	assert(picker.selected_party() == original)
	picker._catalog.search.text = extra.display_name.to_upper()
	picker._catalog.search.text_changed.emit(picker._catalog.search.text)
	assert(picker._catalog.tiles[extra.hero_id].visible)
	assert(not picker._catalog.tiles[original[0]].visible)
	assert(picker.selected_party() == original)
	picker._party_bar._remove_buttons[0].pressed.emit()
	original.pop_front()
	assert(picker.selected_party() == original)
	assert(not picker._preview.toggle_button.disabled)
	picker._preview.toggle_button.pressed.emit()
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
			picker._catalog.tiles[extra.hero_id].pressed.emit()
			await _settle()
			assert(not picker._catalog.visible and picker._preview.visible)
		else:
			assert(picker._catalog.visible and picker._preview.visible)
			assert(picker._body.vertical == (picker.size.x < 740.0))
	picker.reset_selection()
	assert(picker.selected_party().is_empty() and picker._start_button.disabled)
	assert(picker._catalog.search.text.is_empty())
	picker.hide()
	assert(picker._flights.is_empty())
	picker.queue_free()
	await process_frame
	print("Hero selection: adaptive catalog, 25 heroes, search, preview and ordered party OK")
	quit()

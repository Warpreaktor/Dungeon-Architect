class_name EditorTestHeroPanel
extends MarginContainer

signal party_selected(hero_ids: Array[String])

const GOLD := Color("#d8b374")
const GAP := 6
const TILE_TARGET := 68.0
const TILE_MAX := 78.0
const PARTY_SIDE_MAX := 148.0

var _ids: Array[String] = [HeroCatalog.DEFAULT_HERO_ID]
var _hero_ids: Array[String] = []
var _tiles: Dictionary = {}
var _party_buttons: Array[Button] = []
var _party_portraits: Array[TextureRect] = []
var _party_names: Array[Label] = []
var _catalog_toggle: Button
var _catalog_host: Control
var _catalog_grid: GridContainer
var _previous: Button
var _next: Button
var _page_label: Label
var _count: Label
var _party_row: HBoxContainer
var _page := 0
var _page_capacity := 1


func _ready() -> void:
	for margin_side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		add_theme_constant_override(margin_side, 12)
	var content := VBoxContainer.new()
	content.name = "TestProperties"
	content.add_theme_constant_override("separation", 8)
	add_child(content)
	var toolbar := HBoxContainer.new()
	content.add_child(toolbar)
	_catalog_toggle = Button.new()
	_catalog_toggle.text = "Герои  ▾"
	_catalog_toggle.toggle_mode = true
	_catalog_toggle.button_pressed = true
	_catalog_toggle.custom_minimum_size.y = 36
	_catalog_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_toggle.toggled.connect(_set_catalog_open)
	toolbar.add_child(_catalog_toggle)
	_previous = Button.new()
	_previous.text = "‹"
	_previous.custom_minimum_size = Vector2(36, 36)
	_previous.pressed.connect(_change_page.bind(-1))
	toolbar.add_child(_previous)
	_page_label = Label.new()
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.custom_minimum_size.x = 48
	toolbar.add_child(_page_label)
	_next = Button.new()
	_next.text = "›"
	_next.custom_minimum_size = Vector2(36, 36)
	_next.pressed.connect(_change_page.bind(1))
	toolbar.add_child(_next)
	_catalog_host = Control.new()
	_catalog_host.custom_minimum_size.y = TILE_TARGET + 22.0
	_catalog_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_catalog_host.clip_contents = true
	content.add_child(_catalog_host)
	_catalog_grid = GridContainer.new()
	_catalog_grid.name = "HeroMatrix"
	_catalog_grid.add_theme_constant_override("h_separation", GAP)
	_catalog_grid.add_theme_constant_override("v_separation", GAP)
	_catalog_host.add_child(_catalog_grid)
	_catalog_host.resized.connect(_layout_catalog)
	for id in HeroCatalog.list_ids():
		var definition: HeroDefinition = HeroCatalog.get_hero(id)
		if definition == null:
			continue
		_hero_ids.append(id)
		var tile := HeroCatalogTile.new()
		_catalog_grid.add_child(tile)
		tile.configure(definition)
		tile.set_tile_size(TILE_TARGET)
		tile.pressed.connect(_toggle_hero.bind(id))
		tile.add_requested.connect(_toggle_hero)
		_tiles[id] = tile
	content.add_child(HSeparator.new())
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = "Тестовый отряд"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", GOLD)
	header.add_child(title)
	_count = Label.new()
	_count.add_theme_color_override("font_color", GOLD)
	header.add_child(_count)
	_party_row = HBoxContainer.new()
	_party_row.name = "PartySlots"
	_party_row.add_theme_constant_override("separation", GAP)
	content.add_child(_party_row)
	for index in range(GameSession.MAX_PARTY_SIZE):
		_make_party_slot(index)
	_party_row.resized.connect(_layout_party)
	resized.connect(_layout_party)
	_refresh_selection()
	_refresh_page()
	_layout_catalog.call_deferred()
	_layout_party.call_deferred()


func _make_party_slot(index: int) -> void:
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 104
	button.pressed.connect(_party_slot_pressed.bind(index))
	_party_row.add_child(button)
	_party_buttons.append(button)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 5
	content.offset_right = -5
	content.offset_top = 4
	content.offset_bottom = -4
	var number := Label.new()
	number.text = str(index + 1)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.add_theme_color_override("font_color", GOLD)
	content.add_child(number)
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(portrait)
	_party_portraits.append(portrait)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	_party_names.append(label)
	button.set_drag_forwarding(_get_party_drag.bind(index), _can_drop_party.bind(index), _drop_party.bind(index))


func _set_catalog_open(opened: bool) -> void:
	_catalog_toggle.set_pressed_no_signal(opened)
	_catalog_toggle.text = "Герои  ▾" if opened else "Герои  ▸"
	_catalog_host.visible = opened
	_previous.visible = opened
	_next.visible = opened
	_page_label.visible = opened
	if opened:
		_layout_catalog.call_deferred()


func _layout_catalog() -> void:
	if not _catalog_host.visible or _catalog_host.size.x <= 0.0:
		return
	var available: Vector2 = _catalog_host.size
	var columns: int = maxi(1, floori((available.x + GAP) / (TILE_TARGET + GAP)))
	var side: float = clampf(floorf((available.x - GAP * (columns - 1)) / columns), 1.0, TILE_MAX)
	var rows: int = maxi(1, floori((available.y + GAP) / (side + 22.0 + GAP)))
	side = minf(side, maxf(1.0, available.y - 22.0))
	_catalog_grid.columns = columns
	_page_capacity = columns * rows
	for tile in _tiles.values():
		(tile as HeroCatalogTile).set_tile_size(side)
	_refresh_page()


func _refresh_page() -> void:
	var pages: int = maxi(1, ceili(float(_hero_ids.size()) / _page_capacity))
	_page = clampi(_page, 0, pages - 1)
	for index in range(_hero_ids.size()):
		(_tiles[_hero_ids[index]] as HeroCatalogTile).visible = index >= _page * _page_capacity and index < (_page + 1) * _page_capacity
	_page_label.text = "%d / %d" % [_page + 1, pages]
	_previous.disabled = _page == 0
	_next.disabled = _page == pages - 1


func _change_page(delta: int) -> void:
	_page += delta
	_refresh_page()


func _layout_party() -> void:
	var side: float = clampf((_party_row.size.x - GAP * (GameSession.MAX_PARTY_SIZE - 1)) / GameSession.MAX_PARTY_SIZE, 72.0, PARTY_SIDE_MAX)
	side = minf(side, maxf(72.0, size.y * 0.36))
	for button in _party_buttons:
		button.custom_minimum_size.y = side + 26.0


func select_party(hero_ids: Array[String]) -> void:
	_ids.clear()
	for id in hero_ids:
		if HeroCatalog.has(id) and not _ids.has(id) and _ids.size() < GameSession.MAX_PARTY_SIZE:
			_ids.append(id)
	if _ids.is_empty():
		_ids.append(HeroCatalog.DEFAULT_HERO_ID)
	if _count != null:
		_refresh_selection()


func select_hero(hero_id: String) -> void:
	select_party([hero_id])


func selected_party() -> Array[String]:
	return _ids.duplicate()


func _toggle_hero(id: String) -> void:
	if not HeroCatalog.has(id):
		return
	if _ids.has(id):
		if _ids.size() == 1:
			return
		_ids.erase(id)
	elif _ids.size() < GameSession.MAX_PARTY_SIZE:
		_ids.append(id)
	else:
		return
	_commit_selection()


func _party_slot_pressed(index: int) -> void:
	if index >= _ids.size():
		_set_catalog_open(true)


func _refresh_selection() -> void:
	_count.text = "%d / %d" % [_ids.size(), GameSession.MAX_PARTY_SIZE]
	for id in _tiles:
		var tile: HeroCatalogTile = _tiles[id]
		var position: int = _ids.find(id) + 1
		tile.set_selection(false, position)
		tile.disabled = position == 0 and _ids.size() >= GameSession.MAX_PARTY_SIZE
	for index in range(_party_buttons.size()):
		var definition: HeroDefinition = HeroCatalog.get_hero(_ids[index]) if index < _ids.size() else null
		_party_portraits[index].texture = definition.portrait if definition != null else null
		_party_portraits[index].visible = definition != null
		_party_names[index].text = definition.display_name if definition != null else "+"
		_party_names[index].size_flags_vertical = Control.SIZE_FILL if definition != null else Control.SIZE_EXPAND_FILL
		_party_buttons[index].tooltip_text = definition.display_name if definition != null else ""
		_style_party_slot(index, definition != null)


func _style_party_slot(index: int, occupied: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#272c32") if occupied else Color("#1b2026")
	style.border_color = GOLD if occupied else Color("#424952")
	style.set_border_width_all(2 if occupied else 1)
	style.set_corner_radius_all(6)
	_party_buttons[index].add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#38342c")
	_party_buttons[index].add_theme_stylebox_override("hover", hover)
	_party_buttons[index].add_theme_stylebox_override("pressed", hover)


func _get_party_drag(_position: Vector2, index: int) -> Variant:
	if index >= _ids.size():
		return null
	var preview := TextureRect.new()
	preview.texture = _party_portraits[index].texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size = _party_portraits[index].size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party_buttons[index].set_drag_preview(preview)
	return {"panel": self, "hero_id": _ids[index]}


func _can_drop_party(_position: Vector2, data: Variant, index: int) -> bool:
	return data is Dictionary and data.get("panel") == self and _ids.has(data.get("hero_id")) and index < _ids.size()


func _drop_party(position: Vector2, data: Variant, index: int) -> void:
	if _can_drop_party(position, data, index):
		_swap_party(_ids.find(data["hero_id"]), index)


func _swap_party(source: int, target: int) -> void:
	if source < 0 or target < 0 or source >= _ids.size() or target >= _ids.size() or source == target:
		return
	var id: String = _ids[source]
	_ids[source] = _ids[target]
	_ids[target] = id
	_commit_selection()


func _commit_selection() -> void:
	_refresh_selection()
	party_selected.emit(selected_party())

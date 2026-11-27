class_name HeroSelection
extends VBoxContainer

signal party_chosen(hero_ids: Array[String])
signal back_requested

@onready var _catalog: HeroCatalogGrid = %Catalog
@onready var _preview: HeroPreviewPanel = %Preview
@onready var _party_bar: PartySelectionBar = %PartyBar
@onready var _start_button: StoneMenuButton = %StartPartyButton
@onready var _body: BoxContainer = $Body
@onready var _left_column: VBoxContainer = $Body/LeftColumn
@onready var _footer_rule: HSeparator = $Body/LeftColumn/FooterRule
@onready var _party_row: HBoxContainer = $Body/LeftColumn/PartyRow
@onready var _back_button: StoneMenuButton = %BackButton

var _party_rules := HeroPartyRules.new()
var _selected_ids: Array[String] = []
var _heroes: Dictionary = {}
var _focused_id: String = ""
var _detail_page: bool = false
var _separate_page: bool = false
var _drag_layer: CardDragLayer
var _transfer_id := ""

const DRAG_DISTANCE := 12.0
const TOUCH_HOLD_MS := 220
const DOUBLE_TAP_MS := 320
const LAND_SECONDS := 0.32
const RETURN_SECONDS := 0.40

enum Gesture { NONE, TAP, SCROLL, DRAG }
var _gesture: Gesture = Gesture.NONE
var _gesture_id: String = ""
var _touch_index: int = -1
var _origin: Vector2
var _scroll_origin: int
var _started_at: int
var _gesture_double: bool = false
var _gesture_from_party := false
var _source_rect := Rect2()
var _ignore_emulated_mouse: bool = false
var _last_tap_id: String = ""
var _last_tap_at: int = -1000
var _last_tap_point: Vector2
var _pending_focus := Timer.new()


func _ready() -> void:
	_drag_layer = CardDragLayer.new()
	add_child(_drag_layer)
	_catalog.hero_focused.connect(_focus_hero)
	_catalog.hero_add_requested.connect(_add_hero)
	_pending_focus.one_shot = true
	_pending_focus.timeout.connect(_open_pending_focus)
	add_child(_pending_focus)
	_preview.catalog_requested.connect(_show_catalog)
	_party_bar.member_focused.connect(_focus_hero)
	_start_button.pressed.connect(_confirm_party)
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	resized.connect(_adapt_layout)
	_left_column.resized.connect(_adapt_party_row)
	get_viewport().size_changed.connect(_adapt_layout)
	visibility_changed.connect(_on_visibility_changed)
	var heroes: Array[HeroDefinition] = []
	for id in HeroCatalog.list_ids():
		heroes.append(HeroCatalog.get_hero(id))
	set_heroes(heroes)


func set_heroes(heroes: Array[HeroDefinition]) -> void:
	_clear_flights()
	_heroes.clear()
	var unique: Array[HeroDefinition] = []
	for hero in heroes:
		if hero == null or hero.hero_id.is_empty() or _heroes.has(hero.hero_id):
			continue
		_heroes[hero.hero_id] = hero
		unique.append(hero)
	_catalog.set_heroes(unique)
	reset_selection()


func configure_party_rules(rules: HeroPartyRules) -> void:
	_party_rules = rules
	_catalog.set_party_rules(rules)
	reset_selection()


func _focus_hero(hero_id: String, show_details: bool = true) -> void:
	if not _heroes.has(hero_id) or not _party_rules.allows(hero_id):
		return
	_pending_focus.stop()
	_focused_id = hero_id
	_detail_page = show_details
	_preview.show_hero(_heroes[hero_id] as HeroDefinition)
	_refresh_selection()
	_adapt_layout()


func _can_add_hero(hero_id: String) -> bool:
	return _heroes.has(hero_id) and _party_rules.allows(hero_id) and not _selected_ids.has(hero_id) and _selected_ids.size() < _party_rules.capacity()


func _add_hero(hero_id: String, animate: bool = true) -> void:
	if not _can_add_hero(hero_id):
		return
	_clear_flights()
	var tile: HeroCatalogTile = _catalog.tiles[hero_id]
	var source: Rect2 = tile.get_global_rect()
	if animate and tile.is_visible_in_tree() and _catalog.scroll.get_global_rect().intersects(source):
		_begin_transfer(hero_id, source, source.get_center(), false)
		_move_to_party(hero_id, _selected_ids.size())
	else:
		_selected_ids.append(hero_id)
		_refresh_selection()


func _tile_at(point: Vector2) -> HeroCatalogTile:
	if not _catalog.is_visible_in_tree() or not _catalog.scroll.get_global_rect().has_point(point):
		return null
	var scroll_bar: VScrollBar = _catalog.scroll.get_v_scroll_bar()
	if scroll_bar.is_visible_in_tree() and scroll_bar.get_global_rect().has_point(point):
		return null
	for tile in _catalog.tiles.values():
		if tile.is_visible_in_tree() and not tile.disabled and tile.get_global_rect().has_point(point):
			return tile as HeroCatalogTile
	return null


func _begin_gesture(point: Vector2, touch_index: int, double_click: bool = false) -> bool:
	var party_id: String = _party_bar.member_at(point)
	var tile: HeroCatalogTile = _tile_at(point)
	if party_id.is_empty() and tile == null:
		return false
	_clear_flights()
	_pending_focus.stop()
	_gesture = Gesture.TAP
	_gesture_from_party = not party_id.is_empty()
	_gesture_id = party_id if _gesture_from_party else tile.hero.hero_id
	_source_rect = _party_bar.target_rect(_selected_ids.find(party_id)) if _gesture_from_party else tile.get_global_rect()
	_touch_index = touch_index
	_origin = point
	_scroll_origin = _catalog.scroll.scroll_vertical
	_started_at = Time.get_ticks_msec()
	_gesture_double = double_click
	return true


func _move_gesture(point: Vector2) -> void:
	if _gesture == Gesture.TAP and point.distance_to(_origin) >= DRAG_DISTANCE:
		var scroll_bar: VScrollBar = _catalog.scroll.get_v_scroll_bar()
		var scrollable: bool = scroll_bar.max_value > scroll_bar.page
		var held: bool = Time.get_ticks_msec() - _started_at >= TOUCH_HOLD_MS
		if (_gesture_from_party and not _party_rules.required_ids.has(_gesture_id)) or (_can_add_hero(_gesture_id) and (_touch_index < 0 or not scrollable or held)):
			_gesture = Gesture.DRAG
			if not _gesture_from_party:
				_source_rect = (_catalog.tiles[_gesture_id] as HeroCatalogTile).get_global_rect()
			_begin_transfer(_gesture_id, _source_rect, _origin, _gesture_from_party)
			if _gesture_from_party and _separate_page and not _catalog.visible:
				_show_catalog()
		else:
			_gesture = Gesture.SCROLL
		_last_tap_id = ""
	if _gesture == Gesture.SCROLL and _touch_index >= 0:
		_catalog.scroll.scroll_vertical = _scroll_origin + roundi(_origin.y - point.y)
	elif _gesture == Gesture.DRAG:
		_drag_layer.follow(point, _gesture_from_party and _leaves_party_row(point))
		_party_bar.highlight_slot(_drop_slot(point))


func _leaves_party_row(point: Vector2) -> bool:
	var band: Rect2 = _party_row.get_global_rect()
	var leading_edge: float = _source_rect.position.y + point.y - _origin.y
	return leading_edge < band.position.y or not band.has_point(point)


func _end_gesture(point: Vector2, double_click: bool = false, canceled: bool = false) -> void:
	var id: String = _gesture_id
	var gesture: Gesture = _gesture
	var tile: HeroCatalogTile = _tile_at(point)
	if gesture == Gesture.DRAG:
		var target: int = _drop_slot(point) if not canceled else -1
		if target >= 0:
			_move_to_party(id, target)
		elif not canceled and _gesture_from_party and _catalog.is_visible_in_tree() and _catalog.get_global_rect().has_point(point):
			_drag_layer.follow(point, true)
			_move_to_catalog(id)
		else:
			_return_gesture()
	elif not canceled and gesture == Gesture.TAP:
		if _gesture_from_party and _party_bar.member_at(point) == id:
			_last_tap_id = ""
			_party_bar.focus_member(id)
			_focus_hero(id)
		elif tile != null and tile.hero.hero_id == id:
			tile.grab_focus()
			var now: int = Time.get_ticks_msec()
			var repeated: bool = id == _last_tap_id and now - _last_tap_at <= DOUBLE_TAP_MS and point.distance_to(_last_tap_point) < DRAG_DISTANCE * 2.0
			if double_click or _gesture_double or repeated:
				_last_tap_id = ""
				_add_hero(id)
				_focus_hero(id, not _separate_page)
			else:
				_last_tap_id = id
				_last_tap_at = now
				_last_tap_point = point
				if _separate_page:
					_pending_focus.start(float(DOUBLE_TAP_MS) / 1000.0)
				else:
					_focus_hero(id)
	_cancel_gesture()


func _open_pending_focus() -> void:
	if is_visible_in_tree() and _catalog.is_visible_in_tree() and not _last_tap_id.is_empty():
		_focus_hero(_last_tap_id)
	_last_tap_id = ""


func _cancel_gesture() -> void:
	_gesture = Gesture.NONE
	_gesture_id = ""
	_touch_index = -1
	_gesture_double = false
	_gesture_from_party = false
	_party_bar.highlight_slot(-1)


func _input(event: InputEvent) -> void:
	if not is_node_ready() or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _gesture != Gesture.NONE:
		if _gesture == Gesture.DRAG:
			_return_gesture()
		_cancel_gesture()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device == InputEvent.DEVICE_ID_EMULATION:
		if event.pressed:
			_ignore_emulated_mouse = _tile_at(event.position) != null or not _party_bar.member_at(event.position).is_empty() or _touch_index >= 0
		if _ignore_emulated_mouse:
			get_viewport().set_input_as_handled()
		if not event.pressed:
			_ignore_emulated_mouse = false
		return
	if event is InputEventMouseMotion and event.device == InputEvent.DEVICE_ID_EMULATION:
		if _ignore_emulated_mouse:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and _gesture == Gesture.NONE:
			if not _begin_gesture(event.position, event.index, event.double_tap):
				return
		elif not event.pressed and _gesture != Gesture.NONE and _touch_index == event.index:
			_end_gesture(event.position, false, event.canceled)
		else:
			return
	elif event is InputEventScreenDrag and _gesture != Gesture.NONE and _touch_index == event.index:
		_move_gesture(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and _gesture == Gesture.NONE:
			if not _begin_gesture(event.position, -1, event.double_click):
				return
		elif not event.pressed and _gesture != Gesture.NONE and _touch_index < 0:
			_end_gesture(event.position, event.double_click)
		else:
			return
	elif event is InputEventMouseMotion and _gesture != Gesture.NONE and _touch_index < 0:
		_move_gesture(event.position)
	else:
		return
	get_viewport().set_input_as_handled()


func _remove_hero(hero_id: String) -> void:
	if _party_rules.required_ids.has(hero_id):
		return
	var index: int = _selected_ids.find(hero_id)
	if index < 0:
		return
	_clear_flights()
	var source: Rect2 = _party_bar.target_rect(index)
	_begin_transfer(hero_id, source, source.get_center(), true)
	_move_to_catalog(hero_id)


func _refresh_selection() -> void:
	_catalog.refresh_selection(_focused_id, _selected_ids)
	_party_bar.refresh(_selected_ids, _heroes, _party_rules.capacity())
	_adapt_party_row()
	_start_button.disabled = not _party_rules.accepts_party(_selected_ids)
	_sync_preview_portrait()


func _adapt_layout() -> void:
	if not is_node_ready():
		return
	var narrow: bool = _available_width() < 740.0
	_separate_page = narrow and size.y < 680.0
	_body.vertical = narrow and not _separate_page
	_place_party_row(narrow)
	_catalog.visible = not _separate_page or not _detail_page
	_left_column.visible = _catalog.visible
	_preview.visible = not _separate_page or _detail_page
	_preview.custom_minimum_size.x = 0.0 if narrow else minf(310.0, size.x * 0.36)
	_preview.size_flags_stretch_ratio = 0.65 if _body.vertical else 1.0
	_preview.adapt(narrow, _separate_page, size.y)
	_adapt_party_row()
	_catalog.call_deferred("_layout_tiles")


func _place_party_row(narrow: bool) -> void:
	var destination: Container = self if narrow else _left_column
	if _party_row.get_parent() == destination:
		return
	_footer_rule.reparent(destination, false)
	_party_row.reparent(destination, false)
	if narrow:
		move_child(_footer_rule, _body.get_index() + 1)
		move_child(_party_row, _footer_rule.get_index() + 1)


func _available_width() -> float:
	return minf(size.x, get_viewport_rect().size.x + offset_right - offset_left)


func _adapt_party_row() -> void:
	if not is_node_ready():
		return
	var width: float = _available_width()
	if _party_row.get_parent() == _left_column:
		var body_width: float = width - _body.get_theme_constant("separation")
		var left_share: float = _left_column.size_flags_stretch_ratio / (_left_column.size_flags_stretch_ratio + _preview.size_flags_stretch_ratio)
		width = minf(body_width * left_share, body_width - _preview.get_combined_minimum_size().x)
		if _left_column.size.x > 0.0:
			width = minf(width, _left_column.size.x)
	var start_width: float = clampf(width * 0.22, 112.0, 160.0)
	_start_button.custom_minimum_size = Vector2(start_width, _start_button.height_for_width(start_width))
	_back_button.custom_minimum_size = Vector2(start_width, _back_button.height_for_width(start_width))
	var gap: int = _party_row.get_theme_constant("separation")
	var slot_gap: int = _party_bar.row.get_theme_constant("separation")
	var slots: int = _party_rules.capacity()
	var side: float = floorf((width - start_width - gap - slot_gap * (slots - 1)) / slots)
	var height_limit: float = minf(size.y, get_viewport_rect().size.y) * 0.19
	_party_bar.adapt(maxf(1.0, minf(side, minf(150.0, height_limit))))


func _show_catalog() -> void:
	_pending_focus.stop()
	_last_tap_id = ""
	_detail_page = false
	_adapt_layout()
	focus_first()


func _begin_transfer(hero_id: String, source: Rect2, point: Vector2, from_party: bool) -> void:
	_transfer_id = hero_id
	if is_visible_in_tree() and source.has_area():
		var visual := HeroCatalogTile.new()
		visual.theme = theme
		_drag_layer.lift(visual, source, point)
		visual.configure(_heroes[hero_id] as HeroDefinition)
		visual.set_selection(hero_id == _focused_id, 0)
		visual.configure_flight()
	if from_party:
		_party_bar.set_transfer(hero_id)
	else:
		_catalog.set_transfer(hero_id, "")
	_sync_preview_portrait()


func _move_to_party(hero_id: String, index: int) -> void:
	if not _selected_ids.has(hero_id) and not _can_add_hero(hero_id):
		return
	var previous: int = _selected_ids.find(hero_id)
	if previous >= 0:
		_selected_ids.remove_at(previous)
	_selected_ids.insert(clampi(index, 0, _selected_ids.size()), hero_id)
	_party_bar.set_transfer(hero_id)
	_refresh_selection()
	_catalog.set_transfer("", "")
	_settle_to_party(hero_id, LAND_SECONDS)


func _move_to_catalog(hero_id: String) -> void:
	if _party_rules.required_ids.has(hero_id):
		return
	_selected_ids.erase(hero_id)
	if _separate_page and not _catalog.visible:
		_show_catalog()
	_catalog.set_transfer("", hero_id)
	_refresh_selection()
	_party_bar.set_transfer("")
	_drag_layer.discard(func() -> Rect2: return _catalog.visible_tile_rect(hero_id), _finish_transfer)


func _settle_to_party(hero_id: String, duration: float) -> void:
	_drag_layer.settle(func() -> Rect2: return _party_bar.target_rect(_selected_ids.find(hero_id)), duration, _finish_transfer)


func _settle_to_catalog(hero_id: String, duration: float) -> void:
	_drag_layer.settle(func() -> Rect2: return _catalog.return_rect(hero_id), duration, _finish_transfer)


func _finish_transfer() -> void:
	_transfer_id = ""
	_catalog.set_transfer("", "")
	_party_bar.set_transfer("")
	_party_bar.highlight_slot(-1)
	_sync_preview_portrait()


func _sync_preview_portrait() -> void:
	_preview.portrait.modulate.a = 0.0 if not _transfer_id.is_empty() and _focused_id == _transfer_id else 1.0


func _clear_flights() -> void:
	_drag_layer.clear()
	_cancel_gesture()
	_finish_transfer()


func _drop_slot(point: Vector2) -> int:
	var index: int = _party_bar.slot_at(point)
	if index < 0:
		return -1
	if _gesture_from_party:
		return mini(index, _selected_ids.size() - 1)
	return _selected_ids.size() if _party_bar.accepts_drop(point) and _can_add_hero(_gesture_id) else -1


func _return_gesture() -> void:
	if _gesture_from_party:
		_settle_to_party(_gesture_id, RETURN_SECONDS)
	else:
		_catalog.set_transfer("", _gesture_id)
		_settle_to_catalog(_gesture_id, RETURN_SECONDS)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_node_ready():
		_clear_flights()
		_pending_focus.stop()
		_last_tap_id = ""
		_ignore_emulated_mouse = false


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_clear_flights()
		_ignore_emulated_mouse = false
		_pending_focus.stop()
		_last_tap_id = ""
	else:
		_adapt_layout()


func selected_party() -> Array[String]:
	return _selected_ids.duplicate()


func reset_selection() -> void:
	_clear_flights()
	_pending_focus.stop()
	_last_tap_id = ""
	_ignore_emulated_mouse = false
	_selected_ids.clear()
	for id in _party_rules.required_ids:
		if _heroes.has(id):
			_selected_ids.append(id)
	_catalog.reset_filter()
	_focused_id = ""
	if not _selected_ids.is_empty():
		_focused_id = _selected_ids[0]
	elif _heroes.has(HeroCatalog.DEFAULT_HERO_ID) and _party_rules.allows(HeroCatalog.DEFAULT_HERO_ID):
		_focused_id = HeroCatalog.DEFAULT_HERO_ID
	else:
		for id in _heroes:
			if _party_rules.allows(id):
				_focused_id = id
				break
	_detail_page = false
	_preview.show_hero(_heroes.get(_focused_id) as HeroDefinition)
	_refresh_selection()
	_adapt_layout()


func _confirm_party() -> void:
	if _gesture == Gesture.DRAG or not _party_rules.accepts_party(_selected_ids):
		return
	party_chosen.emit(selected_party())


func focus_first() -> void:
	for tile in _catalog.tiles.values():
		if (tile as HeroCatalogTile).is_visible_in_tree() and not (tile as HeroCatalogTile).disabled:
			(tile as HeroCatalogTile).grab_focus()
			return
	if not _selected_ids.is_empty():
		_party_bar.focus_member(_selected_ids[0])

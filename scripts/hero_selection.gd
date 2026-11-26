class_name HeroSelection
extends VBoxContainer

signal party_chosen(hero_ids: Array[String])
signal back_requested

@onready var _catalog: HeroCatalogGrid = %Catalog
@onready var _preview: HeroPreviewPanel = %Preview
@onready var _party_bar: PartySelectionBar = %PartyBar
@onready var _start_button: Button = %StartPartyButton
@onready var _body: BoxContainer = $Body

var _selected_ids: Array[String] = []
var _heroes: Dictionary = {}
var _focused_id: String = ""
var _detail_page: bool = false
var _separate_page: bool = false
var _flights: Array[TextureRect] = []

const DRAG_DISTANCE := 12.0
const TOUCH_HOLD_MS := 220
const DOUBLE_TAP_MS := 320

enum Gesture { NONE, TAP, SCROLL, DRAG }
var _gesture: Gesture = Gesture.NONE
var _gesture_id: String = ""
var _touch_index: int = -1
var _origin: Vector2
var _scroll_origin: int
var _started_at: int
var _gesture_double: bool = false
var _drag_portrait: TextureRect
var _ignore_emulated_mouse: bool = false
var _last_tap_id: String = ""
var _last_tap_at: int = -1000
var _last_tap_point: Vector2
var _pending_focus := Timer.new()


func _ready() -> void:
	_catalog.hero_focused.connect(_focus_hero)
	_catalog.hero_add_requested.connect(_add_hero)
	_pending_focus.one_shot = true
	_pending_focus.timeout.connect(_open_pending_focus)
	add_child(_pending_focus)
	_preview.catalog_requested.connect(_show_catalog)
	_party_bar.member_focused.connect(_focus_hero)
	_party_bar.member_removed.connect(_remove_hero)
	_start_button.pressed.connect(_confirm_party)
	%BackButton.pressed.connect(func() -> void: back_requested.emit())
	resized.connect(_adapt_layout)
	visibility_changed.connect(_on_visibility_changed)
	var heroes: Array[HeroDefinition] = []
	for id in HeroCatalog.list_ids():
		heroes.append(HeroCatalog.get_hero(id))
	set_heroes(heroes)


func set_heroes(heroes: Array[HeroDefinition]) -> void:
	_heroes.clear()
	var unique: Array[HeroDefinition] = []
	for hero in heroes:
		if hero == null or hero.hero_id.is_empty() or _heroes.has(hero.hero_id):
			continue
		_heroes[hero.hero_id] = hero
		unique.append(hero)
	_catalog.set_heroes(unique)
	reset_selection()


func _focus_hero(hero_id: String, show_details: bool = true) -> void:
	if not _heroes.has(hero_id):
		return
	_pending_focus.stop()
	_focused_id = hero_id
	_detail_page = show_details
	_preview.show_hero(_heroes[hero_id] as HeroDefinition)
	_refresh_selection()
	_adapt_layout()


func _can_add_hero(hero_id: String) -> bool:
	return _heroes.has(hero_id) and not _selected_ids.has(hero_id) and _selected_ids.size() < GameSession.MAX_PARTY_SIZE


func _add_hero(hero_id: String, animate: bool = true) -> void:
	if not _can_add_hero(hero_id):
		return
	var tile: HeroCatalogTile = _catalog.tiles[hero_id]
	_selected_ids.append(hero_id)
	_refresh_selection()
	if animate and tile.is_visible_in_tree() and _catalog.scroll.get_global_rect().encloses(tile.portrait.get_global_rect()):
		_animate_add(tile.portrait, _selected_ids.size() - 1)


func _tile_at(point: Vector2) -> HeroCatalogTile:
	if not _catalog.is_visible_in_tree() or not _catalog.scroll.get_global_rect().has_point(point):
		return null
	var scroll_bar: VScrollBar = _catalog.scroll.get_v_scroll_bar()
	if scroll_bar.is_visible_in_tree() and scroll_bar.get_global_rect().has_point(point):
		return null
	for tile in _catalog.tiles.values():
		if tile.is_visible_in_tree() and tile.get_global_rect().has_point(point):
			return tile as HeroCatalogTile
	return null


func _begin_gesture(tile: HeroCatalogTile, point: Vector2, touch_index: int, double_click: bool = false) -> void:
	_pending_focus.stop()
	_gesture = Gesture.TAP
	_gesture_id = tile.hero.hero_id
	_touch_index = touch_index
	_origin = point
	_scroll_origin = _catalog.scroll.scroll_vertical
	_started_at = Time.get_ticks_msec()
	_gesture_double = double_click


func _move_gesture(point: Vector2) -> void:
	if _gesture == Gesture.TAP and point.distance_to(_origin) >= DRAG_DISTANCE:
		var scroll_bar: VScrollBar = _catalog.scroll.get_v_scroll_bar()
		var scrollable: bool = scroll_bar.max_value > scroll_bar.page
		var held: bool = Time.get_ticks_msec() - _started_at >= TOUCH_HOLD_MS
		if _can_add_hero(_gesture_id) and (_touch_index < 0 or not scrollable or held):
			_gesture = Gesture.DRAG
			var tile: HeroCatalogTile = _catalog.tiles[_gesture_id]
			_drag_portrait = TextureRect.new()
			_drag_portrait.texture = tile.portrait.texture
			_drag_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_drag_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_drag_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_drag_portrait.top_level = true
			_drag_portrait.z_index = 11
			add_child(_drag_portrait)
			_drag_portrait.size = tile.portrait.size
			_drag_portrait.modulate.a = 0.85
		else:
			_gesture = Gesture.SCROLL
		_last_tap_id = ""
	if _gesture == Gesture.SCROLL and _touch_index >= 0:
		_catalog.scroll.scroll_vertical = _scroll_origin + roundi(_origin.y - point.y)
	elif _gesture == Gesture.DRAG:
		_drag_portrait.global_position = point - _drag_portrait.size * 0.5
		_party_bar.highlight_drop(point)


func _end_gesture(point: Vector2, double_click: bool = false, canceled: bool = false) -> void:
	var id: String = _gesture_id
	var gesture: Gesture = _gesture
	var tile: HeroCatalogTile = _tile_at(point)
	if not canceled and gesture == Gesture.DRAG and _party_bar.accepts_drop(point):
		_add_hero(id, false)
	elif not canceled and gesture == Gesture.TAP and tile != null and tile.hero.hero_id == id:
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
	if _drag_portrait != null:
		_drag_portrait.hide()
		_drag_portrait.queue_free()
		_drag_portrait = null
	_gesture = Gesture.NONE
	_gesture_id = ""
	_touch_index = -1
	_gesture_double = false
	_party_bar.clear_drop_highlight()


func _input(event: InputEvent) -> void:
	if not is_node_ready() or not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device == InputEvent.DEVICE_ID_EMULATION:
		if event.pressed:
			_ignore_emulated_mouse = _tile_at(event.position) != null or _touch_index >= 0
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
			var tile: HeroCatalogTile = _tile_at(event.position)
			if tile == null:
				return
			_begin_gesture(tile, event.position, event.index, event.double_tap)
		elif not event.pressed and _gesture != Gesture.NONE and _touch_index == event.index:
			_end_gesture(event.position, false, event.canceled)
		else:
			return
	elif event is InputEventScreenDrag and _gesture != Gesture.NONE and _touch_index == event.index:
		_move_gesture(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and _gesture == Gesture.NONE:
			var tile: HeroCatalogTile = _tile_at(event.position)
			if tile == null:
				return
			_begin_gesture(tile, event.position, -1, event.double_click)
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
	_selected_ids.erase(hero_id)
	_refresh_selection()


func _refresh_selection() -> void:
	_catalog.refresh_selection(_focused_id, _selected_ids)
	_party_bar.refresh(_selected_ids, _heroes)
	_party_bar.adapt(size.x < 760.0)
	_start_button.disabled = _selected_ids.is_empty()


func _adapt_layout() -> void:
	if not is_node_ready():
		return
	var narrow: bool = size.x < 740.0
	_separate_page = narrow and size.y < 680.0
	_body.vertical = narrow and not _separate_page
	_catalog.visible = not _separate_page or not _detail_page
	_preview.visible = not _separate_page or _detail_page
	_preview.custom_minimum_size.x = 0.0 if narrow else minf(310.0, size.x * 0.36)
	_preview.size_flags_stretch_ratio = 0.65 if _body.vertical else 1.0
	_preview.adapt(narrow, _separate_page, size.y)
	_party_bar.adapt(size.x < 760.0)
	_catalog.call_deferred("_layout_tiles")


func _show_catalog() -> void:
	_pending_focus.stop()
	_last_tap_id = ""
	_detail_page = false
	_adapt_layout()
	focus_first()


func _animate_add(source: TextureRect, index: int) -> void:
	if not source.is_visible_in_tree() or source.texture == null:
		return
	var from: Rect2 = source.get_global_rect()
	var destination: Rect2 = _party_bar.target_rect(index)
	var flight := TextureRect.new()
	flight.texture = source.texture
	flight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flight.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flight.top_level = true
	flight.z_index = 10
	add_child(flight)
	flight.global_position = from.position
	flight.size = from.size
	_flights.append(flight)
	var tween: Tween = flight.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(flight, "global_position", destination.position, 0.28)
	tween.tween_property(flight, "size", destination.size, 0.28)
	tween.tween_property(flight, "modulate:a", 0.0, 0.12).set_delay(0.16)
	tween.chain().tween_callback(func() -> void:
		_flights.erase(flight)
		flight.queue_free()
	)


func _clear_flights() -> void:
	for flight in _flights:
		flight.hide()
		flight.queue_free()
	_flights.clear()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_clear_flights()
		_cancel_gesture()
		_pending_focus.stop()
		_last_tap_id = ""
	else:
		_adapt_layout()


func selected_party() -> Array[String]:
	return _selected_ids.duplicate()


func reset_selection() -> void:
	_cancel_gesture()
	_pending_focus.stop()
	_last_tap_id = ""
	_clear_flights()
	_selected_ids.clear()
	_catalog.reset_filter()
	_focused_id = ""
	if _heroes.has(HeroCatalog.DEFAULT_HERO_ID):
		_focused_id = HeroCatalog.DEFAULT_HERO_ID
	elif not _heroes.is_empty():
		_focused_id = str(_heroes.keys()[0])
	_detail_page = false
	_preview.show_hero(_heroes.get(_focused_id) as HeroDefinition)
	_refresh_selection()
	_adapt_layout()


func _confirm_party() -> void:
	if _selected_ids.is_empty() or _selected_ids.size() > GameSession.MAX_PARTY_SIZE:
		return
	party_chosen.emit(selected_party())


func focus_first() -> void:
	for tile in _catalog.tiles.values():
		if (tile as HeroCatalogTile).is_visible_in_tree():
			(tile as HeroCatalogTile).grab_focus()
			return

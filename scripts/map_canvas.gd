class_name DungeonCanvas
extends Control

## Рисование карты и обработка мыши/пальцев. Логика карты живёт в DungeonMap.

signal map_edited
signal hover_changed(cell: Vector2i)
signal move_selection_changed(description: String)
signal move_failed
signal edit_action_committed(before: Dictionary, after: Dictionary)
signal configurable_entity_tapped(kind: String, entity_id: String)
signal message_cell_tapped(cell: Vector2i)

const TILE_SIZE := 48.0
const FLOOR_TEXTURE: Texture2D = preload("res://assets/stone_floor.png")
const WALL_TEXTURE: Texture2D = preload("res://assets/stone_wall.png")
const DOUBLE_TAP_MS := 400
const TAP_MOVE_LIMIT := 16.0

var map_data: DungeonMap
var game_session: GameSession
var mode: String = "edit" # edit | play
var selected_tool: String = "wall"
var show_grid: bool = true
var camera_offset := Vector2.ZERO
var zoom: float = 1.0

var _hovered := Vector2i(-1, -1)
var _painting: bool = false
var _erasing: bool = false
var _panning: bool = false
var _touch_positions: Dictionary = {}
var _touch_blocked: bool = false # После мультитача кисть ждёт отпускания всех пальцев.
var _touch_starts: Dictionary = {}
var _touch_invalid_tap: bool = false
var _mouse_down := Vector2.ZERO
var _mouse_dragged: bool = false
var _last_tap_time: int = -10000
var _last_tap_cell := Vector2i(-1, -1)
var _cancelled_tap_time: int = -10000
var _cancelled_tap_cell := Vector2i(-1, -1)
var _moving_kind: String = ""
var _moving_id: String = ""
var _moving_from := Vector2i(-1, -1)
var _stroke_before: Dictionary = {}
var _settings_tap_timer: Timer
var _pending_settings_id: String = ""
var _pending_settings_kind: String = ""
var _settings_tool_pressed_id: String = ""



func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	resized.connect(queue_redraw)
	_settings_tap_timer = Timer.new()
	_settings_tap_timer.one_shot = true
	_settings_tap_timer.wait_time = float(DOUBLE_TAP_MS) / 1000.0
	_settings_tap_timer.timeout.connect(_on_settings_tap_timeout)
	add_child(_settings_tap_timer)


func set_map(value: DungeonMap) -> void:
	_stroke_before.clear()
	map_data = value
	game_session = null
	mode = "edit"
	_hovered = Vector2i(-1, -1)
	cancel_move_selection()
	_reset_pointer_state()
	call_deferred("_fit_after_layout")
	queue_redraw()


func set_selected_tool(kind: String) -> void:
	if selected_tool == kind:
		return
	finish_edit_stroke()
	cancel_move_selection()
	_cancel_pending_settings_tap()
	selected_tool = kind
	_last_tap_time = -10000
	_last_tap_cell = Vector2i(-1, -1)
	_painting = false
	_erasing = false
	_panning = false
	# Переключение инструмента во время касания не начинает новый штрих.
	_touch_blocked = not _touch_positions.is_empty()
	queue_redraw()


func _reset_pointer_state() -> void:
	_cancel_pending_settings_tap()
	_settings_tool_pressed_id = ""
	_painting = false
	_erasing = false
	_panning = false
	_touch_positions.clear()
	_touch_starts.clear()
	_touch_invalid_tap = false
	_mouse_dragged = false
	_last_tap_time = -10000
	_last_tap_cell = Vector2i(-1, -1)
	_touch_blocked = false


func set_game_session(value: GameSession) -> void:
	cancel_move_selection()
	_reset_pointer_state()
	game_session = value
	if value != null:
		map_data = value.map_data
		mode = "play"
	else:
		mode = "edit"
	queue_redraw()


# Дожидаемся размеров контейнера: при первой загрузке прежний deferred fit
# иногда выполнялся до окончательной раскладки интерфейса.
func _fit_after_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if mode == "edit":
		fit_to_view()


func fit_to_view() -> void:
	if map_data == null or size.x <= 0 or size.y <= 0:
		return
	var map_size := Vector2(map_data.width, map_data.height) * TILE_SIZE
	zoom = clampf(minf((size.x - 72.0) / map_size.x, (size.y - 72.0) / map_size.y), 0.2, 2.5)
	camera_offset = (size - map_size * zoom) / 2.0
	queue_redraw()


func center_on_cell(cell: Vector2i) -> void:
	if map_data == null:
		return
	var world_center := (Vector2(cell) + Vector2.ONE * 0.5) * TILE_SIZE
	camera_offset = size * 0.5 - world_center * zoom
	queue_redraw()


func zoom_at(screen_point: Vector2, factor: float) -> void:
	var new_zoom := clampf(zoom * factor, 0.2, 3.5)
	camera_offset = screen_point - (screen_point - camera_offset) * (new_zoom / zoom)
	zoom = new_zoom
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#131a22"))
	if map_data == null:
		return
	var min_x := clampi(floori(-camera_offset.x / (TILE_SIZE * zoom)) - 1, 0, map_data.width)
	var min_y := clampi(floori(-camera_offset.y / (TILE_SIZE * zoom)) - 1, 0, map_data.height)
	var max_x := clampi(ceili((size.x - camera_offset.x) / (TILE_SIZE * zoom)) + 1, 0, map_data.width)
	var max_y := clampi(ceili((size.y - camera_offset.y) / (TILE_SIZE * zoom)) + 1, 0, map_data.height)
	if min_x >= max_x or min_y >= max_y:
		return

	draw_set_transform(camera_offset, 0.0, Vector2.ONE * zoom)
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			_draw_cell(x, y)

	if mode == "play" and game_session != null and map_data.contains(game_session.player_pos.x, game_session.player_pos.y):
		_draw_player(Vector2(game_session.player_pos) * TILE_SIZE)

	if show_grid:
		var grid_color := Color(0.82, 0.84, 0.91, 0.20)
		for x in range(min_x, max_x + 1):
			var pos_x := float(x) * TILE_SIZE
			draw_line(Vector2(pos_x, float(min_y) * TILE_SIZE), Vector2(pos_x, float(max_y) * TILE_SIZE), grid_color, 1.0 / zoom)
		for y in range(min_y, max_y + 1):
			var pos_y := float(y) * TILE_SIZE
			draw_line(Vector2(float(min_x) * TILE_SIZE, pos_y), Vector2(float(max_x) * TILE_SIZE, pos_y), grid_color, 1.0 / zoom)

	if mode == "edit" and not _moving_kind.is_empty() and map_data.contains(_moving_from.x, _moving_from.y):
		var chosen := Rect2(Vector2(_moving_from) * TILE_SIZE, Vector2.ONE * TILE_SIZE)
		draw_rect(chosen, Color(1.0, 0.78, 0.24, 0.20))
		draw_rect(chosen.grow(-2), Color("#ffd26c"), false, 3.0 / zoom)
	if mode == "edit" and selected_tool != "hand" and map_data.contains(_hovered.x, _hovered.y):
		var hovered_rect := Rect2(Vector2(_hovered) * TILE_SIZE, Vector2.ONE * TILE_SIZE)
		draw_rect(hovered_rect, Color(0.34, 0.80, 1.0, 0.22))
		draw_rect(hovered_rect, Color("#82d3fd"), false, 2.0 / zoom)
	draw_rect(Rect2(0, 0, map_data.width * TILE_SIZE, map_data.height * TILE_SIZE), Color("#9da5ab"), false, 2.0 / zoom)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cell(x: int, y: int) -> void:
	var rect := Rect2(float(x) * TILE_SIZE, float(y) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	var can_see := mode != "play" or game_session == null or game_session.is_visible(x, y)
	var has_seen := mode != "play" or game_session == null or game_session.is_revealed(x, y)
	if not has_seen:
		draw_rect(rect, Color("#05080c"))
		return
	if map_data.get_terrain(x, y) == "wall":
		draw_texture_rect(WALL_TEXTURE, rect, false)
	else:
		draw_texture_rect(FLOOR_TEXTURE, rect, false)
	var entities_here := map_data.entities_at(x, y)
	for entity in entities_here:
		if mode == "play" and game_session != null and game_session.is_entity_removed(entity):
			continue
		var kind := str(entity["type"])
		if mode == "play" and kind in ["player_spawn", "trigger", "message"]:
			continue
		var origin := Vector2(x, y) * TILE_SIZE
		if kind == "chest" and (DungeonMap.chest_contents(entity).is_empty() or (mode == "play" and game_session != null and game_session.is_chest_open(entity))):
			_draw_open_chest(origin)
		elif kind == "monster":
			var icon: Texture2D = MonsterCatalog.from_entity(entity).icon
			draw_texture_rect(icon, Rect2(origin, Vector2.ONE * TILE_SIZE), false)
		else:
			_draw_entity(kind, origin)
	if mode == "play" and not can_see:
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.55))


func _draw_player(origin: Vector2) -> void:
	var icon: Texture2D = game_session.hero.definition.map_icon if game_session != null and game_session.hero != null and game_session.hero.definition != null else null
	if icon != null:
		draw_texture_rect(icon, Rect2(origin, Vector2.ONE * TILE_SIZE), false)
		return
	var center := origin + Vector2.ONE * (TILE_SIZE / 2.0)
	draw_circle(center + Vector2(0, -9), 8.0, Color("#f9fff4"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-14, 17), center + Vector2(-10, 0), center + Vector2(0, -1), center + Vector2(10, 0), center + Vector2(14, 17)]), Color("#8af0c1"))
	draw_rect(Rect2(center + Vector2(-5, 3), Vector2(10, 10)), Color("#1e7463"))
	draw_circle(center + Vector2(14, -12), 4.0, Color("#e8c58a"))


func _draw_open_chest(origin: Vector2) -> void:
	# Крышка откинута, внутри видна пустая тёмная полость.
	draw_rect(Rect2(origin + Vector2(8, 8), Vector2(32, 13)), Color("#382817"))
	draw_rect(Rect2(origin + Vector2(10, 10), Vector2(28, 9)), Color("#bd8b48"))
	draw_rect(Rect2(origin + Vector2(12, 13), Vector2(24, 6)), Color("#211715"))
	draw_rect(Rect2(origin + Vector2(8, 21), Vector2(32, 20)), Color("#382817"))
	draw_rect(Rect2(origin + Vector2(10, 23), Vector2(28, 16)), Color("#a76a2d"))
	draw_rect(Rect2(origin + Vector2(12, 23), Vector2(24, 9)), Color("#171014"))
	draw_rect(Rect2(origin + Vector2(21, 29), Vector2(6, 10)), Color("#ffe2a0"))


func _draw_entity(kind: String, origin: Vector2) -> void:
	var center := origin + Vector2.ONE * (TILE_SIZE / 2.0)
	match kind:
		"door":
			draw_rect(Rect2(origin + Vector2(11, 5), Vector2(26, 38)), Color("#42291d"))
			draw_rect(Rect2(origin + Vector2(14, 7), Vector2(20, 34)), Color("#b77a3c"))
			draw_line(origin + Vector2(24, 8), origin + Vector2(24, 40), Color("#714222"), 2.0)
			draw_circle(origin + Vector2(30, 26), 2.6, Color("#f3d380"))
		"chest":
			draw_rect(Rect2(origin + Vector2(8, 17), Vector2(32, 23)), Color("#382817"))
			draw_rect(Rect2(origin + Vector2(10, 19), Vector2(28, 19)), Color("#a76a2d"))
			draw_rect(Rect2(origin + Vector2(10, 14), Vector2(28, 9)), Color("#d8a45b"))
			draw_rect(Rect2(origin + Vector2(21, 16), Vector2(6, 16)), Color("#ffe2a0"))
		"stairs_down":
			draw_rect(Rect2(origin + Vector2(7, 9), Vector2(34, 31)), Color("#172d37"))
			for i in range(4):
				var margin := float(i) * 3.0
				draw_rect(Rect2(origin + Vector2(10 + margin, 10 + i * 7), Vector2(28 - margin * 2, 5)), Color("#5aa7bf").darkened(float(i) * 0.13))
		"key":
			draw_circle(origin + Vector2(18, 15), 7.0, Color("#ffe096"), false, 4.0)
			draw_line(origin + Vector2(22, 20), origin + Vector2(35, 35), Color("#f3ca68"), 5.0)
			draw_line(origin + Vector2(30, 30), origin + Vector2(35, 26), Color("#f3ca68"), 4.0)
		"gold":
			# Монеты рисуются прямо на карте без рамки кнопки палитры.
			draw_circle(origin + Vector2(17, 29), 10.0, Color("#b97e32"))
			draw_circle(origin + Vector2(17, 26), 10.0, Color("#f0c15f"))
			draw_circle(origin + Vector2(28, 29), 10.0, Color("#a66c27"))
			draw_circle(origin + Vector2(28, 26), 10.0, Color("#efb94f"))
			draw_circle(origin + Vector2(24, 18), 11.0, Color("#df9d39"))
			draw_circle(origin + Vector2(24, 16), 11.0, Color("#ffd578"))
			draw_circle(origin + Vector2(24, 16), 7.0, Color("#dba246"), false, 2.0)
		"potion":
			draw_rect(Rect2(origin + Vector2(20, 7), Vector2(8, 10)), Color("#c7b7a2"))
			draw_rect(Rect2(origin + Vector2(13, 18), Vector2(22, 22)), Color("#94c9cc"))
			draw_rect(Rect2(origin + Vector2(15, 24), Vector2(18, 14)), Color("#8a64d1"))
			draw_rect(Rect2(origin + Vector2(18, 10), Vector2(12, 4)), Color("#d8bf89"))
		"message":
			# Маркер заметен в редакторе, но не перекрывает дверь и предметы.
			draw_rect(Rect2(origin + Vector2(29, 3), Vector2(16, 13)), Color("#ffdd93"))
			draw_rect(Rect2(origin + Vector2(31, 5), Vector2(12, 9)), Color("#47352b"))
			draw_colored_polygon(PackedVector2Array([origin + Vector2(32, 16), origin + Vector2(36, 16), origin + Vector2(32, 20)]), Color("#ffdd93"))
		"trigger":
			draw_circle(center, 16.0, Color("#c8a4f2"), false, 2.5)
			draw_circle(center, 7.0, Color("#a47acf"), false, 2.0)
			draw_line(center + Vector2(-21, 0), center + Vector2(21, 0), Color("#b08cda"), 1.5)
			draw_line(center + Vector2(0, -21), center + Vector2(0, 21), Color("#b08cda"), 1.5)
		"player_spawn":
			draw_circle(center + Vector2(0, -9), 8.0, Color("#d5f5d4"))
			draw_colored_polygon(PackedVector2Array([center + Vector2(-14, 17), center + Vector2(-10, 0), center + Vector2(0, -1), center + Vector2(10, 0), center + Vector2(14, 17)]), Color("#62e0aa"))
			draw_rect(Rect2(center + Vector2(-5, 3), Vector2(10, 10)), Color("#1e7463"))


func _screen_to_cell(point: Vector2) -> Vector2i:
	var world := (point - camera_offset) / zoom
	return Vector2i(floori(world.x / TILE_SIZE), floori(world.y / TILE_SIZE))


func _update_hover(point: Vector2) -> void:
	var cell := _screen_to_cell(point)
	if map_data == null or not map_data.contains(cell.x, cell.y):
		cell = Vector2i(-1, -1)
	if cell != _hovered:
		_hovered = cell
		hover_changed.emit(cell)
		queue_redraw()


## Краткая история операций: запоминаем только содержимое карты, не камеру.
func capture_edit_state() -> Dictionary:
	return {"terrain": map_data.terrain.duplicate(true), "entities": map_data.entities.duplicate(true)}


func restore_edit_state(state: Dictionary) -> void:
	if mode != "edit" or map_data == null:
		return
	_stroke_before.clear()
	cancel_move_selection()
	map_data.terrain = state["terrain"].duplicate(true)
	map_data.entities = state["entities"].duplicate(true)
	queue_redraw()


func _begin_edit_stroke() -> void:
	if mode == "edit" and selected_tool != "hand" and map_data != null and _stroke_before.is_empty():
		_stroke_before = capture_edit_state()


func finish_edit_stroke() -> void:
	if _stroke_before.is_empty():
		return
	var before := _stroke_before
	_stroke_before = {}
	var after := capture_edit_state()
	if before != after:
		edit_action_committed.emit(before, after)


func has_move_selection() -> bool:
	return not _moving_kind.is_empty()


func cancel_move_selection() -> void:
	if _moving_kind.is_empty():
		return
	_moving_kind = ""
	_moving_id = ""
	_moving_from = Vector2i(-1, -1)
	move_selection_changed.emit("")
	queue_redraw()


func _select_at(cell: Vector2i) -> void:
	var entities := map_data.entities_at(cell.x, cell.y)
	_moving_from = cell
	if not entities.is_empty():
		# Двойной тап по двери с посланием должен переносить дверь, а не маркер.
		var selected: Dictionary = entities.back()
		for i in range(entities.size() - 1, -1, -1):
			if str(entities[i].get("type", "")) != "message":
				selected = entities[i]
				break
		_moving_kind = str(selected["type"])
		_moving_id = str(selected["id"])
	elif map_data.get_terrain(cell.x, cell.y) == "wall":
		_moving_kind = "wall"
		_moving_id = ""
	else:
		return
	move_selection_changed.emit(_moving_kind)
	queue_redraw()


func _hand_tap(point: Vector2, is_double: bool) -> void:
	if mode != "edit" or selected_tool != "hand" or map_data == null:
		return
	var cell := _screen_to_cell(point)
	if not map_data.contains(cell.x, cell.y):
		return
	var now := Time.get_ticks_msec()
	if has_move_selection():
		if cell == _moving_from:
			_cancelled_tap_time = now
			_cancelled_tap_cell = cell
			cancel_move_selection()
			return
		var before := capture_edit_state()
		if map_data.move_existing(_moving_kind, _moving_id, _moving_from, cell):
			edit_action_committed.emit(before, capture_edit_state())
			_cancelled_tap_time = now
			_cancelled_tap_cell = cell
			cancel_move_selection()
			map_edited.emit()
			queue_redraw()
		else:
			move_failed.emit()
		return
	if is_double and not (cell == _cancelled_tap_cell and now - _cancelled_tap_time <= DOUBLE_TAP_MS):
		_select_at(cell)


## Контекстные свойства для сундуков, монстров, триггеров и посланий.
## В режиме «Рука» выбираем верхний на клетке редактируемый объект.
func _configurable_at(cell: Vector2i) -> Dictionary:
	if map_data == null or not map_data.contains(cell.x, cell.y):
		return {}
	var entities := map_data.entities_at(cell.x, cell.y)
	for i in range(entities.size() - 1, -1, -1):
		var entity: Dictionary = entities[i]
		var kind := str(entity.get("type", ""))
		if kind in ["chest", "trigger", "message", "monster"] and (selected_tool == "hand" or kind == selected_tool or (kind == "monster" and selected_tool.begins_with("monster:"))):
			return entity
	return {}


func _selected_tool_has_properties() -> bool:
	return selected_tool in ["chest", "trigger"] or selected_tool.begins_with("monster:")


func _cancel_pending_settings_tap() -> void:
	_pending_settings_id = ""
	_pending_settings_kind = ""
	if _settings_tap_timer != null:
		_settings_tap_timer.stop()


func _on_settings_tap_timeout() -> void:
	if mode == "edit" and selected_tool == "hand" and not _pending_settings_id.is_empty() and not has_move_selection():
		configurable_entity_tapped.emit(_pending_settings_kind, _pending_settings_id)
	_pending_settings_id = ""
	_pending_settings_kind = ""


func _remember_touch_tap(point: Vector2) -> void:
	var now := Time.get_ticks_msec()
	var cell := _screen_to_cell(point)
	var double_tap: bool = cell == _last_tap_cell and now - _last_tap_time <= DOUBLE_TAP_MS
	_cancel_pending_settings_tap()
	if not double_tap and not has_move_selection():
		var editable := _configurable_at(cell)
		if not editable.is_empty():
			_pending_settings_id = str(editable["id"])
			_pending_settings_kind = str(editable["type"])
			_settings_tap_timer.start()
		else:
			_hand_tap(point, false)
	else:
		_hand_tap(point, double_tap)
	_last_tap_time = now
	_last_tap_cell = cell


func _request_message_at(point: Vector2) -> void:
	if mode != "edit" or selected_tool != "message" or map_data == null:
		return
	var cell := _screen_to_cell(point)
	if map_data.contains(cell.x, cell.y) and map_data.get_terrain(cell.x, cell.y) == "floor":
		message_cell_tapped.emit(cell)


func _edit_at(point: Vector2, erase: bool) -> void:
	if mode != "edit" or selected_tool in ["hand", "message"] or map_data == null:
		return
	var cell := _screen_to_cell(point)
	if not map_data.contains(cell.x, cell.y):
		return
	var modified := false
	if erase or selected_tool == "erase":
		modified = map_data.erase_at(cell.x, cell.y)
	elif selected_tool in ["floor", "wall"]:
		modified = map_data.set_terrain(cell.x, cell.y, selected_tool)
	elif selected_tool == "chest":
		modified = map_data.place_entity("chest", cell.x, cell.y)
	elif selected_tool.begins_with("monster:"):
		var monster_id: String = selected_tool.trim_prefix("monster:")
		if MonsterCatalog.DEFINITIONS.has(monster_id):
			modified = map_data.place_entity("monster", cell.x, cell.y, {"monster_id": monster_id})
	elif selected_tool not in ["key", "potion", "gold", "sword"]:
		# Подбираемые вещи появляются только через источники добычи (пока сундуки).
		modified = map_data.place_entity(selected_tool, cell.x, cell.y)
	if modified:
		queue_redraw()
		map_edited.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# На Android тач-событие дополнительно эмулирует мышь.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_update_hover(event.position)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(event.position, 1.12)
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(event.position, 1.0 / 1.12)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if mode == "edit" and selected_tool == "message":
				if event.pressed:
					_mouse_down = event.position
				elif event.position.distance_to(_mouse_down) < TAP_MOVE_LIMIT:
					_request_message_at(event.position)
				accept_event()
			elif mode == "edit" and selected_tool == "hand":
				if event.pressed:
					_mouse_down = event.position
					_mouse_dragged = false
					_panning = true
				else:
					_panning = false
					if not _mouse_dragged:
						_remember_touch_tap(event.position)
				accept_event()
			elif mode == "edit" and (_panning or Input.is_key_pressed(KEY_SPACE)):
				_panning = event.pressed
				_painting = false
				accept_event()
			elif mode == "edit":
				_painting = event.pressed
				if event.pressed:
					_mouse_down = event.position
					_settings_tool_pressed_id = str(_configurable_at(_screen_to_cell(event.position)).get("id", "")) if _selected_tool_has_properties() else ""
					_begin_edit_stroke()
					_edit_at(event.position, false)
				else:
					finish_edit_stroke()
					if _selected_tool_has_properties() and not _settings_tool_pressed_id.is_empty() and event.position.distance_to(_mouse_down) < TAP_MOVE_LIMIT:
						configurable_entity_tapped.emit("monster" if selected_tool.begins_with("monster:") else selected_tool, _settings_tool_pressed_id)
					_settings_tool_pressed_id = ""
				accept_event()
			elif mode == "play" and event.pressed:
				grab_focus()
				accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if mode == "play":
				_panning = event.pressed
			elif mode == "edit" and selected_tool != "hand":
				_erasing = event.pressed
				if event.pressed:
					_begin_edit_stroke()
					_edit_at(event.position, true)
				else:
					finish_edit_stroke()
			accept_event()
	elif event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if _panning:
			if selected_tool == "hand" and mode == "edit":
				if event.position.distance_to(_mouse_down) > TAP_MOVE_LIMIT:
					_mouse_dragged = true
					_cancel_pending_settings_tap()
			camera_offset += event.relative
			queue_redraw()
		elif mode == "edit" and selected_tool != "hand" and (_painting or _erasing):
			_edit_at(event.position, _erasing)
		_update_hover(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_positions[event.index] = event.position
			_touch_starts[event.index] = event.position
			if mode == "edit" and _selected_tool_has_properties() and _touch_positions.size() == 1:
				_settings_tool_pressed_id = str(_configurable_at(_screen_to_cell(event.position)).get("id", ""))
			if _touch_positions.size() >= 2:
				_touch_invalid_tap = true
				_settings_tool_pressed_id = ""
				_cancel_pending_settings_tap()
			if mode == "edit" and selected_tool not in ["hand", "message"]:
				if _touch_positions.size() == 1 and not _touch_blocked:
					_begin_edit_stroke()
					_edit_at(event.position, false)
				else:
					_touch_blocked = true
		else:
			var start_point: Vector2 = _touch_starts.get(event.index, event.position)
			var tap_valid: bool = not _touch_invalid_tap and event.position.distance_to(start_point) < TAP_MOVE_LIMIT
			_touch_positions.erase(event.index)
			_touch_starts.erase(event.index)
			if mode == "edit" and selected_tool == "hand" and tap_valid:
				_remember_touch_tap(event.position)
			if mode == "edit" and selected_tool == "message" and tap_valid and _touch_positions.is_empty():
				_request_message_at(event.position)
			if mode == "edit" and _selected_tool_has_properties() and tap_valid and not _settings_tool_pressed_id.is_empty() and _touch_positions.is_empty():
				configurable_entity_tapped.emit("monster" if selected_tool.begins_with("monster:") else selected_tool, _settings_tool_pressed_id)
			if _touch_positions.is_empty():
				_settings_tool_pressed_id = ""
				finish_edit_stroke()
				_touch_blocked = false
				_touch_invalid_tap = false
		_update_hover(event.position)
		accept_event()
	elif event is InputEventScreenDrag:
		if _touch_positions.has(event.index):
			var old_point: Vector2 = _touch_positions[event.index]
			var old_positions := _touch_positions.values()
			_touch_positions[event.index] = event.position
			if mode == "play" or (mode == "edit" and selected_tool == "hand"):
				if _touch_positions.size() == 1:
					var touch_origin: Vector2 = _touch_starts.get(event.index, event.position)
					if event.position.distance_to(touch_origin) > TAP_MOVE_LIMIT:
						_cancel_pending_settings_tap()
					camera_offset += event.position - old_point
					queue_redraw()
				elif _touch_positions.size() >= 2:
					var new_positions := _touch_positions.values()
					var old_a: Vector2 = old_positions[0]
					var old_b: Vector2 = old_positions[1]
					var new_a: Vector2 = new_positions[0]
					var new_b: Vector2 = new_positions[1]
					var old_center := (old_a + old_b) * 0.5
					var new_center := (new_a + new_b) * 0.5
					var old_distance := old_a.distance_to(old_b)
					if old_distance > 20.0:
						zoom_at(old_center, new_a.distance_to(new_b) / old_distance)
					camera_offset += new_center - old_center
					queue_redraw()
			elif mode == "edit" and selected_tool != "message" and not _touch_blocked and _touch_positions.size() == 1:
				_edit_at(event.position, false)
		_update_hover(event.position)
		accept_event()

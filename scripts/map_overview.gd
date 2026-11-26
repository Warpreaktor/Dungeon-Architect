class_name MapOverview
extends Control

## Общий вид исследованной карты: одно представление для окна карты и миникарты.
## Не использует игровую камеру и не раскрывает туман войны.

const CELL_SIZE := 18.0
const WALL_COLOR := Color("#637584")
const FLOOR_COLOR := Color("#283947")
const UNKNOWN_COLOR := Color("#090f17")

var session: GameSession
var miniature: bool = false
var _zoom_factor: float = 1.0
var _pan := Vector2.ZERO
var _dragging: bool = false
var _touches: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if miniature else Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)


func show_session(value: GameSession) -> void:
	session = value
	_zoom_factor = 1.0
	_pan = Vector2.ZERO
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _view_scale() -> float:
	if session == null or session.map_data == null:
		return 1.0
	var data: DungeonMap = session.map_data
	var world := Vector2(data.width, data.height) * CELL_SIZE
	if miniature:
		# Ближний радар вокруг героя, не план всего уровня в 200 пикселях.
		return 0.62
	return maxf(0.001, minf((size.x - 20.0) / world.x, (size.y - 20.0) / world.y)) * _zoom_factor


func _view_offset(scale: float) -> Vector2:
	var data: DungeonMap = session.map_data
	var world := Vector2(data.width, data.height) * CELL_SIZE
	if miniature:
		var hero_center := (Vector2(session.player_pos) + Vector2.ONE * 0.5) * CELL_SIZE
		return size * 0.5 - hero_center * scale
	return (size - world * scale) * 0.5 + _pan


func _draw() -> void:
	if not miniature:
		draw_rect(Rect2(Vector2.ZERO, size), UNKNOWN_COLOR)
	if session == null or session.map_data == null or size.x <= 0.0 or size.y <= 0.0:
		return
	if miniature:
		_draw_minimap_overlay()
		return
	var data: DungeonMap = session.map_data
	var scale := _view_scale()
	var offset := _view_offset(scale)
	var cell_pixels := CELL_SIZE * scale
	var start_x := clampi(floori(-offset.x / cell_pixels) - 1, 0, data.width)
	var start_y := clampi(floori(-offset.y / cell_pixels) - 1, 0, data.height)
	var end_x := clampi(ceili((size.x - offset.x) / cell_pixels) + 1, 0, data.width)
	var end_y := clampi(ceili((size.y - offset.y) / cell_pixels) + 1, 0, data.height)
	draw_set_transform(offset, 0.0, Vector2.ONE * scale)
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			if not session.is_revealed(x, y):
				continue
			var location := Vector2(x, y) * CELL_SIZE
			var rect := Rect2(location, Vector2.ONE * CELL_SIZE)
			var is_wall := data.get_terrain(x, y) == "wall"
			draw_rect(rect, WALL_COLOR if is_wall else FLOOR_COLOR)
			if is_wall:
				continue
			for entity in session.entities_at(x, y):
				if session.is_entity_removed(entity):
					continue
				if session.is_entity_hidden_from_hero(entity):
					continue
				var kind := str(entity.get("type", ""))
				var mark := Color.TRANSPARENT
				match kind:
					"door":
						mark = Color("#c782c8") if session.is_door_trap_visible(entity) else Color("#dfb777")
					"chest":
						if not session.is_chest_open(entity):
							mark = Color("#e49c54")
					"monster":
						mark = Color("#b95059")
					"trap":
						mark = Color("#c782c8")
					"stairs_down":
						mark = Color("#6bca9d")
					"portal", "portal_local":
						mark = Color("#977eff")
				if mark.a > 0.0:
					draw_rect(rect.grow(-CELL_SIZE * 0.26), mark)
	var hero_center := (Vector2(session.player_pos) + Vector2.ONE * 0.5) * CELL_SIZE
	draw_circle(hero_center, CELL_SIZE * 0.38, Color("#111a24"))
	draw_circle(hero_center, CELL_SIZE * 0.27, Color("#75f0d6"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Прозрачная миникарта в духе ARPG: только контуры открытых проходов
# и маркеры замеченных объектов, без закрашенного прямоугольника.
func _draw_minimap_overlay() -> void:
	var data: DungeonMap = session.map_data
	var scale := _view_scale()
	var origin := _view_offset(scale)
	var cell_pixels := CELL_SIZE * scale
	var start_x := maxi(0, floori(-origin.x / cell_pixels) - 1)
	var start_y := maxi(0, floori(-origin.y / cell_pixels) - 1)
	var end_x := mini(data.width, ceili((size.x - origin.x) / cell_pixels) + 1)
	var end_y := mini(data.height, ceili((size.y - origin.y) / cell_pixels) + 1)
	var line_color := Color(0.48, 0.88, 0.99, 0.78)
	var line_width := 1.65
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			if not session.is_revealed(x, y) or data.get_terrain(x, y) == "wall":
				continue
			var top_left := origin + Vector2(x, y) * cell_pixels
			var top_right := top_left + Vector2(cell_pixels, 0.0)
			var bottom_left := top_left + Vector2(0.0, cell_pixels)
			var bottom_right := top_left + Vector2.ONE * cell_pixels
			# Обводим только границы проходов, а не сетку каждой клетки.
			if not _is_open_neighbor(data, x, y - 1):
				draw_line(top_left, top_right, line_color, line_width, true)
			if not _is_open_neighbor(data, x, y + 1):
				draw_line(bottom_left, bottom_right, line_color, line_width, true)
			if not _is_open_neighbor(data, x - 1, y):
				draw_line(top_left, bottom_left, line_color, line_width, true)
			if not _is_open_neighbor(data, x + 1, y):
				draw_line(top_right, bottom_right, line_color, line_width, true)
			for entity in session.entities_at(x, y):
				if session.is_entity_removed(entity) or session.is_entity_hidden_from_hero(entity):
					continue
				var mark := Color.TRANSPARENT
				match str(entity.get("type", "")):
					"monster":
						mark = Color(1.0, 0.38, 0.38, 0.95)
					"chest":
						if not session.is_chest_open(entity):
							mark = Color(1.0, 0.75, 0.32, 0.95)
					"trap":
						mark = Color(0.88, 0.44, 0.88, 0.95)
					"door":
						mark = Color(0.88, 0.44, 0.88, 0.95) if session.is_door_trap_visible(entity) else Color(1.0, 0.77, 0.39, 0.90)
					"stairs_down":
						mark = Color(0.45, 1.0, 0.70, 0.95)
					"portal", "portal_local":
						mark = Color(0.60, 0.47, 1.0, 0.95)
				if mark.a > 0.0:
					draw_circle(top_left + Vector2.ONE * cell_pixels * 0.5, 2.8, mark)
	# Метка героя остаётся в центре, даже если карта намного больше экрана.
	var center := size * 0.5
	draw_circle(center, 5.2, Color(0.02, 0.10, 0.15, 0.9))
	draw_circle(center, 3.5, Color(0.55, 1.0, 0.86, 1.0))


func _is_open_neighbor(data: DungeonMap, x: int, y: int) -> bool:
	return data.contains(x, y) and session.is_revealed(x, y) and data.get_terrain(x, y) != "wall"


func _zoom_at(point: Vector2, factor: float) -> void:
	if miniature or session == null:
		return
	var previous := _view_scale()
	var origin := _view_offset(previous)
	_zoom_factor = clampf(_zoom_factor * factor, 0.6, 10.0)
	var next := _view_scale()
	var next_origin := _view_offset(next)
	# Точка под курсором остаётся на том же месте после масштабирования.
	_pan = point - (point - origin) * (next / previous) - (next_origin - _pan)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if miniature:
		return
	if event is InputEventMouseButton:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, 1.15)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 1.0 / 1.15)
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_pan += event.relative
		queue_redraw()
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		accept_event()
	elif event is InputEventScreenDrag and _touches.has(event.index):
		var old_points: Array = _touches.values()
		var old_position: Vector2 = _touches[event.index]
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_pan += event.position - old_position
		else:
			var new_points: Array = _touches.values()
			var old_a: Vector2 = old_points[0]
			var old_b: Vector2 = old_points[1]
			var new_a: Vector2 = new_points[0]
			var new_b: Vector2 = new_points[1]
			var old_dist := old_a.distance_to(old_b)
			if old_dist > 20.0:
				_zoom_at((old_a + old_b) * 0.5, new_a.distance_to(new_b) / old_dist)
			_pan += (new_a + new_b - old_a - old_b) * 0.5
		queue_redraw()
		accept_event()

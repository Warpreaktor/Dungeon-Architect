class_name DungeonCanvas
extends Control

## Рисование карты и обработка мыши/пальцев. Логика карты живёт в DungeonMap.

signal map_edited
signal hover_changed(cell: Vector2i)

const TILE_SIZE := 48.0
const FLOOR_TEXTURE: Texture2D = preload("res://assets/stone_floor.png")
const WALL_TEXTURE: Texture2D = preload("res://assets/stone_wall.png")

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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	resized.connect(queue_redraw)


func set_map(value: DungeonMap) -> void:
	map_data = value
	game_session = null
	mode = "edit"
	_hovered = Vector2i(-1, -1)
	call_deferred("fit_to_view")
	queue_redraw()


func set_game_session(value: GameSession) -> void:
	game_session = value
	if value != null:
		map_data = value.map_data
		mode = "play"
	else:
		mode = "edit"
	queue_redraw()


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

	if mode == "edit" and map_data.contains(_hovered.x, _hovered.y):
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
		var kind := str(entity["type"])
		if mode == "play" and kind == "player_spawn":
			continue
		_draw_entity(kind, Vector2(x, y) * TILE_SIZE)
	if mode == "play" and not can_see:
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.55))


func _draw_player(origin: Vector2) -> void:
	var center := origin + Vector2.ONE * (TILE_SIZE / 2.0)
	draw_circle(center + Vector2(0, -9), 8.0, Color("#f9fff4"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-14, 17), center + Vector2(-10, 0), center + Vector2(0, -1), center + Vector2(10, 0), center + Vector2(14, 17)]), Color("#8af0c1"))
	draw_rect(Rect2(center + Vector2(-5, 3), Vector2(10, 10)), Color("#1e7463"))
	draw_circle(center + Vector2(14, -12), 4.0, Color("#e8c58a"))


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
		"monster":
			draw_circle(center + Vector2(0, 3), 16.0, Color("#4a1727"))
			draw_circle(center, 13.0, Color("#d95665"))
			draw_colored_polygon(PackedVector2Array([origin + Vector2(11, 16), origin + Vector2(13, 4), origin + Vector2(23, 13)]), Color("#e88079"))
			draw_colored_polygon(PackedVector2Array([origin + Vector2(27, 13), origin + Vector2(36, 4), origin + Vector2(37, 17)]), Color("#e88079"))
			draw_circle(origin + Vector2(19, 24), 3.0, Color("#fff0d3"))
			draw_circle(origin + Vector2(29, 24), 3.0, Color("#fff0d3"))
		"stairs_down":
			draw_rect(Rect2(origin + Vector2(7, 9), Vector2(34, 31)), Color("#172d37"))
			for i in range(4):
				var margin := float(i) * 3.0
				draw_rect(Rect2(origin + Vector2(10 + margin, 10 + i * 7), Vector2(28 - margin * 2, 5)), Color("#5aa7bf").darkened(float(i) * 0.13))
		"key":
			draw_circle(origin + Vector2(18, 15), 7.0, Color("#ffe096"), false, 4.0)
			draw_line(origin + Vector2(22, 20), origin + Vector2(35, 35), Color("#f3ca68"), 5.0)
			draw_line(origin + Vector2(30, 30), origin + Vector2(35, 26), Color("#f3ca68"), 4.0)
		"potion":
			draw_rect(Rect2(origin + Vector2(20, 7), Vector2(8, 10)), Color("#c7b7a2"))
			draw_rect(Rect2(origin + Vector2(13, 18), Vector2(22, 22)), Color("#94c9cc"))
			draw_rect(Rect2(origin + Vector2(15, 24), Vector2(18, 14)), Color("#8a64d1"))
			draw_rect(Rect2(origin + Vector2(18, 10), Vector2(12, 4)), Color("#d8bf89"))
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


func _edit_at(point: Vector2, erase: bool) -> void:
	if mode != "edit" or map_data == null:
		return
	var cell := _screen_to_cell(point)
	if not map_data.contains(cell.x, cell.y):
		return
	var modified := false
	if erase or selected_tool == "erase":
		modified = map_data.erase_at(cell.x, cell.y)
	elif selected_tool in ["floor", "wall"]:
		modified = map_data.set_terrain(cell.x, cell.y, selected_tool)
	else:
		modified = map_data.place_entity(selected_tool, cell.x, cell.y)
	if modified:
		queue_redraw()
		map_edited.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_update_hover(event.position)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(event.position, 1.12)
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(event.position, 1.0 / 1.12)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_LEFT and (_panning or Input.is_key_pressed(KEY_SPACE))):
			_panning = event.pressed
			accept_event()
		elif mode == "edit" and event.button_index == MOUSE_BUTTON_LEFT:
			_painting = event.pressed
			if event.pressed:
				_edit_at(event.position, false)
			accept_event()
		elif mode == "edit" and event.button_index == MOUSE_BUTTON_RIGHT:
			_erasing = event.pressed
			if event.pressed:
				_edit_at(event.position, true)
			accept_event()
		elif mode == "play" and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			grab_focus()
			accept_event()
	elif event is InputEventMouseMotion:
		if _panning:
			camera_offset += event.relative
			queue_redraw()
		elif mode == "edit" and (_painting or _erasing):
			_edit_at(event.position, _erasing)
		_update_hover(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_positions[event.index] = event.position
			if mode == "edit" and _touch_positions.size() == 1:
				_edit_at(event.position, false)
		else:
			_touch_positions.erase(event.index)
		_update_hover(event.position)
		accept_event()
	elif event is InputEventScreenDrag:
		if _touch_positions.has(event.index):
			var old_positions := _touch_positions.values()
			_touch_positions[event.index] = event.position
			if mode == "edit" and _touch_positions.size() == 1:
				_edit_at(event.position, false)
			elif _touch_positions.size() >= 2:
				var new_positions := _touch_positions.values()
				var old_distance: float = (old_positions[0] as Vector2).distance_to(old_positions[1] as Vector2)
				var new_distance: float = (new_positions[0] as Vector2).distance_to(new_positions[1] as Vector2)
				var midpoint: Vector2 = ((new_positions[0] as Vector2) + (new_positions[1] as Vector2)) * 0.5
				if old_distance > 20.0:
					zoom_at(midpoint, new_distance / old_distance)
				camera_offset += event.relative * 0.5
				queue_redraw()
		accept_event()

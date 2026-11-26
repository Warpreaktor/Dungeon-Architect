class_name DungeonCanvas
extends Control

## Рисование карты и обработка мыши/пальцев. Логика карты живёт в DungeonMap.

signal map_edited
signal hover_changed(cell: Vector2i)
signal move_selection_changed(description: String)
signal move_failed
signal placement_rejected(message: String)
signal player_step_finished
signal trap_playback_finished
signal edit_action_committed(before: Dictionary, after: Dictionary)
signal configurable_entity_tapped(kind: String, entity_id: String)
signal message_cell_tapped(cell: Vector2i)
signal ground_loot_tapped(container_id: String)

const TILE_SIZE := 48.0
const FOG_SHADER: Shader = preload("res://shaders/map_fog.gdshader")
const FOG_COLOR := Color("#05080c")
const FLOOR_TEXTURE: Texture2D = preload("res://assets/stone_floor.png")
const WALL_TEXTURE: Texture2D = preload("res://assets/stone_wall.png")
const HIDDEN_MARKER: Texture2D = preload("res://assets/icons/traps/blind_shroud.png")
var _portal_texture: Texture2D = ImageAsset.texture("res://assets/icons/portals/portal_gateway.png")
var _stairs_up_texture: Texture2D = ImageAsset.texture("res://assets/icons/map_objects/stairs_up.png")
var _local_portal_textures: Dictionary = {}
var _monster_icons: Dictionary = {}
var _trap_icons: Dictionary = {}
var _door_trap_icons: Dictionary = {}
var _fog_layer: ColorRect
var _fog_material: ShaderMaterial
var _fog_texture: ImageTexture
var _fog_mask: PackedByteArray = PackedByteArray()
var _fog_mask_size := Vector2i.ZERO

const CHEST_TEXTURE: Texture2D = preload("res://assets/icons/map_objects/chest.png")
const STAIRS_DOWN_TEXTURE: Texture2D = preload("res://assets/icons/map_objects/stairs_down.png")
const DOUBLE_TAP_MS := 400
const TAP_MOVE_LIMIT := 16.0
const PLAY_START_ZOOM := 4.0
const PLAY_MIN_ZOOM := 3.25
const PLAY_VISION_MIN_ZOOM := 2.7
const PLAY_MAX_ZOOM := 4.0
const PLAYER_STEP_SECONDS := 0.30
const DAMAGE_FLASH_IN_SECONDS: float = 0.13
const DAMAGE_FLASH_OUT_SECONDS: float = 0.24
const DAMAGE_FLASH_COLOR: Color = Color(1.0, 0.26, 0.26, 1.0)

var map_data: DungeonMap
var game_session: GameSession
var mode: String = "edit" # edit | play
var reachability_result: Dictionary = {}
var selected_tool: String = "wall"
var developer_interaction_enabled: bool = false
var show_grid: bool = true
var camera_offset := Vector2.ZERO
var zoom: float = 1.0
var _player_visual_cell := Vector2.ZERO
var _player_step_tween: Tween
var _player_flash_tween: Tween
var _player_flash_color: Color = Color.WHITE
var _trap_playback: Tween
var _collapse_cell := Vector2i.ZERO
var _collapse_progress: float = -1.0
var _collapse_axis := Vector2i.ZERO
var _spike_burst_cell := Vector2i.ZERO
var _spike_burst_progress: float = -1.0
var _trap_playback_destination := Vector2i.ZERO

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
	for monster_id in MonsterCatalog.list_ids():
		_monster_icons[monster_id] = MonsterCatalog.get_monster(monster_id).icon
	for legacy_id in MonsterCatalog.LEGACY_IDS:
		_monster_icons[legacy_id] = _monster_icons[MonsterCatalog.resolve_id(legacy_id)]
	for trap_id in TrapCatalog.list_ids():
		var trap: TrapDefinition = TrapCatalog.get_trap(trap_id)
		_trap_icons[trap_id] = trap.icon
		if trap.can_attach_to("door"):
			_door_trap_icons[trap_id] = trap.icon
	for color_id in DungeonMap.PORTAL_COLORS:
		_local_portal_textures[color_id] = ImageAsset.texture("res://assets/icons/portals/portal_%s.png" % color_id)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_fog_material = ShaderMaterial.new()
	_fog_material.shader = FOG_SHADER
	_fog_material.set_shader_parameter("fog_color", FOG_COLOR)
	_fog_layer = ColorRect.new()
	_fog_layer.name = "FogOfWar"
	_fog_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_layer.material = _fog_material
	_fog_layer.hide()
	add_child(_fog_layer)
	resized.connect(_on_canvas_resized)
	_settings_tap_timer = Timer.new()
	_settings_tap_timer.one_shot = true
	_settings_tap_timer.wait_time = float(DOUBLE_TAP_MS) / 1000.0
	_settings_tap_timer.timeout.connect(_on_settings_tap_timeout)
	add_child(_settings_tap_timer)


func _on_canvas_resized() -> void:
	if mode == "play" and game_session != null:
		if _trap_playback != null:
			_update_player_visual_cell(_player_visual_cell)
		else:
			center_on_cell(game_session.player_pos)
	else:
		queue_redraw()


func set_map(value: DungeonMap) -> void:
	var interrupted: bool = _cancel_trap_playback()
	_cancel_player_step()
	_cancel_player_flash()
	reachability_result.clear()
	_stroke_before.clear()
	map_data = value
	game_session = null
	mode = "edit"
	if _fog_layer != null:
		_fog_layer.hide()
	_hovered = Vector2i(-1, -1)
	cancel_move_selection()
	_reset_pointer_state()
	call_deferred("_fit_after_layout")
	queue_redraw()
	if interrupted:
		trap_playback_finished.emit()


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
	var interrupted: bool = _cancel_trap_playback()
	_cancel_player_step()
	_cancel_player_flash()
	reachability_result.clear()
	cancel_move_selection()
	_reset_pointer_state()
	game_session = value
	if _fog_layer != null:
		_fog_layer.hide()
	if value != null:
		map_data = value.map_data
		_player_visual_cell = Vector2(value.player_pos)
		mode = "play"
	else:
		mode = "edit"
	queue_redraw()
	if interrupted:
		trap_playback_finished.emit()


# Дожидаемся размеров контейнера: при первой загрузке прежний deferred fit
# иногда выполнялся до окончательной раскладки интерфейса.
func _fit_after_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if mode == "edit":
		fit_to_view()


## Только отображение шага анимируется: игровая позиция уже обновлена в GameSession.
## Во время Tween новые команды перемещения не принимаются редактором.
func is_player_moving() -> bool:
	return (_player_step_tween != null and _player_step_tween.is_running()) or _trap_playback != null


func animate_player_step(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if mode != "play" or game_session == null or from_cell == to_cell:
		return
	_cancel_player_step()
	if absi(to_cell.x - from_cell.x) + absi(to_cell.y - from_cell.y) > 1:
		_player_visual_cell = Vector2(to_cell)
		center_on_cell(to_cell)
		_player_step_tween = create_tween()
		_player_step_tween.tween_interval(0.01)
		_player_step_tween.finished.connect(_finish_player_step.bind(Vector2(to_cell)))
		return
	_player_visual_cell = Vector2(from_cell)
	_player_step_tween = create_tween()
	_player_step_tween.set_trans(Tween.TRANS_LINEAR)
	_player_step_tween.tween_method(_update_player_visual_cell, Vector2(from_cell), Vector2(to_cell), PLAYER_STEP_SECONDS)
	_player_step_tween.finished.connect(_finish_player_step.bind(Vector2(to_cell)))


func _update_player_visual_cell(cell: Vector2) -> void:
	_player_visual_cell = cell
	var world_center := (_player_visual_cell + Vector2.ONE * 0.5) * TILE_SIZE
	camera_offset = size * 0.5 - world_center * zoom
	queue_redraw()


func _finish_player_step(cell: Vector2) -> void:
	_player_step_tween = null
	_update_player_visual_cell(cell)
	player_step_finished.emit()


func _cancel_player_step() -> void:
	if _player_step_tween != null:
		_player_step_tween.kill()
		_player_step_tween = null


func play_trap_visuals(events: Array[Dictionary], destination: Vector2i) -> bool:
	if mode != "play" or game_session == null or _trap_playback != null:
		return false
	var playback_events: Array[Dictionary] = []
	for event in events:
		var effect: String = str(event.get("effect", ""))
		if effect in ["falling_slab", "spike_burst"] and event.get("cell") is Vector2i:
			playback_events.append({"effect": effect, "cell": event["cell"]})
	if playback_events.is_empty():
		return false
	_cancel_player_step()
	_trap_playback_destination = destination
	_trap_playback = create_tween()
	var visual_cell: Vector2 = _player_visual_cell
	for event in playback_events:
		var cell: Vector2i = event["cell"]
		if visual_cell != Vector2(cell):
			_trap_playback.tween_method(_update_player_visual_cell, visual_cell, Vector2(cell), PLAYER_STEP_SECONDS * 0.65)
		match str(event["effect"]):
			"falling_slab":
				_trap_playback.tween_callback(_begin_collapse.bind(cell))
				_trap_playback.tween_method(_update_collapse, 0.0, 1.0, 0.65)
				_trap_playback.tween_callback(_clear_collapse)
			"spike_burst":
				_trap_playback.tween_callback(_begin_spike_burst.bind(cell))
				_trap_playback.tween_method(_update_spike_burst, 0.0, 1.0, 0.58)
				_trap_playback.tween_callback(_clear_spike_burst)
		visual_cell = Vector2(cell)
	if visual_cell != Vector2(destination):
		_trap_playback.tween_method(_update_player_visual_cell, visual_cell, Vector2(destination), PLAYER_STEP_SECONDS * 0.65)
	_trap_playback.finished.connect(_finish_trap_playback)
	return true


func _begin_collapse(cell: Vector2i) -> void:
	_collapse_cell = cell
	_collapse_axis = map_data.narrow_passage_axis(cell)
	_update_collapse(0.0)


func _update_collapse(progress: float) -> void:
	_collapse_progress = progress
	queue_redraw()


func _clear_collapse() -> void:
	_collapse_progress = -1.0
	queue_redraw()


func _begin_spike_burst(cell: Vector2i) -> void:
	_spike_burst_cell = cell
	_update_spike_burst(0.0)


func _update_spike_burst(progress: float) -> void:
	_spike_burst_progress = progress
	queue_redraw()


func _clear_spike_burst() -> void:
	_spike_burst_progress = -1.0
	queue_redraw()


func skip_trap_playback() -> void:
	if _trap_playback != null:
		_trap_playback.kill()
		_finish_trap_playback()


func _finish_trap_playback() -> void:
	_trap_playback = null
	_clear_collapse()
	_clear_spike_burst()
	_update_player_visual_cell(Vector2(_trap_playback_destination))
	trap_playback_finished.emit()


func _cancel_trap_playback() -> bool:
	var interrupted: bool = _trap_playback != null
	if interrupted:
		_trap_playback.kill()
		_trap_playback = null
	_clear_collapse()
	_clear_spike_burst()
	return interrupted


func flash_player_damage() -> void:
	if mode != "play" or game_session == null:
		return
	_cancel_player_flash()
	_player_flash_tween = create_tween()
	_player_flash_tween.tween_method(_set_player_flash_color, Color.WHITE, DAMAGE_FLASH_COLOR, DAMAGE_FLASH_IN_SECONDS)
	_player_flash_tween.tween_method(_set_player_flash_color, DAMAGE_FLASH_COLOR, Color.WHITE, DAMAGE_FLASH_OUT_SECONDS)
	_player_flash_tween.tween_method(_set_player_flash_color, Color.WHITE, DAMAGE_FLASH_COLOR, DAMAGE_FLASH_IN_SECONDS)
	_player_flash_tween.tween_method(_set_player_flash_color, DAMAGE_FLASH_COLOR, Color.WHITE, DAMAGE_FLASH_OUT_SECONDS)


func _set_player_flash_color(value: Color) -> void:
	_player_flash_color = value
	queue_redraw()


func _cancel_player_flash() -> void:
	if _player_flash_tween != null and _player_flash_tween.is_valid():
		_player_flash_tween.kill()
	_player_flash_tween = null
	_player_flash_color = Color.WHITE


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
	var min_play_zoom := PLAY_MIN_ZOOM
	if game_session != null and game_session.hero != null and game_session.hero.has_vision_effect():
		min_play_zoom = PLAY_VISION_MIN_ZOOM
	var new_zoom := clampf(zoom * factor, min_play_zoom if mode == "play" else 0.2, PLAY_MAX_ZOOM if mode == "play" else 3.5)
	if mode == "play" and game_session != null:
		zoom = new_zoom
		center_on_cell(game_session.player_pos)
	else:
		camera_offset = screen_point - (screen_point - camera_offset) * (new_zoom / zoom)
		zoom = new_zoom
		queue_redraw()


func _draw() -> void:
	var fog_enabled: bool = mode == "play" and game_session != null and not game_session.debug_open_map
	draw_rect(Rect2(Vector2.ZERO, size), FOG_COLOR if fog_enabled else Color("#131a22"))
	if map_data == null:
		_fog_layer.hide()
		return
	var min_x := clampi(floori(-camera_offset.x / (TILE_SIZE * zoom)) - 1, 0, map_data.width)
	var min_y := clampi(floori(-camera_offset.y / (TILE_SIZE * zoom)) - 1, 0, map_data.height)
	var max_x := clampi(ceili((size.x - camera_offset.x) / (TILE_SIZE * zoom)) + 1, 0, map_data.width)
	var max_y := clampi(ceili((size.y - camera_offset.y) / (TILE_SIZE * zoom)) + 1, 0, map_data.height)
	if min_x >= max_x or min_y >= max_y:
		_fog_layer.hide()
		return
	_update_fog(Rect2i(min_x, min_y, max_x - min_x, max_y - min_y))

	var stairs_up_cell := Vector2i(-1, -1)
	if mode == "play" and game_session != null and game_session.has_stairs_up():
		stairs_up_cell = map_data.find_entity_position("player_spawn")
	draw_set_transform(camera_offset, 0.0, Vector2.ONE * zoom)
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			_draw_cell(x, y, stairs_up_cell)

	if mode == "play" and game_session != null and map_data.contains(game_session.player_pos.x, game_session.player_pos.y):
		_draw_player(_player_visual_cell * TILE_SIZE)
		if _player_visual_cell.distance_to(Vector2(game_session.player_pos)) < 0.01:
			for entity in map_data.entities_at(game_session.player_pos.x, game_session.player_pos.y):
				if str(entity.get("type", "")) == "trap" and game_session.is_trap_revealed(entity):
					_draw_triggered_trap_marker(_player_visual_cell * TILE_SIZE, entity)

	if _collapse_progress >= 0.0:
		_draw_collapse()
	if _spike_burst_progress >= 0.0:
		_draw_spike_burst()

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
	if not fog_enabled:
		draw_rect(Rect2(0, 0, map_data.width * TILE_SIZE, map_data.height * TILE_SIZE), Color("#9da5ab"), false, 2.0 / zoom)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_collapse() -> void:
	var center: Vector2 = (Vector2(_collapse_cell) + Vector2.ONE * 0.5) * TILE_SIZE
	var angle: float = PI * 0.5 if _collapse_axis == Vector2i.RIGHT else 0.0
	draw_set_transform(camera_offset + center * zoom, angle, Vector2.ONE * zoom)
	var progress: float = _collapse_progress
	var fall: float = clampf(progress / 0.42, 0.0, 1.0)
	var impact: float = clampf((progress - 0.42) / 0.58, 0.0, 1.0)
	var opacity: float = 1.0 - smoothstep(0.55, 1.0, progress)
	var height: float = lerpf(-28.0, 0.0, fall * fall)
	var fall_offset: Vector2 = Vector2(0.0, height).rotated(-angle)
	var shadow := Rect2(-21.0, -12.0, 42.0, 24.0)
	draw_rect(shadow, Color(0.03, 0.04, 0.06, lerpf(0.18, 0.65, fall) * opacity))
	var top := PackedVector2Array([Vector2(-22, -14), Vector2(15, -14), Vector2(22, -8), Vector2(-16, -8)])
	var face := PackedVector2Array([Vector2(-22, -14), Vector2(-16, -8), Vector2(22, -8), Vector2(22, 12), Vector2(-16, 12), Vector2(-22, 6)])
	for index in face.size():
		face[index] = face[index] + fall_offset
	for index in top.size():
		top[index] = top[index] + fall_offset
	draw_colored_polygon(face, Color(0.32, 0.36, 0.43, opacity))
	draw_colored_polygon(top, Color(0.76, 0.79, 0.83, opacity))
	draw_polyline(PackedVector2Array([Vector2(-5, -8) + fall_offset, Vector2(-10, 1) + fall_offset, Vector2(0, 5) + fall_offset, Vector2(-3, 12) + fall_offset]), Color(0.13, 0.17, 0.23, opacity), 2.0, true)
	if progress >= 0.42:
		for index in range(12):
			var direction := Vector2.from_angle(TAU * float(index) / 12.0)
			var dust_pos: Vector2 = direction * lerpf(8.0, 30.0, impact)
			draw_circle(dust_pos, lerpf(2.0, 5.5, impact), Color(0.69, 0.64, 0.54, (1.0 - impact) * 0.64))
		var ring_alpha: float = (1.0 - impact) * 0.75
		draw_arc(Vector2.ZERO, lerpf(12.0, 29.0, impact), 0.0, TAU, 32, Color(1.0, 0.84, 0.61, ring_alpha), 1.5, true)
	draw_set_transform(camera_offset, 0.0, Vector2.ONE * zoom)


func _draw_spike_burst() -> void:
	var center: Vector2 = (Vector2(_spike_burst_cell) + Vector2.ONE * 0.5) * TILE_SIZE
	draw_set_transform(camera_offset + center * zoom, 0.0, Vector2.ONE * zoom)
	var progress: float = _spike_burst_progress
	var rise: float = smoothstep(0.08, 0.34, progress)
	var retract: float = 1.0 - smoothstep(0.62, 1.0, progress)
	var spike_phase: float = clampf(rise * retract, 0.0, 1.0)
	var impact: float = clampf((progress - 0.26) / 0.74, 0.0, 1.0)
	var glow_alpha: float = (1.0 - smoothstep(0.58, 1.0, progress)) * 0.56
	draw_circle(Vector2.ZERO, lerpf(7.0, 18.0, impact), Color(0.98, 0.24, 0.18, glow_alpha))
	draw_arc(Vector2.ZERO, lerpf(10.0, 28.0, impact), 0.0, TAU, 32, Color(1.0, 0.84, 0.56, (1.0 - impact) * 0.62), 1.7, true)
	var crack_alpha: float = 0.26 + spike_phase * 0.5
	for points in [PackedVector2Array([Vector2(-18, 4), Vector2(-8, 0), Vector2(0, 1), Vector2(9, -4), Vector2(18, -1)]), PackedVector2Array([Vector2(-12, 14), Vector2(-5, 9), Vector2(2, 6), Vector2(8, 10), Vector2(14, 7)]), PackedVector2Array([Vector2(-15, -10), Vector2(-5, -7), Vector2(3, -12), Vector2(12, -9)])]:
		draw_polyline(points, Color(0.18, 0.06, 0.04, crack_alpha), 2.0, true)
	var positions := [-16.0, -8.0, 0.0, 8.0, 16.0]
	for index in positions.size():
		var offset_x: float = positions[index]
		var height: float = lerpf(0.0, 18.0 + float(index % 2) * 5.0 + (6.0 if index == 2 else 0.0), spike_phase)
		var width: float = 5.0 if index == 2 else 4.0
		var base_y: float = 14.0 - height * 0.15
		var spike := PackedVector2Array([Vector2(offset_x - width, 14), Vector2(offset_x, base_y - height), Vector2(offset_x + width, 14)])
		draw_colored_polygon(spike, Color(0.85, 0.87, 0.90, 0.96))
		draw_polyline(PackedVector2Array([Vector2(offset_x - width, 14), Vector2(offset_x, base_y - height), Vector2(offset_x + width, 14)]), Color(0.39, 0.43, 0.46, 0.9), 1.3, true)
		draw_line(Vector2(offset_x, base_y - height), Vector2(offset_x, 13), Color(0.63, 0.66, 0.71, 0.72), 1.0)
	if progress >= 0.22:
		for index in range(10):
			var direction := Vector2.from_angle(TAU * float(index) / 10.0)
			var particle_distance: float = lerpf(5.0, 26.0, impact)
			var particle_radius: float = lerpf(1.0, 3.5, 1.0 - impact * 0.55)
			var tint: Color = Color(0.76, 0.68, 0.53, (1.0 - impact) * 0.72) if index % 2 == 0 else Color(0.93, 0.30, 0.18, (1.0 - impact) * 0.48)
			draw_circle(direction * particle_distance, particle_radius, tint)
	draw_set_transform(camera_offset, 0.0, Vector2.ONE * zoom)


func _update_fog(cells: Rect2i) -> void:
	if mode != "play" or game_session == null or game_session.debug_open_map or not cells.has_area():
		_fog_layer.hide()
		return
	var bounds: Rect2i = cells.grow(1)
	var mask := PackedByteArray()
	mask.resize(bounds.size.x * bounds.size.y * 2)
	var index: int = 0
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			mask[index] = 255 if game_session.is_revealed(x, y) else 0
			mask[index + 1] = 255 if game_session.is_visible(x, y) else 0
			index += 2
	if _fog_texture == null or _fog_mask_size != bounds.size or _fog_mask != mask:
		var image: Image = Image.create_from_data(bounds.size.x, bounds.size.y, false, Image.FORMAT_RG8, mask)
		if _fog_texture == null or _fog_mask_size != bounds.size:
			_fog_texture = ImageTexture.create_from_image(image)
			_fog_material.set_shader_parameter("fog_mask", _fog_texture)
			_fog_material.set_shader_parameter("mask_size", Vector2(bounds.size))
		else:
			_fog_texture.update(image)
		_fog_mask = mask
		_fog_mask_size = bounds.size
	_fog_layer.position = camera_offset + Vector2(cells.position) * TILE_SIZE * zoom
	_fog_layer.size = Vector2(cells.size) * TILE_SIZE * zoom
	_fog_layer.show()


func _draw_cell(x: int, y: int, stairs_up_cell: Vector2i) -> void:
	var rect := Rect2(float(x) * TILE_SIZE, float(y) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	var has_seen := mode != "play" or game_session == null or game_session.is_revealed(x, y)
	if not has_seen:
		draw_rect(rect, FOG_COLOR)
		return
	var is_wall := map_data.get_terrain(x, y) == "wall"
	if is_wall:
		draw_texture_rect(WALL_TEXTURE, rect, false)
	else:
		draw_texture_rect(FLOOR_TEXTURE, rect, false)
	# Полупрозрачный слой анализа виден только автору, не игроку.
	if mode == "edit" and not reachability_result.is_empty() and not is_wall:
		var position := Vector2i(x, y)
		var certain: Dictionary = reachability_result.get("reachable", {})
		var possible: Dictionary = reachability_result.get("possible", {})
		if certain.has(position):
			draw_rect(rect, Color(0.22, 0.78, 0.41, 0.27))
		elif possible.has(position):
			draw_rect(rect, Color(0.24, 0.65, 0.95, 0.30))
		else:
			draw_rect(rect, Color(0.85, 0.25, 0.35, 0.24))
	var entities_here: Array = game_session.entities_at(x, y) if mode == "play" and game_session != null else map_data.entities_at(x, y)
	var has_hidden_entity := false
	var visible_floor_trap: Dictionary = {}
	var drawable_entities: int = 0
	for entity in entities_here:
		if mode == "play" and game_session != null and game_session.is_entity_removed(entity):
			continue
		var kind := str(entity["type"])
		if mode == "play" and (game_session.is_entity_hidden_from_hero(entity) if game_session != null else DungeonMap.is_entity_hidden(entity)):
			continue
		if mode == "play" and kind in ["player_spawn", "trigger", "message"]:
			continue
		drawable_entities += 1
		var origin := Vector2(x, y) * TILE_SIZE
		if kind == "chest" and ((mode == "play" and game_session != null and game_session.is_chest_open(entity)) or (not DungeonMap.chest_is_random(entity) and DungeonMap.chest_contents(entity).is_empty())):
			_draw_open_chest(origin)
		elif kind == "monster":
			var monster_id := str(entity.get("properties", {}).get("monster_id", MonsterCatalog.DEFAULT_MONSTER_ID))
			var icon: Texture2D = _monster_icons.get(monster_id, _monster_icons.get(MonsterCatalog.DEFAULT_MONSTER_ID))
			if icon != null:
				draw_texture_rect(icon, Rect2(origin, Vector2.ONE * TILE_SIZE), false)
		elif kind == "trap":
			_draw_trap(origin, entity, mode == "play" and game_session != null and game_session.is_trap_disarmed(entity))
			if mode == "play" and game_session != null and not game_session.is_trap_disarmed(entity):
				visible_floor_trap = entity
		elif kind == "portal_local":
			var portal_color: String = str(entity.get("properties", {}).get("color", ""))
			var portal_texture: Texture2D = _local_portal_textures.get(portal_color)
			if portal_texture != null:
				draw_texture_rect(portal_texture, Rect2(origin, Vector2.ONE * TILE_SIZE), false)
		else:
			_draw_entity(kind, origin)
			if kind == "door":
				_draw_door_lock(origin, LockCatalog.required_key(entity))
				if mode == "edit" or (game_session != null and game_session.is_door_trap_visible(entity)):
					_draw_door_trap_marker(origin, entity)
		if mode == "edit" and DungeonMap.is_entity_hidden(entity):
			has_hidden_entity = true
	if drawable_entities > 1 and not visible_floor_trap.is_empty():
		_draw_triggered_trap_marker(rect.position, visible_floor_trap)
	if Vector2i(x, y) == stairs_up_cell:
		if _stairs_up_texture != null:
			draw_texture_rect(_stairs_up_texture, rect, false)
	if has_hidden_entity:
		_draw_hidden_marker(rect.position)


func _draw_hidden_marker(origin: Vector2) -> void:
	var marker := Rect2(origin + Vector2(2, 2), Vector2.ONE * 18.0)
	draw_rect(marker, Color("#20202b"))
	draw_texture_rect(HIDDEN_MARKER, marker, false)


## Цветной знак замка виден при редактировании и при прохождении.
func _draw_door_lock(origin: Vector2, lock_id: String) -> void:
	var tint: Color = LockCatalog.color(lock_id)
	draw_rect(Rect2(origin + Vector2(19, 21), Vector2(11, 14)), Color("#1a1b22"))
	draw_arc(origin + Vector2(24.5, 22.5), 4.0, PI, TAU, 10, tint, 2.8)
	draw_rect(Rect2(origin + Vector2(20.5, 25), Vector2(8, 8)), tint)
	draw_circle(origin + Vector2(24.5, 28), 1.3, Color("#24202b"))


func _draw_door_trap_marker(origin: Vector2, door: Dictionary) -> void:
	var attachment: Variant = door.get("properties", {}).get("trap", {})
	if not attachment is Dictionary:
		return
	var icon: Texture2D = _door_trap_icons.get(str(attachment.get("trap_id", "")))
	if icon == null:
		return
	var rect := Rect2(origin + Vector2(1, 1), Vector2(22, 22))
	draw_rect(rect.grow(1), Color("#111b28"))
	var inactive: bool = mode == "play" and game_session != null and game_session.is_trap_disarmed(door)
	draw_texture_rect(icon, rect, false, Color(0.58, 0.63, 0.70, 0.72) if inactive else Color.WHITE)


func _draw_player(origin: Vector2) -> void:
	var icon: Texture2D = game_session.hero.definition.map_icon if game_session != null and game_session.hero != null and game_session.hero.definition != null else null
	if icon != null:
		draw_texture_rect(icon, Rect2(origin, Vector2.ONE * TILE_SIZE), false, _player_flash_color)
		return
	var center := origin + Vector2.ONE * (TILE_SIZE / 2.0)
	draw_circle(center + Vector2(0, -9), 8.0, Color("#f9fff4") * _player_flash_color)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-14, 17), center + Vector2(-10, 0), center + Vector2(0, -1), center + Vector2(10, 0), center + Vector2(14, 17)]), Color("#8af0c1") * _player_flash_color)
	draw_rect(Rect2(center + Vector2(-5, 3), Vector2(10, 10)), Color("#1e7463") * _player_flash_color)
	draw_circle(center + Vector2(14, -12), 4.0, Color("#e8c58a"))


func _trap_icon(entity: Dictionary) -> Texture2D:
	var trap_id := str(entity.get("properties", {}).get("trap_id", TrapCatalog.DEFAULT_TRAP_ID))
	return _trap_icons.get(trap_id, _trap_icons.get(TrapCatalog.DEFAULT_TRAP_ID))


func _draw_triggered_trap_marker(origin: Vector2, entity: Dictionary) -> void:
	var icon := _trap_icon(entity)
	if icon == null:
		return
	var badge := Rect2(origin + Vector2(28, -3), Vector2(23, 23))
	draw_rect(badge.grow(1.0), Color("#eeb978"))
	draw_texture_rect(icon, badge, false)


func _draw_trap(origin: Vector2, entity: Dictionary, disarmed: bool) -> void:
	var icon := _trap_icon(entity)
	if icon == null:
		_draw_entity("trigger", origin)
		return
	var modulate := Color(1, 1, 1, 1)
	if disarmed:
		modulate = Color(0.58, 0.63, 0.70, 0.72)
	draw_texture_rect(icon, Rect2(origin, Vector2.ONE * TILE_SIZE), false, modulate)
	if disarmed:
		var overlay := Rect2(origin + Vector2(4, 4), Vector2(40, 40))
		draw_rect(overlay, Color(0.05, 0.08, 0.12, 0.22))
		draw_line(overlay.position + Vector2(6, 34), overlay.position + Vector2(34, 6), Color("#9fb2c8"), 2.2)
		draw_line(overlay.position + Vector2(8, 36), overlay.position + Vector2(36, 8), Color("#1d2631"), 1.0)


func _draw_open_chest(origin: Vector2) -> void:
	draw_texture_rect(CHEST_TEXTURE, Rect2(origin, Vector2.ONE * TILE_SIZE), false, Color(0.48, 0.48, 0.48, 0.8))


func _draw_entity(kind: String, origin: Vector2) -> void:
	var center := origin + Vector2.ONE * (TILE_SIZE / 2.0)
	match kind:
		"door":
			draw_rect(Rect2(origin + Vector2(11, 5), Vector2(26, 38)), Color("#42291d"))
			draw_rect(Rect2(origin + Vector2(14, 7), Vector2(20, 34)), Color("#b77a3c"))
			draw_line(origin + Vector2(24, 8), origin + Vector2(24, 40), Color("#714222"), 2.0)
			draw_circle(origin + Vector2(30, 26), 2.6, Color("#f3d380"))
		"ground_loot":
			_draw_entity("chest", origin)
			draw_circle(origin + Vector2(37, 12), 5, Color("#e8c58a"))
		"chest":
			draw_texture_rect(CHEST_TEXTURE, Rect2(origin, Vector2.ONE * TILE_SIZE), false)
		"portal":
			if _portal_texture != null:
				draw_texture_rect(_portal_texture, Rect2(origin, Vector2.ONE * TILE_SIZE), false)
		"stairs_down":
			draw_texture_rect(STAIRS_DOWN_TEXTURE, Rect2(origin, Vector2.ONE * TILE_SIZE), false)
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
		if mode == "edit" and selected_tool != "hand":
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


func has_edit_stroke() -> bool:
	return not _stroke_before.is_empty()


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
		if _moving_kind == "trap":
			for entity in map_data.entities_at(_moving_from.x, _moving_from.y):
				if str(entity.get("id", "")) != _moving_id:
					continue
				var trap: TrapDefinition = TrapCatalog.from_entity(entity)
				if trap != null:
					var error: String = map_data.trap_placement_error(trap, cell)
					if not error.is_empty():
						placement_rejected.emit(error)
						return
		var before := capture_edit_state()
		if map_data.move_existing(_moving_kind, _moving_id, _moving_from, cell):
			_cancelled_tap_time = now
			_cancelled_tap_cell = cell
			cancel_move_selection()
			map_edited.emit()
			edit_action_committed.emit(before, capture_edit_state())
			queue_redraw()
		else:
			move_failed.emit()
		return
	if is_double and not (cell == _cancelled_tap_cell and now - _cancelled_tap_time <= DOUBLE_TAP_MS):
		_select_at(cell)


## В режиме «Рука» выбираем верхний на клетке редактируемый объект.
func _configurable_at(cell: Vector2i) -> Dictionary:
	if map_data == null or not map_data.contains(cell.x, cell.y):
		return {}
	var entities := map_data.entities_at(cell.x, cell.y)
	var message_entity: Dictionary = {}
	for i in range(entities.size() - 1, -1, -1):
		var entity: Dictionary = entities[i]
		var kind := str(entity.get("type", ""))
		if kind == "message" and selected_tool == "hand":
			message_entity = entity
			continue
		if kind == "player_spawn" and developer_interaction_enabled and selected_tool == "hand":
			return entity
		if kind in ["chest", "trigger", "message", "monster", "door", "stairs_down", "portal", "trap"] and (selected_tool == "hand" or kind == _settings_tool_kind()):
			return entity
	return message_entity


func _selected_tool_has_properties() -> bool:
	return _settings_tool_kind() in ["chest", "trigger", "door", "stairs_down", "portal", "monster", "trap"]


func _settings_tool_kind() -> String:
	if selected_tool.begins_with("monster:"):
		return "monster"
	if selected_tool.begins_with("trap:"):
		var definition: TrapDefinition = TrapCatalog.get_trap(selected_tool.trim_prefix("trap:"))
		return "trap" if definition.can_attach_to("floor") else ""
	return selected_tool


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
	_begin_edit_stroke()
	var modified := false
	if erase or selected_tool == "erase":
		modified = map_data.erase_at(cell.x, cell.y)
	elif selected_tool in ["floor", "wall"]:
		modified = map_data.set_terrain(cell.x, cell.y, selected_tool)
	elif selected_tool == "chest":
		modified = map_data.place_entity("chest", cell.x, cell.y)
	elif selected_tool.begins_with("monster:"):
		var monster_id: String = selected_tool.trim_prefix("monster:")
		if MonsterCatalog.has(monster_id):
			modified = map_data.place_entity("monster", cell.x, cell.y, {"monster_id": monster_id})
	elif selected_tool.begins_with("portal_local:"):
		var color_id: String = selected_tool.trim_prefix("portal_local:")
		modified = map_data.place_entity("portal_local", cell.x, cell.y, {"color": color_id})
	elif selected_tool.begins_with("trap:"):
		var trap_id: String = selected_tool.trim_prefix("trap:")
		if TrapCatalog.has(trap_id):
			var trap: TrapDefinition = TrapCatalog.get_trap(trap_id)
			if trap.can_attach_to("door"):
				for entity in map_data.entities_at(cell.x, cell.y):
					if str(entity.get("type", "")) == "door":
						modified = map_data.attach_door_trap(str(entity["id"]), trap_id)
						break
			elif trap.can_attach_to("floor"):
				var error: String = map_data.trap_placement_error(trap, cell)
				if not error.is_empty():
					placement_rejected.emit(error)
					return
				modified = map_data.place_entity("trap", cell.x, cell.y, {"trap_id": trap_id})
	elif selected_tool not in ["key", "potion", "gold", "sword"]:
		# Подбираемые вещи появляются только через источники добычи (пока сундуки).
		modified = map_data.place_entity(selected_tool, cell.x, cell.y)
	if modified:
		queue_redraw()
		map_edited.emit()


func _request_ground_loot_at(point: Vector2) -> void:
	if mode != "play" or game_session == null:
		return
	var cell: Vector2i = _screen_to_cell(point)
	if not game_session.is_visible(cell.x, cell.y):
		return
	var container: Dictionary = game_session.ground_container_at(cell)
	if not container.is_empty():
		ground_loot_tapped.emit(str(container["id"]))


func _gui_input(event: InputEvent) -> void:
	if _trap_playback != null:
		accept_event()
		return
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
			_panning = event.pressed if mode == "edit" else false
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
						configurable_entity_tapped.emit(_settings_tool_kind(), _settings_tool_pressed_id)
					_settings_tool_pressed_id = ""
				accept_event()
			elif mode == "play":
				if event.pressed:
					_mouse_down = event.position
					grab_focus()
				elif event.position.distance_to(_mouse_down) < TAP_MOVE_LIMIT:
					_request_ground_loot_at(event.position)
				accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if mode == "play":
				# В игре камера следует за героем; свободный обзор — в экране карты.
				_panning = false
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
			if mode == "play" and tap_valid and _touch_positions.is_empty():
				_request_ground_loot_at(event.position)
			if mode == "edit" and selected_tool == "hand" and tap_valid:
				_remember_touch_tap(event.position)
			if mode == "edit" and selected_tool == "message" and tap_valid and _touch_positions.is_empty():
				_request_message_at(event.position)
			if mode == "edit" and _selected_tool_has_properties() and tap_valid and not _settings_tool_pressed_id.is_empty() and _touch_positions.is_empty():
				configurable_entity_tapped.emit(_settings_tool_kind(), _settings_tool_pressed_id)
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
			if mode == "play":
				# Одним пальцем карту не сдвигаем. Два пальца меняют только масштаб.
				if _touch_positions.size() >= 2:
					var new_positions := _touch_positions.values()
					var old_a: Vector2 = old_positions[0]
					var old_b: Vector2 = old_positions[1]
					var new_a: Vector2 = new_positions[0]
					var new_b: Vector2 = new_positions[1]
					var old_distance := old_a.distance_to(old_b)
					if old_distance > 20.0:
						zoom_at(size * 0.5, new_a.distance_to(new_b) / old_distance)
			elif mode == "edit" and selected_tool == "hand":
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

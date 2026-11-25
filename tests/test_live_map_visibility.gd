extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := GameSession.new()
	session.map_data = DungeonMap.create_blank(DungeonMap.MAX_SIZE, DungeonMap.MAX_SIZE)
	session.hero = HeroState.new()
	session.player_pos = Vector2i(2, 2)
	session._init_masks()
	session._refresh_visibility()
	var far := Vector2i(session.map_data.width - 1, session.map_data.height - 1)
	assert(not session.is_revealed(far.x, far.y))
	session.set_debug_open_map(true)
	assert(session.is_revealed(far.x, far.y))
	assert(session.is_visible(far.x, far.y))
	session.set_debug_open_map(false)
	assert(not session.is_revealed(far.x, far.y))
	assert(not session.is_visible(far.x, far.y))
	assert(session.is_revealed(session.player_pos.x, session.player_pos.y))
	session.player_pos = Vector2i(30, 30)
	session._refresh_visibility()
	assert(not session.is_visible(2, 2) and session.is_revealed(2, 2))
	_assert_visibility(session)
	session.hero.vision_bonus = 1
	session.hero.vision_phases = 2
	session._refresh_visibility()
	assert(session.is_visible(32, 30))
	_assert_visibility(session)
	session.hero.vision_phases = 0
	session._refresh_visibility()
	assert(not session.is_visible(32, 30) and session.is_revealed(32, 30))
	_assert_visibility(session)
	session.set_debug_open_map(true)
	session.player_pos = Vector2i(0, 0)
	session._refresh_visibility()
	assert(session.is_visible(far.x, far.y))
	session.set_debug_open_map(false)
	assert(session.is_revealed(0, 0) and session.is_revealed(30, 30))
	assert(not session.is_revealed(far.x, far.y))
	_assert_visibility(session)
	session.map_data = DungeonMap.create_blank(4, 4)
	session.player_pos = Vector2i(3, 3)
	session._init_masks()
	session._refresh_visibility()
	_assert_visibility(session)
	_test_fog_layer()
	print("Live open-map setting restores exploration mask OK")
	quit()


func _assert_visibility(session: GameSession) -> void:
	var radius: int = GameSession.VISION_RADIUS + (session.hero.vision_bonus if session.hero.has_vision_effect() else 0)
	for y in range(session.map_data.height):
		for x in range(session.map_data.width):
			var expected: bool = absi(x - session.player_pos.x) <= radius and absi(y - session.player_pos.y) <= radius
			assert(session.is_visible(x, y) == expected)
			assert(not expected or session.is_revealed(x, y))


func _test_fog_layer() -> void:
	var session := GameSession.new()
	session.map_data = DungeonMap.create_blank(12, 12)
	session.hero = HeroState.new()
	session.player_pos = Vector2i(2, 2)
	session._init_masks()
	session._refresh_visibility()
	session.player_pos = Vector2i(3, 2)
	session._refresh_visibility()
	var canvas := DungeonCanvas.new()
	root.add_child(canvas)
	canvas.set_game_session(session)
	canvas.zoom = 3.5
	canvas.camera_offset = Vector2(-80.0, 12.0)
	var cells := Rect2i(2, 1, 4, 3)
	canvas._update_fog(cells)
	assert(canvas._fog_layer.visible)
	assert(canvas._fog_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(canvas._fog_mask_size == cells.size + Vector2i(2, 2))
	assert(canvas._fog_mask.size() == 60)
	assert(canvas._fog_layer.position.is_equal_approx(canvas.camera_offset + Vector2(cells.position) * DungeonCanvas.TILE_SIZE * canvas.zoom))
	assert(canvas._fog_layer.size.is_equal_approx(Vector2(cells.size) * DungeonCanvas.TILE_SIZE * canvas.zoom))
	var bounds: Rect2i = cells.grow(1)
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var index: int = ((y - bounds.position.y) * bounds.size.x + x - bounds.position.x) * 2
			assert(canvas._fog_mask[index] == (255 if session.is_revealed(x, y) else 0))
			assert(canvas._fog_mask[index + 1] == (255 if session.is_visible(x, y) else 0))
	# Исследованная, видимая и неизвестная клетки сохраняют разные состояния.
	assert(canvas._fog_mask.slice(24, 26) == PackedByteArray([255, 0]))
	assert(canvas._fog_mask.slice(28, 30) == PackedByteArray([255, 255]))
	assert(canvas._fog_mask.slice(32, 34) == PackedByteArray([0, 0]))
	var original_texture: ImageTexture = canvas._fog_texture
	var original_mask: PackedByteArray = canvas._fog_mask.duplicate()
	canvas.camera_offset += Vector2(10, -5)
	canvas._update_fog(cells)
	assert(canvas._fog_texture == original_texture)
	assert(canvas._fog_mask == original_mask)
	assert(canvas._fog_layer.position.is_equal_approx(canvas.camera_offset + Vector2(cells.position) * DungeonCanvas.TILE_SIZE * canvas.zoom))
	session.hero.vision_bonus = 1
	session.hero.vision_phases = 2
	session._refresh_visibility()
	canvas._update_fog(cells)
	assert(canvas._fog_texture == original_texture)
	assert(canvas._fog_mask != original_mask)
	session.set_debug_open_map(true)
	canvas._update_fog(cells)
	assert(not canvas._fog_layer.visible)
	session.set_debug_open_map(false)
	canvas._update_fog(Rect2i(0, 0, 2, 2))
	assert(canvas._fog_layer.visible)
	assert(canvas._fog_mask_size == Vector2i(4, 4))
	assert(canvas._fog_mask.slice(0, 8) == PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0]))
	canvas.set_game_session(null)
	assert(not canvas._fog_layer.visible)
	canvas._update_fog(cells)
	assert(not canvas._fog_layer.visible)
	canvas.queue_free()

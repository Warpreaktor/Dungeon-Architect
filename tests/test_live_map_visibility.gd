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
	print("Live open-map setting restores exploration mask OK")
	quit()


func _assert_visibility(session: GameSession) -> void:
	var radius: int = GameSession.VISION_RADIUS + (session.hero.vision_bonus if session.hero.has_vision_effect() else 0)
	for y in range(session.map_data.height):
		for x in range(session.map_data.width):
			var expected: bool = absi(x - session.player_pos.x) <= radius and absi(y - session.player_pos.y) <= radius
			assert(session.is_visible(x, y) == expected)
			assert(not expected or session.is_revealed(x, y))

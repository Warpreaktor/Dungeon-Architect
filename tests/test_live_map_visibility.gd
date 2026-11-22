extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := GameSession.new()
	session.map_data = DungeonMap.create_blank()
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
	print("Live open-map setting restores exploration mask OK")
	quit()

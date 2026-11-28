extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var hero := HeroCatalog.get_hero("volcha")
	assert(hero.map_icon != null)
	assert(hero.map_icon.resource_path == "res://assets/heroes/volcha_map.png")
	var image := hero.map_icon.get_image()
	assert(image != null and image.get_width() == image.get_height())
	assert(image.get_pixel(0, 0).a == 0.0)
	assert(is_equal_approx(DungeonCanvas.PLAYER_STEP_SECONDS, 0.5))

	var dungeon := DungeonMap.create_blank(9, 9)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	var session := GameSession.start_for(dungeon, "volcha")
	assert(session != null)
	var canvas := DungeonCanvas.new()
	canvas.size = Vector2(640, 480)
	root.add_child(canvas)
	canvas.set_game_session(session)
	var origin := session.player_pos
	assert(session.move_by(-1, 0))
	canvas.animate_player_step(origin, session.player_pos)
	assert(canvas.is_player_moving())
	assert(canvas._player_visual_cell == Vector2(origin))
	await canvas.player_step_finished
	assert(not canvas.is_player_moving())
	assert(canvas._player_visual_cell == Vector2(session.player_pos))

	origin = session.player_pos
	session.player_pos = Vector2i(6, 6)
	canvas.animate_player_step(origin, session.player_pos)
	assert(canvas._player_visual_cell == Vector2(session.player_pos))
	await canvas.player_step_finished
	assert(not canvas.is_player_moving())
	canvas.queue_free()
	print("Hero map token: OK")
	quit()

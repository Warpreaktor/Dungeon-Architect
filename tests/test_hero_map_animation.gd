extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var hero := HeroCatalog.get_hero("volcha")
	assert(hero.map_rig_scene != null and hero.map_sprite_frames == null)
	assert(hero.map_icon != null)
	var rig := hero.map_rig_scene.instantiate() as HeroMapRig
	assert(rig != null)
	root.add_child(rig)
	assert(rig.skeleton.get_bone_count() == 17)
	assert(rig.animation_player.has_animation(&"idle"))
	assert(rig.animation_player.has_animation(&"walk"))
	assert(is_equal_approx(DungeonCanvas.PLAYER_STEP_SECONDS, 0.5))
	rig.start_walk(Vector2.LEFT, DungeonCanvas.PLAYER_STEP_SECONDS)
	assert(rig.skeleton.transform.x.x < 0.0)
	assert(rig.animation_player.current_animation == &"walk")
	assert(is_equal_approx(rig.animation_player.get_playing_speed(), 1.0))
	rig.start_walk(Vector2.UP, DungeonCanvas.PLAYER_STEP_SECONDS * 0.65)
	assert(rig.skeleton.transform.x.x < 0.0)
	assert(rig.animation_player.get_playing_speed() > 1.0)
	rig.stop_walk()
	assert(rig.animation_player.current_animation == &"idle")
	rig.start_walk(Vector2.RIGHT, DungeonCanvas.PLAYER_STEP_SECONDS)
	assert(rig.skeleton.transform.x.x > 0.0)
	rig.queue_free()
	assert(HeroCatalog.get_hero("petushan").map_rig_scene == null)

	var dungeon := DungeonMap.create_blank(9, 9)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	var session := GameSession.start_for(dungeon, "volcha")
	assert(session != null)
	var canvas := DungeonCanvas.new()
	canvas.size = Vector2(640, 480)
	root.add_child(canvas)
	canvas.set_game_session(session)
	assert(canvas._player_rig != null)
	var origin := session.player_pos
	session.player_pos += Vector2i.LEFT
	canvas.animate_player_step(origin, session.player_pos)
	assert(canvas._player_rig.animation_player.current_animation == &"walk")
	await canvas.player_step_finished
	assert(canvas._player_rig.animation_player.current_animation == &"idle")
	assert(canvas._player_visual_cell == Vector2(session.player_pos))
	origin = session.player_pos
	session.player_pos = Vector2i(6, 6)
	canvas.animate_player_step(origin, session.player_pos)
	assert(canvas._player_rig.animation_player.current_animation == &"idle")
	await canvas.player_step_finished
	assert(canvas._player_visual_cell == Vector2(session.player_pos))
	canvas.set_game_session(GameSession.start_for(dungeon, "petushan"))
	assert(canvas._player_rig == null)
	canvas.set_map(dungeon)
	assert(canvas._player_rig_viewport == null)
	canvas.queue_free()
	print("Hero map rig: OK")
	quit()

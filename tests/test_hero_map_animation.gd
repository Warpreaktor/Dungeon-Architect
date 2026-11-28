extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var hero := HeroCatalog.get_hero("volcha")
	var frames: SpriteFrames = hero.map_sprite_frames
	assert(frames != null)
	assert(hero.map_icon != null)
	assert(hero.map_icon.get_width() == 256 and hero.map_icon.get_height() == 256)
	assert(hero.map_icon.get_image().get_pixel(0, 0).a == 0.0)
	for row in range(3):
		var suffix: String = ["up", "down", "right"][row]
		var walk := StringName("walk_" + suffix)
		var idle := StringName("idle_" + suffix)
		assert(frames.get_frame_count(walk) == 6)
		assert(frames.get_frame_count(idle) == 2)
		assert(is_equal_approx(frames.get_animation_speed(idle), 5.0))
		for index in range(6):
			var frame := frames.get_frame_texture(walk, index) as AtlasTexture
			assert(frame != null and frame.region == Rect2((index + 1) * 256, row * 256, 256, 256))
		for index in range(2):
			var frame := frames.get_frame_texture(idle, index) as AtlasTexture
			assert(frame != null and frame.region == Rect2(index * 7 * 256, row * 256, 256, 256))
	assert(is_equal_approx(DungeonCanvas.PLAYER_STEP_SECONDS, 0.5))
	var animation := HeroMapAnimation.new()
	assert(animation.configure(frames))
	assert(animation.texture() == frames.get_frame_texture(&"idle_down", 0))
	assert(is_equal_approx(frames.get_animation_speed(&"idle_down"), 5.0))
	assert(animation.advance(0.21))
	assert(animation.frame_index == 1)
	for direction in [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]:
		animation.start_walk(direction)
		var suffix: String = "down" if direction == Vector2.DOWN else ("up" if direction == Vector2.UP else "right")
		assert(animation.animation == StringName("walk_" + suffix))
		assert(animation.mirrored == (direction == Vector2.LEFT))
		assert(is_equal_approx(frames.get_animation_speed(animation.animation), 12.0))
		var cycle_seconds: float = 0.0
		for index in range(frames.get_frame_count(animation.animation)):
			cycle_seconds += frames.get_frame_duration(animation.animation, index) / frames.get_animation_speed(animation.animation)
		assert(is_equal_approx(cycle_seconds, DungeonCanvas.PLAYER_STEP_SECONDS))
		assert(animation.advance(0.09) and animation.frame_index == 1)
		assert(animation.advance(0.34) and animation.frame_index == 5)
		assert(animation.advance(0.08) and animation.frame_index == 0)
		animation.stop_walk()
		assert(animation.animation == StringName("idle_" + suffix))
		assert(animation.mirrored == (direction == Vector2.LEFT))
		assert(animation.frame_index == 0)
	assert(animation.configure(null))
	assert(animation.texture() == null and not animation.advance(1.0))
	assert(HeroCatalog.get_hero("petushan").map_sprite_frames == null)

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
	assert(canvas._player_animation.animation == &"walk_right" and canvas._player_animation.mirrored)
	await canvas.player_step_finished
	assert(canvas._player_animation.animation == &"idle_right" and canvas._player_animation.mirrored)
	assert(canvas._player_visual_cell == Vector2(session.player_pos))
	origin = session.player_pos
	session.player_pos = Vector2i(6, 6)
	canvas.animate_player_step(origin, session.player_pos)
	assert(canvas._player_animation.animation == &"idle_right")
	await canvas.player_step_finished
	assert(canvas._player_visual_cell == Vector2(session.player_pos))
	canvas.set_game_session(GameSession.start_for(dungeon, "petushan"))
	assert(canvas._player_animation.texture() == null)
	canvas.set_map(dungeon)
	assert(canvas._player_animation.texture() == null)
	canvas.queue_free()
	print("Hero map animation: OK")
	quit()

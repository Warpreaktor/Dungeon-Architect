extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition := MonsterCatalog.get_monster("skeleton")
	assert(definition.map_rig_scene != null)
	var rig := definition.map_rig_scene.instantiate() as MapCharacterRig
	assert(rig != null)
	root.add_child(rig)
	assert(rig.skeleton.get_bone_count() >= 14)
	assert(is_equal_approx(rig.skeleton.position.x, rig.render_size.x * 0.5))
	assert(rig.animation_player.has_animation(&"idle"))
	assert(rig.animation_player.has_animation(&"walk"))
	rig.start_walk(Vector2.LEFT, 0.5)
	assert(rig.skeleton.transform.x.x < 0.0)
	var body := rig.get_node("Skeleton2D/Body") as Bone2D
	var hip := rig.get_node("Skeleton2D/NearHip") as Bone2D
	var rotation_before := hip.rotation
	rig.animation_player.seek(0.125, true)
	assert(not is_equal_approx(hip.rotation, rotation_before))
	assert(body.rotation > 0.0)
	rig.start_walk(Vector2.UP, 0.25)
	assert(rig.skeleton.transform.x.x < 0.0)
	assert(is_equal_approx(rig.animation_player.get_playing_speed(), 2.0))
	rig.stop_walk()
	assert(rig.animation_player.current_animation == &"idle")
	rig.start_walk(Vector2.RIGHT, 0.5)
	assert(rig.skeleton.transform.x.x > 0.0)
	rig.queue_free()

	var dungeon := DungeonMap.create_blank(9, 9)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("monster", 3, 2, {"monster_id": "skeleton"}))
	assert(dungeon.place_entity("monster", 2, 3, {"monster_id": "skeleton"}))
	assert(dungeon.place_entity("monster", 3, 3, {"monster_id": "hunter"}))
	var first: Dictionary = dungeon.entities_at(3, 2)[0]
	var second: Dictionary = dungeon.entities_at(2, 3)[0]
	var hunter: Dictionary = dungeon.entities_at(3, 3)[0]
	var session := GameSession.start_for(dungeon, "volcha")
	assert(session != null)
	var canvas := DungeonCanvas.new()
	canvas.size = Vector2(640, 480)
	root.add_child(canvas)
	canvas.set_game_session(session)
	assert(canvas._monster_rig_viewports.size() == 1)
	var viewport: SubViewport = canvas._monster_rig_viewports[definition.map_rig_scene]
	assert(viewport.size == Vector2i(256, 256))
	assert(canvas._monster_map_texture(first) == viewport.get_texture())
	assert(canvas._monster_map_texture(second) == viewport.get_texture())
	assert(canvas._monster_map_texture(hunter) == MonsterCatalog.get_monster("hunter").icon)
	assert(canvas._monster_map_texture({"properties": {"monster_id": "skeleton_guard"}}) == viewport.get_texture())
	assert(canvas._player_rig != null and canvas._player_rig_viewport != viewport)
	session.removed_entities[str(first["id"])] = true
	assert(session.is_entity_removed(first))
	assert(not session.is_entity_removed(second))
	canvas.set_map(dungeon)
	assert(canvas._monster_rig_viewports.is_empty())
	assert(canvas._monster_map_texture(first) == definition.icon)
	canvas.set_game_session(session)
	assert(canvas._monster_rig_viewports.size() == 1)
	canvas.set_game_session(null)
	assert(canvas._monster_rig_viewports.is_empty())
	canvas.queue_free()
	await process_frame
	print("Monster map rig: OK")
	quit()

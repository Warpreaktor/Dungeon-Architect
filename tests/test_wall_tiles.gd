extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var center := Vector2i(3, 3)
	var data: DungeonMap = DungeonMap.create_blank(7, 7)
	assert(data.set_terrain(center.x, center.y, "wall"))
	assert(WallTiles.TILE_SET.get_terrain_set_mode(0) == TileSet.TERRAIN_MODE_MATCH_SIDES)
	assert(WallTiles.atlas().get_tiles_count() == 16)
	for mask in range(16):
		for index in range(4):
			var neighbor: Vector2i = center + WallTiles.SIDES[index]
			data.set_terrain(neighbor.x, neighbor.y, "wall" if mask & (1 << index) else "floor")
		assert(WallTiles.connection_mask(data, center) == mask)
		var coords := Vector2i(mask & 3, mask >> 2)
		assert(WallTiles.atlas_coords(data, center) == coords)
		assert(WallTiles.texture_region(data, center) == Rect2i(coords * 256, Vector2i(256, 256)))
	# Угол внешней границы не соединяется с клетками за картой.
	assert(WallTiles.connection_mask(data, Vector2i.ZERO) == 6)
	var canvas := DungeonCanvas.new()
	root.add_child(canvas)
	canvas.map_data = data
	var before := canvas.capture_edit_state()
	assert(data.erase_at(3, 2))
	assert(WallTiles.connection_mask(data, center) == 14)
	assert(data.set_terrain(4, 3, "floor"))
	assert(WallTiles.connection_mask(data, center) == 12)
	assert(data.move_existing("wall", "", Vector2i(3, 4), Vector2i(4, 4)))
	assert(WallTiles.connection_mask(data, center) == 8)
	canvas.restore_edit_state(before)
	assert(WallTiles.connection_mask(data, center) == 15)
	assert(WallTiles.connection_mask(data, Vector2i(3, 2)) == 4)
	var restored := DungeonMap.from_dict(JSON.parse_string(JSON.stringify(data.to_dict())))
	assert(restored != null and restored.terrain == data.terrain)
	assert(WallTiles.atlas_coords(restored, center) == Vector2i(3, 3))
	assert(MapPreview.make_preview(restored) != null)
	canvas.queue_free()
	print("Wall terrain connections: OK")
	quit()

extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := DungeonMap.create_blank(32, 32)
	data.map_id = "map_floor_variations"
	var atlas: TileSetAtlasSource = FloorTiles.atlas()
	assert(atlas.get_tiles_count() == 8)
	var expected: Dictionary = {}
	for index in range(atlas.get_tiles_count()):
		expected[atlas.get_tile_texture_region(atlas.get_tile_id(index))] = true
	var used: Dictionary = {}
	var layout: Dictionary = {}
	for y in range(data.height):
		for x in range(data.width):
			var cell := Vector2i(x, y)
			var region: Rect2i = FloorTiles.texture_region(data, cell)
			assert(expected.has(region))
			layout[cell] = region
			used[region] = true
	assert(used.size() == expected.size())
	var cell := Vector2i(4, 4)
	var before: Rect2i = layout[cell]
	assert(data.set_terrain(cell.x, cell.y, "wall"))
	assert(FloorTiles.texture_region(data, cell) == before)
	assert(data.set_terrain(cell.x, cell.y, "floor"))
	var restored := DungeonMap.from_dict(JSON.parse_string(JSON.stringify(data.to_dict())))
	assert(restored != null)
	for point in layout:
		assert(FloorTiles.texture_region(restored, point) == layout[point])
	var preview := MapPreview.make_preview(restored)
	assert(preview != null)
	assert(preview.get_image().get_data() == MapPreview.make_preview(data).get_image().get_data())
	restored.map_id = OfficialCampaignLibrary.ID_PREFIX + data.map_id
	for point in layout:
		assert(FloorTiles.texture_region(restored, point) == layout[point])
	seed(12345)
	var next_random: int = randi()
	seed(12345)
	assert(FloorTiles.texture_region(data, cell) == before)
	assert(randi() == next_random)
	print("Floor tile variations: OK")
	quit()

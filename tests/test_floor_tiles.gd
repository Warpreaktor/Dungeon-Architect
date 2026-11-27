extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := DungeonMap.create_blank(32, 32)
	data.map_id = "map_floor_variations"
	var atlas: TileSetAtlasSource = FloorTiles.atlas()
	assert(atlas.get_tiles_count() == 20)
	assert(atlas.texture_region_size == Vector2i(256, 256))
	assert(atlas.texture.get_size() == Vector2(1280, 1024))
	for y in range(4):
		for x in range(5):
			assert(atlas.has_tile(Vector2i(x, y)))
	var expected: Dictionary = {}
	for index in range(atlas.get_tiles_count()):
		expected[atlas.get_tile_texture_region(atlas.get_tile_id(index))] = true
	var layout: Dictionary = {}
	for y in range(data.height):
		for x in range(data.width):
			var cell := Vector2i(x, y)
			var region: Rect2i = FloorTiles.texture_region(data, cell)
			assert(expected.has(region))
			layout[cell] = region
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
	_test_weighted_distribution(data, atlas)
	await _test_probability_changes(data, atlas)
	print("Floor tile variations: OK")
	quit()


func _test_weighted_distribution(data: DungeonMap, atlas: TileSetAtlasSource) -> void:
	var weights: Dictionary = {}
	var total: float = 0.0
	for index in range(atlas.get_tiles_count()):
		var coords: Vector2i = atlas.get_tile_id(index)
		var weight: float = atlas.get_tile_data(coords, 0).probability
		weights[atlas.get_tile_texture_region(coords)] = weight
		total += weight
	assert(total > 0.0)
	var counts: Dictionary = {}
	var side := 128
	for y in range(side):
		for x in range(side):
			var region: Rect2i = FloorTiles.texture_region(data, Vector2i(x, y))
			counts[region] = int(counts.get(region, 0)) + 1
	for region in weights:
		var expected: float = float(weights[region]) / total
		var actual: float = float(counts.get(region, 0)) / float(side * side)
		assert(absf(actual - expected) <= maxf(0.003, expected * 0.15))


func _test_probability_changes(data: DungeonMap, atlas: TileSetAtlasSource) -> void:
	var weights: Dictionary = {}
	var chosen := Vector2i(1, 0)
	for index in range(atlas.get_tiles_count()):
		var coords: Vector2i = atlas.get_tile_id(index)
		var tile: TileData = atlas.get_tile_data(coords, 0)
		weights[coords] = tile.probability
		tile.probability = 1.0 if coords == chosen else 0.0
	await process_frame
	var expected: Rect2i = atlas.get_tile_texture_region(chosen)
	for y in range(8):
		for x in range(8):
			assert(FloorTiles.texture_region(data, Vector2i(x, y)) == expected)
	atlas.get_tile_data(chosen, 0).probability = 0.0
	await process_frame
	assert(FloorTiles.texture_region(data, Vector2i.ZERO) == atlas.get_tile_texture_region(Vector2i.ZERO))
	for coords in weights:
		atlas.get_tile_data(coords, 0).probability = weights[coords]
	await process_frame
	_test_weighted_distribution(data, atlas)

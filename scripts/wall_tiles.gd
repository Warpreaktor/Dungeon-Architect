class_name WallTiles
extends RefCounted

const TILE_SET: TileSet = preload("res://assets/tilesets/stone_walls.tres")
const SIDES := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const PEERING_BITS := [TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_LEFT_SIDE]
const SOURCE_ID := 0

static var _tiles_by_mask: Dictionary = {}


static func atlas() -> TileSetAtlasSource:
	return TILE_SET.get_source(SOURCE_ID) as TileSetAtlasSource


static func connection_mask(data: DungeonMap, cell: Vector2i) -> int:
	var mask: int = 0
	for index in range(SIDES.size()):
		var neighbor: Vector2i = cell + SIDES[index]
		if data.contains(neighbor.x, neighbor.y) and data.get_terrain(neighbor.x, neighbor.y) == "wall":
			mask |= 1 << index
	return mask


static func atlas_coords(data: DungeonMap, cell: Vector2i) -> Vector2i:
	if _tiles_by_mask.is_empty():
		_index_tiles()
	return _tiles_by_mask[connection_mask(data, cell)]


static func texture_region(data: DungeonMap, cell: Vector2i) -> Rect2i:
	return atlas().get_tile_texture_region(atlas_coords(data, cell))


static func _index_tiles() -> void:
	var source: TileSetAtlasSource = atlas()
	for index in range(source.get_tiles_count()):
		var coords: Vector2i = source.get_tile_id(index)
		var tile: TileData = source.get_tile_data(coords, 0)
		if tile.terrain_set != 0 or tile.terrain != 0:
			continue
		var mask: int = 0
		for side in range(PEERING_BITS.size()):
			if tile.get_terrain_peering_bit(PEERING_BITS[side]) == tile.terrain:
				mask |= 1 << side
		_tiles_by_mask[mask] = coords

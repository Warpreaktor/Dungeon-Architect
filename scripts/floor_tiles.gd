class_name FloorTiles
extends RefCounted

const TILE_SET: TileSet = preload("res://assets/tilesets/crypt_floor.tres")
const SOURCE_ID := 0

static var _regions: Array[Rect2i] = []
static var _cumulative_weights: Array[float] = []


static func atlas() -> TileSetAtlasSource:
	return TILE_SET.get_source(SOURCE_ID) as TileSetAtlasSource


static func texture_region(data: DungeonMap, cell: Vector2i) -> Rect2i:
	if _regions.is_empty():
		_index_tiles()
	var total: float = _cumulative_weights.back()
	if total <= 0.0:
		return _regions[0]
	var roll: float = float(_cell_hash(data.map_id, cell)) / 4294967296.0 * total
	return _regions[mini(_cumulative_weights.bsearch(roll, false), _regions.size() - 1)]


static func _cell_hash(map_id: String, cell: Vector2i) -> int:
	var value: int = (map_id.trim_prefix(OfficialCampaignLibrary.ID_PREFIX).hash() ^ (cell.x * 0x1f123bb5) ^ (cell.y * 0x5f356495)) & 0xffffffff
	value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0xffffffff
	value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0xffffffff
	return value ^ (value >> 16)


static func _invalidate_index() -> void:
	_regions.clear()
	_cumulative_weights.clear()


static func _index_tiles() -> void:
	if not TILE_SET.changed.is_connected(_invalidate_index):
		TILE_SET.changed.connect(_invalidate_index)
	var source: TileSetAtlasSource = atlas()
	var coords: Array[Vector2i] = []
	for index in range(source.get_tiles_count()):
		coords.append(source.get_tile_id(index))
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var total: float = 0.0
	for tile in coords:
		var tile_data: TileData = source.get_tile_data(tile, 0)
		total += maxf(0.0, tile_data.probability)
		_regions.append(source.get_tile_texture_region(tile))
		_cumulative_weights.append(total)

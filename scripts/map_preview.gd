class_name MapPreview
extends RefCounted

## Рендер миниатюр для библиотеки редактора.
const PREVIEW_WIDTH := 176
const PREVIEW_HEIGHT := 116
const PREVIEW_FLOOR: Texture2D = preload("res://assets/stone_floor.png")
const PREVIEW_COLORS := {
    "door": Color("#c58a49"), "chest": Color("#edc06c"),
    "monster": Color("#e65d73"), "trap": Color("#e07b8f"), "key": Color("#ffe8a3"),
    "potion": Color("#b89bff"), "gold": Color("#f4ce67"), "stairs_down": Color("#5bd2e7"), "portal": Color("#977eff"), "portal_local": Color("#977eff"),
    "trigger": Color("#ce90e5"), "player_spawn": Color("#70f2aa"),
    "message": Color("#ffdd93")
}


static func make_preview(data: DungeonMap) -> ImageTexture:
	# Миниатюра строится из сохранённой карты и не требует отдельного PNG.
	var img := Image.create(PREVIEW_WIDTH, PREVIEW_HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color("#101820"))
	var cell_size := minf(float(PREVIEW_WIDTH - 12) / float(data.width), float(PREVIEW_HEIGHT - 12) / float(data.height))
	var drawn_width := float(data.width) * cell_size
	var drawn_height := float(data.height) * cell_size
	var left := (float(PREVIEW_WIDTH) - drawn_width) * 0.5
	var top := (float(PREVIEW_HEIGHT) - drawn_height) * 0.5
	var floor_image := PREVIEW_FLOOR.get_image()
	var wall_image := WallTiles.atlas().texture.get_image()
	var wall_regions: Dictionary = {}
	var x_start := maxi(0, floori(left))
	var y_start := maxi(0, floori(top))
	var x_end := mini(PREVIEW_WIDTH, ceili(left + drawn_width))
	var y_end := mini(PREVIEW_HEIGHT, ceili(top + drawn_height))
	for py in range(y_start, y_end):
		for px in range(x_start, x_end):
			var world_x := (float(px) - left) / cell_size
			var world_y := (float(py) - top) / cell_size
			var cx := floori(world_x)
			var cy := floori(world_y)
			if not data.contains(cx, cy):
				continue
			var fraction := Vector2(fposmod(world_x, 1.0), fposmod(world_y, 1.0))
			var floor_pixel := Vector2i(fraction * Vector2(floor_image.get_size())).clamp(Vector2i.ZERO, floor_image.get_size() - Vector2i.ONE)
			var color: Color = floor_image.get_pixelv(floor_pixel)
			if data.get_terrain(cx, cy) == "wall":
				var cell := Vector2i(cx, cy)
				if not wall_regions.has(cell):
					wall_regions[cell] = WallTiles.texture_region(data, cell)
				var region: Rect2i = wall_regions[cell]
				var wall_pixel: Vector2i = region.position + Vector2i(fraction * Vector2(region.size)).clamp(Vector2i.ZERO, region.size - Vector2i.ONE)
				color = color.blend(wall_image.get_pixelv(wall_pixel))
			img.set_pixel(px, py, color)
	for entity in data.entities:
		var kind := str(entity.get("type", ""))
		if not PREVIEW_COLORS.has(kind):
			continue
		var center_x := roundi(left + (float(entity["x"]) + 0.5) * cell_size)
		var center_y := roundi(top + (float(entity["y"]) + 0.5) * cell_size)
		var dot_radius := clampi(roundi(cell_size * 0.23), 1, 4)
		var dot := Rect2i(center_x - dot_radius, center_y - dot_radius, dot_radius * 2 + 1, dot_radius * 2 + 1)
		img.fill_rect(dot.intersection(Rect2i(0, 0, PREVIEW_WIDTH, PREVIEW_HEIGHT)), PREVIEW_COLORS[kind])
	return ImageTexture.create_from_image(img)

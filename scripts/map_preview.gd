class_name MapPreview
extends RefCounted

## Общий рендер миниатюр для библиотеки редактора и главного меню.
const PREVIEW_WIDTH := 176
const PREVIEW_HEIGHT := 116
const PREVIEW_FLOOR: Texture2D = preload("res://assets/stone_floor.png")
const PREVIEW_WALL: Texture2D = preload("res://assets/stone_wall.png")
const PREVIEW_COLORS := {
    "door": Color("#c58a49"), "chest": Color("#edc06c"),
    "monster": Color("#e65d73"), "trap": Color("#e07b8f"), "key": Color("#ffe8a3"),
    "potion": Color("#b89bff"), "gold": Color("#f4ce67"), "stairs_down": Color("#5bd2e7"), "portal": Color("#977eff"),
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
	var wall_image := PREVIEW_WALL.get_image()
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
			var source := wall_image if data.get_terrain(cx, cy) == "wall" else floor_image
			var sx := clampi(floori(fposmod(world_x, 1.0) * float(source.get_width())), 0, source.get_width() - 1)
			var sy := clampi(floori(fposmod(world_y, 1.0) * float(source.get_height())), 0, source.get_height() - 1)
			img.set_pixel(px, py, source.get_pixel(sx, sy))
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

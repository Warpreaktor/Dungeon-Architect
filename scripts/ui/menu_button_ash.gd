extends Node2D

const COLUMNS := 88
const ROWS := 22
const PALE_ASH := Color(0.73, 0.69, 0.64)
const DARK_ASH := Color(0.29, 0.27, 0.25)
const EMBER := Color(0.96, 0.46, 0.15)

static var _mask: Image
var _seeds := PackedVector2Array()
var _drifts := PackedVector2Array()
var _colors := PackedColorArray()
var _thresholds := PackedFloat32Array()
var _bounds := Rect2()
var _burn := 0.0
var _scatter := 0.0


func prepare(texture: Texture2D) -> void:
	if not _seeds.is_empty():
		return
	if _mask == null:
		_mask = texture.get_image()
		if _mask != null and _mask.is_compressed() and _mask.decompress() != OK:
			_mask = null
		if _mask != null and not _mask.is_empty():
			_mask.resize(256, 64, Image.INTERPOLATE_BILINEAR)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for y in range(ROWS):
		for x in range(COLUMNS):
			var uv := (Vector2(x, y) + Vector2(rng.randf(), rng.randf())) / Vector2(COLUMNS, ROWS)
			if _mask != null and not _mask.is_empty():
				var pixel := Vector2i(uv * Vector2(_mask.get_size()))
				if _mask.get_pixelv(pixel).a < 0.35:
					continue
			_seeds.append(uv)
			_drifts.append(Vector2(rng.randf_range(-0.32, 0.32), rng.randf_range(-1.4, 0.4)))
			_colors.append(DARK_ASH.lerp(PALE_ASH, rng.randf()))
			_thresholds.append(0.12 + 0.76 * uv.y + rng.randf_range(-0.10, 0.10))


func show_phase(bounds: Rect2, burn: float, scatter: float) -> void:
	_bounds = bounds
	_burn = burn
	_scatter = scatter
	queue_redraw()


func _draw() -> void:
	if _burn <= 0.0 or _scatter >= 1.0 or not _bounds.has_area():
		return
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var grain: float = clampf(_bounds.size.y / float(ROWS) * 0.43, 0.7, 1.5)
	var loosen: float = _scatter * _scatter
	for index in range(_seeds.size()):
		var age: float = _burn - _thresholds[index]
		if age <= 0.0:
			continue
		var point: Vector2 = _bounds.position + (_seeds[index] + _drifts[index] * (0.02 * age + loosen)) * _bounds.size
		var color: Color = _colors[index].lerp(EMBER, 1.0 - smoothstep(0.0, 0.12, age))
		color.a = smoothstep(0.0, 0.045, age) * (1.0 - smoothstep(0.25, 1.0, _scatter))
		points.append(point - Vector2(grain * 0.5, 0.0))
		points.append(point + Vector2(grain * 0.5, grain * 0.35))
		colors.append(color)
	if not points.is_empty():
		draw_multiline_colors(points, colors, grain)

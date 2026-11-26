extends Node2D

const DENSITY := 42
const PALE_ASH := Color(0.73, 0.69, 0.64)
const DARK_ASH := Color(0.29, 0.27, 0.25)
const EMBER := Color(0.96, 0.46, 0.15)

var _seeds := PackedVector2Array()
var _drifts := PackedVector2Array()
var _colors := PackedColorArray()
var _thresholds := PackedFloat32Array()
var _card_size := Vector2.ONE
var _burn := 0.0
var _scatter := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for y in range(DENSITY):
		for x in range(DENSITY):
			var uv := (Vector2(x, y) + Vector2(rng.randf(), rng.randf())) / float(DENSITY)
			if (uv.x < 0.025 or uv.x > 0.975) and (uv.y < 0.025 or uv.y > 0.975):
				continue
			_seeds.append(uv)
			_drifts.append(Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.65, 0.75)))
			_colors.append(DARK_ASH.lerp(PALE_ASH, rng.randf()))
			_thresholds.append(0.12 + 0.76 * uv.y + rng.randf_range(-0.1, 0.1))


func show_phase(card_size: Vector2, burn: float, scatter: float) -> void:
	_card_size = card_size
	_burn = burn
	_scatter = scatter
	queue_redraw()


func _draw() -> void:
	if _burn <= 0.0 or _scatter >= 1.0:
		return
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var grain: float = clampf(minf(_card_size.x, _card_size.y) / float(DENSITY) * 0.45, 0.7, 1.6)
	for index in range(_seeds.size()):
		var age: float = _burn - _thresholds[index]
		if age <= 0.0:
			continue
		var drift: Vector2 = _drifts[index]
		var loosen: float = _scatter * _scatter
		var point: Vector2 = (_seeds[index] + drift * (0.015 * age + loosen)) * _card_size
		var color: Color = _colors[index].lerp(EMBER, 1.0 - smoothstep(0.0, 0.12, age))
		color.a = smoothstep(0.0, 0.045, age) * (1.0 - smoothstep(0.28, 1.0, _scatter))
		points.append(point - Vector2(grain * 0.5, 0.0))
		points.append(point + Vector2(grain * 0.5, grain * 0.35))
		colors.append(color)
	if not points.is_empty():
		draw_multiline_colors(points, colors, grain)

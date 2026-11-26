class_name CardDragLayer
extends Control

const LIFT_SCALE := 1.05
const LIFT_SECONDS := 0.10
const MAX_TILT := 8.0
const FOLLOW_SPEED := 22.0
const ASH_SECONDS := 0.32

var card: Control
var _tween: Tween
var _following := false
var _pointer := Vector2.ZERO
var _offset := Vector2.ZERO
var _tilt := 0.0
var _ash_bits: Array[ColorRect] = []
var _ash_rng := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 30
	set_process(false)
	_ash_rng.randomize()


func lift(visual: Control, source: Rect2, pointer: Vector2) -> void:
	clear()
	card = visual
	add_child(card)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.focus_mode = Control.FOCUS_NONE
	card.size = source.size
	card.pivot_offset = source.size * 0.5
	card.global_position = source.position
	_pointer = pointer
	_offset = source.position - pointer
	_tilt = -3.0
	_following = true
	set_process(true)
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(card, "scale", Vector2.ONE * LIFT_SCALE, LIFT_SECONDS)


func follow(pointer: Vector2) -> void:
	var movement: Vector2 = pointer - _pointer
	if not movement.is_zero_approx():
		_tilt = clampf(movement.x * 0.35 + movement.y * 0.08, -MAX_TILT, MAX_TILT)
	_pointer = pointer


func _process(delta: float) -> void:
	if not _following or not is_instance_valid(card):
		return
	var weight: float = 1.0 - exp(-FOLLOW_SPEED * delta)
	card.global_position = card.global_position.lerp(_pointer + _offset, weight)
	card.rotation_degrees = lerpf(card.rotation_degrees, _tilt, weight)
	_tilt = lerpf(_tilt, 0.0, weight)


func settle(target: Callable, duration: float, finished: Callable, as_ash: bool = false) -> void:
	if not is_instance_valid(card):
		finished.call()
		return
	_stop_tween()
	_following = false
	set_process(false)
	var from := Rect2(card.global_position, card.size)
	var from_scale: Vector2 = card.scale
	var from_rotation: float = card.rotation
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(weight: float) -> void:
		var destination: Rect2 = target.call()
		if not destination.has_area():
			destination = from
		card.size = from.size.lerp(destination.size, weight)
		card.pivot_offset = card.size * 0.5
		card.global_position = from.position.lerp(destination.position, weight)
		card.scale = from_scale.lerp(Vector2.ONE, weight)
		card.rotation = lerpf(from_rotation, 0.0, weight)
	, 0.0, 1.0, duration)
	_tween.tween_callback(func() -> void:
		_tween = null
		if as_ash:
			_crumble(finished)
		else:
			clear()
			finished.call()
	)


func _crumble(finished: Callable) -> void:
	var frame := Rect2(card.global_position, card.size)
	var unit: float = maxf(1.0, minf(frame.size.x, frame.size.y) / 18.0)
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(card, "modulate:a", 0.0, ASH_SECONDS * 0.45)
	_tween.tween_property(card, "scale", Vector2.ONE * 0.95, ASH_SECONDS * 0.45)
	for index in range(36):
		var bit := ColorRect.new()
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bit.size = Vector2.ONE * unit * _ash_rng.randf_range(0.45, 1.25)
		bit.pivot_offset = bit.size * 0.5
		bit.color = Color(0.28, 0.26, 0.24).lerp(Color(0.83, 0.57, 0.31), _ash_rng.randf())
		add_child(bit)
		bit.global_position = frame.position + Vector2(_ash_rng.randf(), _ash_rng.randf()) * frame.size
		_ash_bits.append(bit)
		var drift := Vector2(_ash_rng.randf_range(-7.0, 7.0), _ash_rng.randf_range(-11.0, -2.0)) * unit
		_tween.tween_property(bit, "global_position", bit.global_position + drift, ASH_SECONDS)
		_tween.tween_property(bit, "rotation_degrees", _ash_rng.randf_range(-150.0, 150.0), ASH_SECONDS)
		_tween.tween_property(bit, "modulate:a", 0.0, ASH_SECONDS)
		_tween.tween_property(bit, "scale", Vector2.ONE * 0.2, ASH_SECONDS)
	_tween.chain().tween_callback(func() -> void:
		_tween = null
		clear()
		finished.call()
	)


func clear() -> void:
	_stop_tween()
	_following = false
	set_process(false)
	if is_instance_valid(card):
		card.hide()
		card.queue_free()
	card = null
	for bit in _ash_bits:
		bit.hide()
		bit.queue_free()
	_ash_bits.clear()


func _stop_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

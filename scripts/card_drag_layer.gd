class_name CardDragLayer
extends Control

const LIFT_SCALE := 1.05
const LIFT_SECONDS := 0.10
const MAX_TILT := 8.0
const FOLLOW_SPEED := 22.0

var card: Control
var _tween: Tween
var _following := false
var _pointer := Vector2.ZERO
var _offset := Vector2.ZERO
var _tilt := 0.0


func _ready() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 30
	set_process(false)


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


func settle(target: Callable, duration: float, finished: Callable) -> void:
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


func _stop_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

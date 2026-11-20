class_name BattleChainReorderController
extends RefCounted

const DRAG_START_FRACTION: float = 0.08
const HORIZONTAL_INTENT_RATIO: float = 1.15
const SWAP_SECONDS: float = 0.23
const DRAG_LIFT_SCALE: float = 1.04

enum Pointer { NONE, MOUSE, TOUCH }

var _host: Control
var _row: HBoxContainer
var _can_reorder: Callable
var _on_move: Callable
var _pointer: int = Pointer.NONE
var _source_index: int = -1
var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _moving: bool = false
var _animating: bool = false
var _suppressed_index: int = -1
var _positions: Array[Vector2] = []
var _preview_index: int = -1
var _tween: Tween
var _preview_tween: Tween


func configure(host: Control, row: HBoxContainer, can_reorder: Callable, on_move: Callable) -> void:
	_host = host
	_row = row
	_can_reorder = can_reorder
	_on_move = on_move


static func moved(values: Array[String], from_index: int, to_index: int) -> Array[String]:
	var result: Array[String] = values.duplicate()
	if from_index < 0 or to_index < 0 or from_index >= result.size() or to_index >= result.size():
		return result
	var entry: String = result[from_index]
	result.remove_at(from_index)
	result.insert(to_index, entry)
	return result


func is_animating() -> bool:
	return _animating


func consume_selection(index: int) -> bool:
	return _moving or _animating or index == _suppressed_index


func cancel() -> void:
	_stop_tweens()
	_restore_slots()
	_pointer = Pointer.NONE
	_moving = false
	_animating = false
	_source_index = -1
	_preview_index = -1
	_suppressed_index = -1


func handle_input(event: InputEvent) -> void:
	if _animating or _host == null or _row == null:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _pointer == Pointer.NONE or _pointer == Pointer.MOUSE:
				_start(touch.position, Pointer.TOUCH, touch.index)
		elif _pointer == Pointer.TOUCH and touch.index == _touch_index:
			_finish(touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _pointer == Pointer.TOUCH and drag.index == _touch_index:
			_update(drag.position)
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed and _pointer == Pointer.NONE:
			_start(mouse.position, Pointer.MOUSE, -1)
		elif not mouse.pressed and _pointer == Pointer.MOUSE:
			_finish(mouse.position)
	elif event is InputEventMouseMotion and _pointer == Pointer.MOUSE:
		_update((event as InputEventMouseMotion).position)


func _start(point: Vector2, pointer: Pointer, index: int) -> void:
	_pointer = Pointer.NONE
	_source_index = -1
	_suppressed_index = -1
	if not _can_reorder.is_valid() or not bool(_can_reorder.call()):
		return
	for i in range(_row.get_child_count() - 1):
		var slot: BattleAbilitySlot = _row.get_child(i) as BattleAbilitySlot
		if slot == null or slot.disabled or not slot.get_global_rect().has_point(point):
			continue
		var over_child_button: bool = false
		for child in slot.get_children():
			if child is BaseButton:
				var button_child: BaseButton = child as BaseButton
				if button_child.visible and button_child.get_global_rect().has_point(point):
					over_child_button = true
					break
		if over_child_button:
			continue
		_pointer = pointer
		_touch_index = index
		_source_index = i
		_preview_index = i
		_origin = point
		_positions.clear()
		for child in _row.get_children():
			_positions.append((child as Control).position)
		_moving = false
		return


func _update(point: Vector2) -> void:
	if _source_index < 0:
		return
	if not _can_reorder.is_valid() or not bool(_can_reorder.call()):
		cancel()
		return
	var source: Control = _row.get_child(_source_index) as Control
	var delta: Vector2 = point - _origin
	if not _moving:
		if absf(delta.x) < source.size.x * DRAG_START_FRACTION:
			return
		if absf(delta.x) <= absf(delta.y) * HORIZONTAL_INTENT_RATIO:
			return
		_moving = true
		_suppressed_index = _source_index
		source.z_index = 2
		source.pivot_offset = source.size * 0.5
		source.scale = Vector2.ONE * DRAG_LIFT_SCALE
	var count: int = _row.get_child_count() - 1
	var first_x: float = _positions.front().x
	var last_x: float = _positions[count - 1].x
	source.position = Vector2(clampf(_positions[_source_index].x + delta.x, first_x, last_x), _positions[_source_index].y)
	var target_index: int = target_for_displacement(_source_index, count, delta.x, source.size.x, float(_row.get_theme_constant("separation")))
	if target_index != _preview_index:
		_preview_index = target_index
		_animate_preview()


func _finish(point: Vector2) -> void:
	var from_index: int = _source_index
	var was_moving: bool = _moving
	_pointer = Pointer.NONE
	_source_index = -1
	_moving = false
	if not was_moving or from_index < 0:
		return
	_suppressed_index = from_index
	var source: Control = _row.get_child(from_index) as Control
	var to_index: int = target_for_displacement(from_index, _row.get_child_count() - 1, point.x - _origin.x, source.size.x, float(_row.get_theme_constant("separation")))
	_preview_index = to_index
	_stop_tweens()
	_animating = true
	_tween = _host.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(true)
	for i in range(_row.get_child_count() - 1):
		var slot: Control = _row.get_child(i) as Control
		_tween.tween_property(slot, "position", _target_position(i, from_index, to_index), SWAP_SECONDS)
	_tween.tween_property(source, "scale", Vector2.ONE, SWAP_SECONDS)
	_tween.finished.connect(func() -> void:
		_animating = false
		_restore_slots()
		if from_index != to_index and _on_move.is_valid():
			_on_move.call(from_index, to_index)
	)


static func target_for_displacement(source_index: int, count: int, delta_x: float, slot_width: float, spacing: float) -> int:
	if source_index < 0 or source_index >= count or count <= 1:
		return source_index
	if absf(delta_x) < slot_width * DRAG_START_FRACTION:
		return source_index
	var step: float = maxf(slot_width + spacing, slot_width)
	if step <= 0.0:
		return source_index
	var distance_in_slots: int = roundi(absf(delta_x) / step)
	return clampi(source_index + (distance_in_slots if delta_x > 0.0 else -distance_in_slots), 0, count - 1)


func _target_position(index: int, from_index: int, to_index: int) -> Vector2:
	if index == from_index:
		return _positions[to_index]
	if from_index < to_index and index > from_index and index <= to_index:
		return _positions[index - 1]
	if from_index > to_index and index >= to_index and index < from_index:
		return _positions[index + 1]
	return _positions[index]


func _animate_preview() -> void:
	if _preview_tween != null and _preview_tween.is_valid():
		_preview_tween.kill()
	_preview_tween = _host.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_preview_tween.set_parallel(true)
	for i in range(_row.get_child_count() - 1):
		if i == _source_index:
			continue
		_preview_tween.tween_property(_row.get_child(i), "position", _target_position(i, _source_index, _preview_index), SWAP_SECONDS)


func _stop_tweens() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _preview_tween != null and _preview_tween.is_valid():
		_preview_tween.kill()
	_tween = null
	_preview_tween = null


func _restore_slots() -> void:
	if _row == null:
		return
	for i in range(mini(_positions.size(), _row.get_child_count())):
		var slot: Control = _row.get_child(i) as Control
		slot.position = _positions[i]
		slot.scale = Vector2.ONE
		slot.z_index = 0

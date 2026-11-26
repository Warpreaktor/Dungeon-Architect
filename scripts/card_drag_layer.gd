class_name CardDragLayer
extends Control

const ASH_SHADER := preload("res://shaders/card_ash.gdshader")
const ASH_DUST := preload("res://scripts/card_ash_dust.gd")
const LIFT_SCALE := 1.05
const LIFT_SECONDS := 0.14
const MAX_TILT := 8.0
const FOLLOW_SPEED := 15.0
const BURN_SECONDS := 0.72
const SCATTER_SECONDS := 0.62
const REFORM_SECONDS := 0.82
const DRAG_BURN_LIMIT := 0.84

var card: Control
var _tween: Tween
var _following := false
var _pointer := Vector2.ZERO
var _offset := Vector2.ZERO
var _tilt := 0.0
var _group: CanvasGroup
var _ash_material: ShaderMaterial
var _dust: Node2D
var _burn := 0.0
var _scatter := 0.0
var _burn_requested := false


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


func follow(pointer: Vector2, burning: bool = false) -> void:
	var movement: Vector2 = pointer - _pointer
	if not movement.is_zero_approx():
		_tilt = clampf(movement.x * 0.35 + movement.y * 0.08, -MAX_TILT, MAX_TILT)
	_pointer = pointer
	_burn_requested = burning
	if burning:
		_ensure_ash()


func _process(delta: float) -> void:
	if not _following or not is_instance_valid(card):
		return
	var weight: float = 1.0 - exp(-FOLLOW_SPEED * delta)
	card.global_position = card.global_position.lerp(_pointer + _offset, weight)
	card.rotation_degrees = lerpf(card.rotation_degrees, _tilt, weight)
	_tilt = lerpf(_tilt, 0.0, weight)
	if _ash_material != null:
		var target: float = DRAG_BURN_LIMIT if _burn_requested else 0.0
		_burn = move_toward(_burn, target, delta / BURN_SECONDS)
		_sync_ash()


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
	var from_burn: float = _burn
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
		_burn = lerpf(from_burn, 0.0, weight)
		_sync_ash()
	, 0.0, 1.0, duration)
	_tween.tween_callback(_complete.bind(finished))


func discard(target: Callable, finished: Callable) -> void:
	if not is_instance_valid(card):
		finished.call()
		return
	_stop_tween()
	_following = false
	set_process(false)
	_ensure_ash()
	var from: Vector2 = card.global_position
	var destination: Vector2 = _pointer + _offset
	var from_burn: float = _burn
	var from_rotation: float = card.rotation
	var from_scale: Vector2 = card.scale
	var duration: float = maxf(0.24, BURN_SECONDS * (1.0 - from_burn))
	_tween = create_tween()
	_tween.tween_method(func(weight: float) -> void:
		var movement: float = 1.0 - pow(1.0 - weight, 3.0)
		card.global_position = from.lerp(destination, movement)
		card.rotation = lerpf(from_rotation, 0.0, movement)
		card.scale = from_scale.lerp(Vector2.ONE, movement)
		_burn = lerpf(from_burn, 1.0, weight)
		_sync_ash()
	, 0.0, 1.0, duration)
	_tween.tween_method(_set_scatter, 0.0, 1.0, SCATTER_SECONDS)
	_tween.tween_callback(_reform.bind(target, finished))


func _reform(target: Callable, finished: Callable) -> void:
	_tween = null
	var destination: Rect2 = target.call()
	if not destination.has_area():
		_complete(finished)
		return
	card.scale = Vector2.ONE
	card.rotation = 0.0
	card.size = destination.size
	card.pivot_offset = card.size * 0.5
	card.global_position = destination.position
	_sync_ash()
	_tween = create_tween()
	_tween.tween_method(func(weight: float) -> void:
		var current: Rect2 = target.call()
		if not current.has_area():
			_group.hide()
			_dust.hide()
			return
		_group.show()
		_dust.show()
		card.size = current.size
		card.pivot_offset = card.size * 0.5
		card.global_position = current.position
		_scatter = 1.0 - smoothstep(0.0, 0.48, weight)
		_burn = 1.0 - smoothstep(0.35, 1.0, weight)
		_sync_ash()
	, 0.0, 1.0, REFORM_SECONDS)
	_tween.tween_callback(_complete.bind(finished))


func _ensure_ash() -> void:
	if _ash_material != null:
		return
	_group = CanvasGroup.new()
	add_child(_group)
	var original_position: Vector2 = card.global_position
	card.reparent(_group, false)
	card.global_position = original_position
	_ash_material = ShaderMaterial.new()
	_ash_material.shader = ASH_SHADER
	_group.material = _ash_material
	_dust = ASH_DUST.new()
	add_child(_dust)
	_sync_ash()


func _set_scatter(value: float) -> void:
	_scatter = value
	_sync_ash()


func _sync_ash() -> void:
	if _ash_material == null or not is_instance_valid(card):
		return
	var inverse: Transform2D = card.get_transform().affine_inverse()
	_ash_material.set_shader_parameter("card_origin", inverse.origin)
	_ash_material.set_shader_parameter("card_x", Vector2(inverse.x.x, inverse.y.x))
	_ash_material.set_shader_parameter("card_y", Vector2(inverse.x.y, inverse.y.y))
	_ash_material.set_shader_parameter("card_size", card.size.max(Vector2.ONE))
	_ash_material.set_shader_parameter("burn", _burn)
	_dust.transform = card.get_transform()
	_dust.call("show_phase", card.size, _burn, _scatter)


func _complete(finished: Callable) -> void:
	_tween = null
	clear()
	finished.call()


func clear() -> void:
	_stop_tween()
	_following = false
	set_process(false)
	if is_instance_valid(card):
		card.hide()
		card.queue_free()
	card = null
	if is_instance_valid(_group):
		_group.hide()
		_group.queue_free()
	_group = null
	if is_instance_valid(_dust):
		_dust.hide()
		_dust.queue_free()
	_dust = null
	_ash_material = null
	_burn = 0.0
	_scatter = 0.0
	_burn_requested = false


func _stop_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

class_name BattleStatusPresenter
extends RefCounted

signal info_requested(actor_id: String, status_id: String)

# Общая раскладка значков состояний. Константы BLEED_FLASH управляют анимацией статусов.
const STATUS_ICONS: Dictionary = {
	"bleeding": preload("res://assets/abilities/statuses/bleeding.png"),
	"petushan_accuracy_down": preload("res://assets/abilities/statuses/accuracy_down.png"),
	"rabbit_master_mark": preload("res://assets/abilities/statuses/rabbit_master_mark.png")
}
const STATUS_MARKER_GAP: float = 0.04
const BLEED_FLASH_IN_SECONDS: float = 0.18
const BLEED_FLASH_OUT_SECONDS: float = 1.00
const BLEED_FLASH_START_SCALE: float = 0.85
const BLEED_FLASH_PEAK_SCALE: float = 1.05
const BLEED_MARKER_SCALE: float = 0.28
const BLEED_MARKER_OFFSET: Vector2 = Vector2(0.02, 0.70)


var _owner: Node
var _impact_portraits: Dictionary = {}
var _status_markers: Dictionary = {}
var _impact_status_markers: Dictionary = {}
var _status_tweens: Dictionary = {}
var _visible_statuses: Dictionary = {"hero": {}, "enemy": {}}


func _init(owner: Node) -> void:
	_owner = owner


func setup(portraits: Dictionary) -> void:
	for actor_id in portraits:
		var portrait: TextureRect = portraits[actor_id] as TextureRect
		if portrait != null:
			_status_markers[str(actor_id)] = _make_status_markers(portrait, str(actor_id))


func reset() -> void:
	_visible_statuses = {}
	for actor_id in _status_markers:
		_visible_statuses[actor_id] = {}
		_layout_status_markers(str(actor_id))


func attach_impact(actor_id: String, portrait: TextureRect) -> void:
	_impact_portraits[actor_id] = portrait
	_impact_status_markers[actor_id] = _make_status_markers(portrait, actor_id)
	_layout_status_markers(actor_id)


func clear_impact() -> void:
	for running in _status_tweens.values():
		var tween: Tween = running as Tween
		if tween != null and tween.is_valid():
			tween.kill()
	_status_tweens.clear()
	_impact_status_markers.clear()
	_impact_portraits.clear()


func _make_status_markers(parent: TextureRect, actor_id: String) -> Dictionary:
	var result: Dictionary = {}
	for status_id in STATUS_ICONS:
		var icon := TextureRect.new()
		icon.texture = STATUS_ICONS[status_id]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.gui_input.connect(_on_marker_input.bind(actor_id, str(status_id)))
		icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
		icon.size = parent.size * BLEED_MARKER_SCALE
		icon.visible = false
		parent.add_child(icon)
		result[status_id] = icon
	return result


func _on_marker_input(event: InputEvent, actor_id: String, status_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		info_requested.emit(actor_id, status_id)
	elif event is InputEventScreenTouch and event.pressed and event.index == 0:
		info_requested.emit(actor_id, status_id)


func _visible_marker_ids(actor_id: String) -> Array[String]:
	var ids: Array[String] = []
	var visible: Dictionary = _visible_statuses.get(actor_id, {})
	for status_id in STATUS_ICONS:
		if bool(visible.get(status_id, false)):
			ids.append(status_id)
	return ids


func _marker_position(parent: TextureRect, index: int) -> Vector2:
	return parent.size * Vector2(
		BLEED_MARKER_OFFSET.x + float(index) * (BLEED_MARKER_SCALE + STATUS_MARKER_GAP),
		BLEED_MARKER_OFFSET.y)


func _layout_status_markers(actor_id: String, skip_animation: String = "") -> void:
	var ids: Array[String] = _visible_marker_ids(actor_id)
	for collection in [_status_markers, _impact_status_markers]:
		var markers: Dictionary = collection.get(actor_id, {})
		for status_id in markers:
			var icon: TextureRect = markers[status_id] as TextureRect
			if icon == null or not is_instance_valid(icon):
				continue
			icon.visible = status_id in ids
			var animating: bool = collection == _impact_status_markers and _status_tweens.has(actor_id + ":" + str(status_id))
			if icon.visible and status_id != skip_animation and not animating:
				var portrait: TextureRect = icon.get_parent() as TextureRect
				icon.size = portrait.size * BLEED_MARKER_SCALE
				icon.position = _marker_position(portrait, ids.find(status_id))
				icon.modulate = Color.WHITE


func set_visible(actor_id: String, status_id: String, visible: bool, skip_animation: bool = false) -> void:
	if not STATUS_ICONS.has(status_id):
		return
	var visible_by_id: Dictionary = _visible_statuses.get(actor_id, {}).duplicate()
	visible_by_id[status_id] = visible
	_visible_statuses[actor_id] = visible_by_id
	_layout_status_markers(actor_id, status_id if skip_animation else "")


func flash(actor_id: String, status_id: String) -> void:
	if not STATUS_ICONS.has(status_id):
		return
	var portrait: TextureRect = _impact_portraits.get(actor_id) as TextureRect
	if portrait == null:
		set_visible(actor_id, status_id, true)
		return
	var tween_key: String = actor_id + ":" + status_id
	var previous: Tween = _status_tweens.get(tween_key) as Tween
	if previous != null and previous.is_valid():
		previous.kill()
	set_visible(actor_id, status_id, true, true)
	var markers: Dictionary = _impact_status_markers.get(actor_id, {})
	var icon: TextureRect = markers.get(status_id) as TextureRect
	if icon == null:
		return
	icon.show()
	icon.size = portrait.size * BLEED_FLASH_START_SCALE
	icon.position = (portrait.size - icon.size) * 0.5
	icon.modulate = Color(1.0, 0.35, 0.35, 1.0) if status_id == "bleeding" else Color.WHITE
	icon.pivot_offset = Vector2.ZERO
	icon.scale = Vector2.ONE
	var tween: Tween = _owner.create_tween()
	_status_tweens[tween_key] = tween
	var peak_size: Vector2 = portrait.size * BLEED_FLASH_PEAK_SCALE
	tween.tween_property(icon, "size", peak_size, BLEED_FLASH_IN_SECONDS)
	tween.parallel().tween_property(icon, "position", (portrait.size - peak_size) * 0.5, BLEED_FLASH_IN_SECONDS)
	tween.tween_property(icon, "size", portrait.size * BLEED_MARKER_SCALE, BLEED_FLASH_OUT_SECONDS)
	tween.parallel().tween_property(icon, "position", _marker_position(portrait, _visible_marker_ids(actor_id).find(status_id)), BLEED_FLASH_OUT_SECONDS)
	tween.parallel().tween_property(icon, "modulate", Color.WHITE, BLEED_FLASH_OUT_SECONDS)
	tween.tween_callback(_finish_status_flash.bind(actor_id, status_id))


func _finish_status_flash(actor_id: String, status_id: String) -> void:
	_status_tweens.erase(actor_id + ":" + status_id)
	_layout_status_markers(actor_id)


func sync(participants: Dictionary) -> void:
	for actor_id in _status_markers:
		var actor: BattleParticipant = participants.get(actor_id) as BattleParticipant
		for status_id in STATUS_ICONS:
			set_visible(str(actor_id), status_id, actor != null and actor.statuses.has(status_id))

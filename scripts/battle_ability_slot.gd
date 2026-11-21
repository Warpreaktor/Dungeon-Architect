class_name BattleAbilitySlot
extends Button

## Одна ячейка алгоритма. Никакого собственного состояния боя:
## показывает AbilityDefinition и посылает номер выбранной ячейки.
signal slot_selected(index: int)
signal info_requested(content: String)

const ATTACK_ICON: Texture2D = preload("res://assets/hud/attack.png")
const DEFENSE_ICON: Texture2D = preload("res://assets/hud/shield.png")
const SUPPORT_ICON: Texture2D = preload("res://assets/hud/heart.png")
const SPECIAL_ICON: Texture2D = preload("res://assets/hud/fist.png")
const INFO_BUTTON_SIDE: float = 30.0


@onready var _slot_number: Label = $SlotMargin/Row/Labels/SlotNumber
@onready var _slot_name: Label = $SlotMargin/Row/Labels/SlotName
@onready var _slot_icon: TextureRect = $SlotMargin/Row/SlotIcon
@onready var _empty_icon: Label = $SlotMargin/Row/EmptyIcon

var slot_index: int = 0
var _invalid_tween: Tween
var _info_button: Button


static func visual_icon(ability: AbilityDefinition) -> Texture2D:
	if ability == null:
		return null
	if ability.icon != null:
		return ability.icon
	match ability.category:
		AbilityDefinition.Category.DEFENSE:
			return DEFENSE_ICON
		AbilityDefinition.Category.SUPPORT:
			return SUPPORT_ICON
		AbilityDefinition.Category.SPECIAL:
			return SPECIAL_ICON
		_:
			return ATTACK_ICON


static func side_for_width(available_width: float, slot_count: int, gap: float, minimum: float, maximum: float) -> float:
	if slot_count <= 0:
		return minimum
	return clampf((available_width - gap * float(slot_count - 1)) / float(slot_count), minimum, maximum)


func _ready() -> void:
	pressed.connect(_notify_selection)
	_info_button = Button.new()
	_info_button.text = "ⓘ"
	_info_button.custom_minimum_size = Vector2.ONE * INFO_BUTTON_SIDE
	_info_button.size = _info_button.custom_minimum_size
	_info_button.focus_mode = Control.FOCUS_NONE
	_info_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_button.pressed.connect(_show_info)
	add_child(_info_button)
	resized.connect(_position_info_button)
	_position_info_button()
	_info_button.hide()


func _position_info_button() -> void:
	if _info_button != null:
		_info_button.position = Vector2(maxf(0.0, size.x - _info_button.size.x), 0.0)


func _show_info() -> void:
	if not tooltip_text.is_empty():
		info_requested.emit(tooltip_text)


func configure(index: int, ability: AbilityDefinition, editable: bool, actor: BattleParticipant = null) -> void:
	slot_index = index
	_slot_number.text = "%02d" % (index + 1)
	_slot_name.text = ability.display_name if ability != null else "Добавить"
	_slot_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slot_icon.texture = visual_icon(ability)
	_slot_icon.visible = _slot_icon.texture != null
	_empty_icon.visible = not _slot_icon.visible
	_empty_icon.text = "+"
	tooltip_text = BattleAbilityTooltip.describe(ability, actor, index)
	disabled = not editable
	_info_button.visible = not tooltip_text.is_empty()


func _notify_selection() -> void:
	slot_selected.emit(slot_index)


func configure_recharge(index: int) -> void:
	configure(index, null, false)
	_slot_number.text = "%02d" % (index + 1)
	_slot_name.text = "Отдых"
	_slot_icon.texture = null
	_slot_icon.visible = false
	_empty_icon.visible = true
	_empty_icon.text = "Zz"
	tooltip_text = "Отдых: завершает фазу и возвращает все приёмы"
	_info_button.visible = true


func set_current(active: bool) -> void:
	if active:
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color("#3e3220")
		focus.border_color = Color("#f7c96b")
		focus.set_border_width_all(3)
		focus.set_corner_radius_all(7)
		add_theme_stylebox_override("normal", focus)
		add_theme_stylebox_override("disabled", focus)
	else:
		remove_theme_stylebox_override("normal")
		remove_theme_stylebox_override("disabled")


func flash_empty() -> void:
	if _invalid_tween != null and _invalid_tween.is_valid():
		_invalid_tween.kill()
	_invalid_tween = create_tween()
	for i in range(3):
		_invalid_tween.tween_property(self, "modulate", Color(1.0, 0.22, 0.22), 0.12)
		_invalid_tween.tween_property(self, "modulate", Color.WHITE, 0.14)


## Вражеские приёмы скрыты до момента исполнения, но сам слот виден.
func configure_hidden(index: int) -> void:
	configure(index, null, false)
	_slot_name.text = "???"
	_empty_icon.text = "?"
	tooltip_text = ""
	_info_button.hide()


func reveal_enemy_action(ability: AbilityDefinition, participant: BattleParticipant) -> void:
	configure(slot_index, ability, false, participant)

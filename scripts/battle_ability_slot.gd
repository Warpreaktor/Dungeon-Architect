class_name BattleAbilitySlot
extends Button

## Одна ячейка алгоритма. Никакого собственного состояния боя:
## показывает AbilityDefinition и посылает номер выбранной ячейки.
signal slot_selected(index: int)

const ATTACK_ICON: Texture2D = preload("res://assets/hud/attack.png")
const DEFENSE_ICON: Texture2D = preload("res://assets/hud/shield.png")
const SUPPORT_ICON: Texture2D = preload("res://assets/hud/heart.png")
const SPECIAL_ICON: Texture2D = preload("res://assets/hud/fist.png")


@onready var _slot_number: Label = $SlotMargin/Row/Labels/SlotNumber
@onready var _slot_name: Label = $SlotMargin/Row/Labels/SlotName
@onready var _slot_icon: TextureRect = $SlotMargin/Row/SlotIcon
@onready var _empty_icon: Label = $SlotMargin/Row/EmptyIcon

var slot_index: int = 0
var _invalid_tween: Tween


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


func _ready() -> void:
	pressed.connect(_notify_selection)


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
	tooltip_text = "Отдых: один пропущенный такт"


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


func reveal_enemy_action(ability: AbilityDefinition, participant: BattleParticipant) -> void:
	configure(slot_index, ability, false, participant)

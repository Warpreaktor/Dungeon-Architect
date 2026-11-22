class_name InventoryView
extends CanvasLayer

## Только представление: предметы и экипировка принадлежат GameSession/HeroState.
## Изменение состояния предметов выполняет игровой контроллер, а не UI.
signal closed
signal item_use_requested(item_id: String)
signal equipment_requested(item_id: String, equip: bool)

@onready var _card: PanelContainer = %Card
@onready var _columns: GridContainer = %Columns
@onready var _bag_grid: GridContainer = %BagGrid
@onready var _gold_label: Label = %GoldLabel
@onready var _attack_label: Label = %AttackLabel
@onready var _strength_label: Label = %StrengthLabel
@onready var _agility_label: Label = %AgilityLabel
@onready var _defense_label: Label = %DefenseLabel
@onready var _item_icon: TextureRect = %ItemIcon
@onready var _item_name: Label = %ItemName
@onready var _item_description: RichTextLabel = %ItemDescription
@onready var _item_properties: Label = %ItemProperties
@onready var _use_button: Button = %UseButton
@onready var _use_feedback: Label = %UseFeedback
@onready var _weapon_icon: TextureRect = %WeaponIcon
@onready var _weapon_name: Label = %WeaponName
@onready var _shield_icon: TextureRect = %ShieldIcon
@onready var _shield_name: Label = %ShieldName
@onready var _close_button: Button = %CloseButton

var _session: GameSession
var _entries: Array[String] = []
var _selected_index: int = -1
var _bag_cell_size: float = 52.0


func _ready() -> void:
	_use_button.pressed.connect(_request_use_selected)
	_close_button.pressed.connect(close_by_player)
	get_viewport().size_changed.connect(_resize_card)
	_resize_card()
	hide()


func open_for(session: GameSession) -> void:
	if session == null or session.hero == null:
		return
	_session = session
	_use_feedback.text = ""
	_refresh_contents()
	_resize_card()
	show()
	_close_button.grab_focus()


func _refresh_contents() -> void:
	for child in _bag_grid.get_children():
		_bag_grid.remove_child(child)
		child.queue_free()
	_entries = _session.inventory_slot_ids()
	var hero: HeroState = _session.hero
	_gold_label.text = "%d" % hero.gold
	_attack_label.text = "%d" % hero.melee_attack()
	_strength_label.text = "%d" % hero.strength
	_agility_label.text = "%d" % hero.agility
	var shield_item: ItemDefinition = ItemCatalog.get_item(hero.equipped_shield_id)
	_defense_label.text = "%d" % (shield_item.defense_bonus if shield_item != null else hero.defense)
	_set_equipment(_weapon_icon, _weapon_name, hero.equipped_weapon_id, "Оружие: не найдено")
	_set_equipment(_shield_icon, _shield_name, hero.equipped_shield_id, "Щит: не найден")
	if _selected_index < 0 or _selected_index >= _entries.size() or _entries[_selected_index].is_empty():
		_selected_index = _first_occupied_slot()
	for index in range(_entries.size()):
		var item_id: String = _entries[index]
		var definition: ItemDefinition = ItemCatalog.get_item(item_id) if not item_id.is_empty() else null
		var quantity: int = int(_session.carried_items.get(item_id, 0)) if definition != null and definition.stackable else 1
		var slot := InventoryGridSlot.new()
		_bag_grid.add_child(slot)
		slot.configure(index, definition, quantity, index == _selected_index, _bag_cell_size)
		slot.activated.connect(_show_item)
		slot.moved.connect(_move_slot)
	if _selected_index < 0:
		_clear_item_info()
	else:
		_show_item(_selected_index)


func _first_occupied_slot() -> int:
	for index in range(_entries.size()):
		if not _entries[index].is_empty():
			return index
	return -1


func _move_slot(from_index: int, to_index: int) -> void:
	if _session == null or not _session.swap_inventory_slots(from_index, to_index):
		return
	_selected_index = to_index
	_refresh_contents()


func _set_equipment(icon_node: TextureRect, name_node: Label, item_id: String, empty_text: String) -> void:
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	icon_node.texture = item.icon if item != null else null
	name_node.text = item.display_name if item != null else empty_text


func _clear_item_info() -> void:
	_item_icon.texture = null
	_item_name.text = "Нет предметов"
	_item_description.text = ""
	_item_properties.text = ""
	_use_button.visible = false


func _show_item(index: int) -> void:
	if index < 0 or index >= _entries.size() or _session == null:
		return
	var item_id := _entries[index]
	if item_id.is_empty():
		return
	_selected_index = index
	for child in _bag_grid.get_children():
		if child is InventoryGridSlot:
			var definition: ItemDefinition = ItemCatalog.get_item(child.item_id) if not child.item_id.is_empty() else null
			var quantity: int = int(_session.carried_items.get(child.item_id, 0)) if definition != null and definition.stackable else 1
			child.configure(child.slot_index, definition, quantity, child.slot_index == _selected_index, _bag_cell_size)
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	if item == null:
		return
	_item_icon.texture = item.icon
	_item_name.text = item.display_name
	_item_description.text = item.get_description()
	_use_feedback.text = ""
	_use_button.visible = item.category == ItemDefinition.Category.CONSUMABLE or item.category == ItemDefinition.Category.EQUIPMENT
	if item.category == ItemDefinition.Category.EQUIPMENT:
		_use_button.text = "Снять" if _is_equipped(item_id) else "Надеть"
	else:
		_use_button.text = "Использовать"
	var category := "Квестовый предмет"
	match item.category:
		ItemDefinition.Category.CONSUMABLE:
			category = "Расходник"
		ItemDefinition.Category.EQUIPMENT:
			category = "Снаряжение"
		ItemDefinition.Category.CURRENCY:
			category = "Валюта"
	var details := category
	var count: int = int(_session.carried_items.get(item_id, 0))
	if item.stackable:
		details += "  ·  количество: %d" % count
	match item.consumable_effect:
		ItemDefinition.ConsumableEffect.HEAL:
			details += "\nВосстанавливает: до %d HP" % item.healing_amount
		ItemDefinition.ConsumableEffect.ATTACK:
			details += "\nАтака: +%d на %s" % [item.effect_value, DescriptionTemplate.phases(item.effect_duration_phases)]
		ItemDefinition.ConsumableEffect.RESIST:
			details += "\nПолучаемый урон: −%d%% на %s" % [item.effect_value, DescriptionTemplate.phases(item.effect_duration_phases)]
		ItemDefinition.ConsumableEffect.VISION:
			details += "\nОбзор: +%d на %s" % [item.effect_value, DescriptionTemplate.phases(item.effect_duration_phases)]
		_:
			if item.healing_amount > 0:
				details += "\nВосстанавливает: до %d HP" % item.healing_amount
	if item.weapon_damage > 0:
		details += "\nУрон оружия: %d (%s)" % [item.weapon_damage, "дальний" if item.weapon_kind == ItemDefinition.WeaponKind.RANGED else "ближний"]
	if item.defense_bonus > 0:
		details += "\nБлок: +%d" % item.defense_bonus
		if item.max_durability > 0:
			details += "\nПрочность: %d / %d" % [_session.hero.current_shield_durability(item_id), item.max_durability]
	if _is_equipped(item_id):
		details += "\nНадето"
	_item_properties.text = details


func _is_equipped(item_id: String) -> bool:
	if _session == null or _session.hero == null:
		return false
	return item_id == _session.hero.equipped_weapon_id or item_id == _session.hero.equipped_shield_id


func _request_use_selected() -> void:
	if _selected_index < 0 or _selected_index >= _entries.size() or _session == null:
		return
	var item_id: String = _entries[_selected_index]
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	if item == null:
		return
	if item.category == ItemDefinition.Category.EQUIPMENT:
		equipment_requested.emit(item_id, not _is_equipped(item_id))
	elif item.category == ItemDefinition.Category.CONSUMABLE:
		item_use_requested.emit(item_id)


## Обновляем количество и характеристики, сохраняя выбранный предмет при возможности.
func show_use_result(item_id: String, message: String) -> void:
	if _session == null:
		return
	_refresh_contents()
	var index: int = _entries.find(item_id)
	if index >= 0:
		_show_item(index)
	_use_feedback.text = message


## Обновляем слоты, подписи и характеристики после смены экипировки.
func show_equipment_result(item_id: String, message: String = "") -> void:
	if _session == null:
		return
	_refresh_contents()
	var index: int = _entries.find(item_id)
	if index >= 0:
		_show_item(index)
	_use_feedback.text = message


func _resize_card() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_columns.columns = 1 if viewport_size.x < 1050.0 else 2
	_card.custom_minimum_size = Vector2(
		minf(1110.0, maxf(300.0, viewport_size.x - 24.0)),
		minf(660.0, maxf(240.0, viewport_size.y - 24.0))
	)
	var available_width: float = _card.custom_minimum_size.x - 86.0
	if _columns.columns == 2:
		available_width -= 325.0
	var cell: float = clampf((available_width - 9.0 * 4.0) / 10.0, 24.0, 56.0)
	_bag_cell_size = cell
	if _session != null:
		_refresh_contents()


func close_by_player() -> void:
	dismiss()
	closed.emit()


func dismiss() -> void:
	hide()
	_session = null

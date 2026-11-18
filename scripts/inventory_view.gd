class_name InventoryView
extends CanvasLayer

## Только представление: предметы и экипировка принадлежат GameSession/HeroState.
## Изменение состояния предметов выполняет игровой контроллер, а не UI.
signal closed
signal item_use_requested(item_id: String)
signal equipment_requested(item_id: String, equip: bool)

@onready var _card: PanelContainer = %Card
@onready var _columns: GridContainer = %Columns
@onready var _item_list: ItemList = %ItemList
@onready var _empty_label: Label = %EmptyLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _attack_label: Label = %AttackLabel
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


func _ready() -> void:
	_item_list.item_selected.connect(_show_item)
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
	if _entries.is_empty():
		_close_button.grab_focus()
	else:
		_item_list.grab_focus()


func _refresh_contents() -> void:
	_item_list.clear()
	_entries.clear()
	var hero: HeroState = _session.hero
	_gold_label.text = "Золото: %d" % hero.gold
	_attack_label.text = "Атака: %d" % hero.attack
	var shield_item: ItemDefinition = ItemCatalog.get_item(hero.equipped_shield_id)
	_defense_label.text = "Блок: %d" % (shield_item.defense_bonus if shield_item != null else hero.defense)
	_set_equipment(_weapon_icon, _weapon_name, hero.equipped_weapon_id, "Оружие: не найдено")
	_set_equipment(_shield_icon, _shield_name, hero.equipped_shield_id, "Щит: не найден")

	# Расходники лежат стопками, а каждый экземпляр экипировки виден отдельно.
	var item_ids: Array[String] = []
	for item_id in _session.carried_items.keys():
		item_ids.append(str(item_id))
	item_ids.sort()
	for item_id in item_ids:
		var definition: ItemDefinition = ItemCatalog.get_item(item_id)
		if definition == null:
			continue
		var quantity: int = int(_session.carried_items.get(item_id, 0))
		if quantity <= 0:
			continue
		if definition.stackable:
			_add_entry(item_id, "%s  ×%d" % [definition.display_name, quantity], definition.icon)
		else:
			for index in range(quantity):
				var label := definition.display_name
				if definition.equipment_slot == ItemDefinition.EquipmentSlot.SHIELD:
					var values: Array = hero.shield_durabilities.get(item_id, [])
					if index < values.size():
						label += "  ·  %d/%d" % [int(values[index]), definition.max_durability]
				if index == 0 and item_id in [hero.equipped_weapon_id, hero.equipped_shield_id]:
					label += "  ·  надето"
				_add_entry(item_id, label, definition.icon)
	_empty_label.visible = _entries.is_empty()
	if _entries.is_empty():
		_clear_item_info()
	else:
		_item_list.select(0)
		_show_item(0)


func _add_entry(item_id: String, label: String, icon: Texture2D) -> void:
	_item_list.add_item(label, icon)
	_entries.append(item_id)


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
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	if item == null:
		return
	_item_icon.texture = item.icon
	_item_name.text = item.display_name
	_item_description.text = item.description
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
			details += "\nАтака: +%d на %d шагов" % [item.effect_value, item.effect_duration_steps]
		ItemDefinition.ConsumableEffect.RESIST:
			details += "\nПолучаемый урон: −%d%% на %d шагов" % [item.effect_value, item.effect_duration_steps]
		ItemDefinition.ConsumableEffect.VISION:
			details += "\nОбзор: +%d на %d шагов" % [item.effect_value, item.effect_duration_steps]
		_:
			if item.healing_amount > 0:
				details += "\nВосстанавливает: до %d HP" % item.healing_amount
	if item.attack_bonus > 0:
		details += "\nАтака: +%d" % item.attack_bonus
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
	var selected: PackedInt32Array = _item_list.get_selected_items()
	var index: int = selected[0] if not selected.is_empty() else -1
	if index < 0 or index >= _entries.size() or _session == null:
		return
	var item_id: String = _entries[index]
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
		_item_list.select(index)
		_show_item(index)
	_use_feedback.text = message


## Обновляем слоты, подписи и характеристики после смены экипировки.
func show_equipment_result(item_id: String, message: String = "") -> void:
	if _session == null:
		return
	_refresh_contents()
	var index: int = _entries.find(item_id)
	if index >= 0:
		_item_list.select(index)
		_show_item(index)
	_use_feedback.text = message


func _resize_card() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	# На узком экране список и описание идут друг под другом.
	_columns.columns = 1 if viewport_size.x < 700.0 else 2
	_card.custom_minimum_size = Vector2(
		minf(760.0, maxf(260.0, viewport_size.x - 28.0)),
		minf(530.0, maxf(240.0, viewport_size.y - 28.0))
	)


func close_by_player() -> void:
	dismiss()
	closed.emit()


func dismiss() -> void:
	hide()
	_session = null

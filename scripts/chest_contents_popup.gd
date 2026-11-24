class_name ChestContentsPopup
extends MobileKeyboardPopup

## Редактор количества наград для сундуков и монстров. Карта хранит ID и количества.
signal contents_changed(entity_id: String, contents: Array[String], gold_amount: int, random_mode: bool, hidden: bool, quantities: Dictionary)
signal monster_configuration_changed(entity_id: String, party: Array[String], contents: Array[String], gold_amount: int, random_mode: bool, hidden: bool, quantities: Dictionary)

@onready var _title: Label = %Title
@onready var _random_check: CheckBox = %RandomCheck
@onready var _hidden_check: CheckBox = %HiddenCheck
@onready var _rows: VBoxContainer = %LootRows
@onready var _scroll: ScrollContainer = %LootScroll
@onready var _monster_party: VBoxContainer = %MonsterParty
@onready var _primary_monster: Label = %PrimaryMonster
@onready var _secondary_monster: OptionButton = %SecondaryMonster

const CATEGORY_NAMES := ["Ключи", "Зелья", "Оружие", "Щиты", "Шлемы", "Броня", "Перчатки", "Сапоги", "Амулеты", "Снаряжение", "Прочее"]
const CATEGORY_ICONS := {
	"Ключи": preload("res://assets/icons/key.png"),
	"Зелья": preload("res://assets/icons/stats/24x24/potion.png"),
	"Оружие": preload("res://assets/icons/sword.png"),
	"Щиты": preload("res://assets/icons/shield.png"),
	"Шлемы": preload("res://assets/icons/helmets/helmet_leather.png"),
	"Броня": preload("res://assets/icons/armors/armor_leather_vest.png"),
	"Перчатки": preload("res://assets/icons/gloves/gloves_cloth_wraps.png"),
	"Сапоги": preload("res://assets/icons/boots/boots_leather_ankle.png"),
	"Амулеты": preload("res://assets/icons/amulets/amulet_knotted_cord.png"),
	"Снаряжение": preload("res://assets/icons/equipment_slots/armor.png"),
	"Прочее": preload("res://assets/icons/gold.png"),
}
const AMOUNT_WIDTH := 94.0

var _entity_id: String = ""
var _editing_monster: bool = false
var _primary_monster_id: String = ""
var _item_checks: Dictionary = {} # id -> CheckBox
var _item_amounts: Dictionary = {} # id -> SpinBox
var _unlisted_quantities: Dictionary = {}
var _group_buttons: Dictionary = {} # category -> Button
var _group_contents: Dictionary = {} # category -> VBoxContainer
var _editing_amount: SpinBox


func _ready() -> void:
	%SaveButton.pressed.connect(_save)
	%CancelButton.pressed.connect(hide)
	%KeyboardDoneButton.pressed.connect(_finish_amount)
	%KeyboardDoneButton.visible = false
	_random_check.toggled.connect(_refresh_enabled)
	_secondary_monster.add_theme_constant_override("icon_max_width", 32)
	_secondary_monster.get_popup().add_theme_constant_override("icon_max_width", 32)
	_build_item_rows()


func _build_item_rows() -> void:
	var weapons: Array[String] = []
	var shields: Array[String] = []
	var helmets: Array[String] = []
	var armor: Array[String] = []
	var gloves: Array[String] = []
	var boots: Array[String] = []
	var amulets: Array[String] = []
	var other_equipment: Array[String] = []
	for item_id in ItemCatalog.equipment_ids():
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		match item.equipment_slot:
			ItemDefinition.EquipmentSlot.WEAPON:
				weapons.append(item_id)
			ItemDefinition.EquipmentSlot.SHIELD:
				shields.append(item_id)
			ItemDefinition.EquipmentSlot.HEAD:
				helmets.append(item_id)
			ItemDefinition.EquipmentSlot.BODY:
				armor.append(item_id)
			ItemDefinition.EquipmentSlot.GLOVES:
				gloves.append(item_id)
			ItemDefinition.EquipmentSlot.BOOTS:
				boots.append(item_id)
			ItemDefinition.EquipmentSlot.NECK:
				amulets.append(item_id)
			_:
				other_equipment.append(item_id)
	var potions: Array[String] = ["potion"]
	for kind in ["health", "strength", "vitality", "vision"]:
		for grade in ["small", "medium", "large"]:
			potions.append("potion_%s_%s" % [kind, grade])
	var groups: Array[Dictionary] = [
		{"title": "Ключи", "items": LockCatalog.LOCK_IDS},
		{"title": "Зелья", "items": potions},
		{"title": "Оружие", "items": weapons},
		{"title": "Щиты", "items": shields},
		{"title": "Шлемы", "items": helmets},
		{"title": "Броня", "items": armor},
		{"title": "Перчатки", "items": gloves},
		{"title": "Сапоги", "items": boots},
		{"title": "Амулеты", "items": amulets},
		{"title": "Снаряжение", "items": other_equipment},
		{"title": "Прочее", "items": ["gold"]}
	]
	for group in groups:
		var category: String = str(group["title"])
		var header := Button.new()
		header.text = "▸  %s" % category
		header.icon = CATEGORY_ICONS[category]
		header.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.expand_icon = true
		header.add_theme_constant_override("icon_max_width", 28)
		header.add_theme_constant_override("h_separation", 10)
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.custom_minimum_size.y = 44
		header.focus_mode = Control.FOCUS_NONE
		_rows.add_child(header)
		var body := VBoxContainer.new()
		body.visible = false
		body.add_theme_constant_override("separation", 4)
		_rows.add_child(body)
		_group_buttons[category] = header
		_group_contents[category] = body
		header.pressed.connect(_toggle_group.bind(category))
		for item_id in group["items"]:
			_add_item_row(body, str(item_id))


func _add_item_row(parent: VBoxContainer, item_id: String) -> void:
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	if item == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size.y = 44
	parent.add_child(row)

	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var check := CheckBox.new()
	check.text = item.display_name
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.custom_minimum_size.y = 44
	row.add_child(check)
	_item_checks[item_id] = check

	var amount := SpinBox.new()
	amount.custom_minimum_size = Vector2(AMOUNT_WIDTH, 44)
	amount.min_value = 1
	amount.max_value = 999999 if item_id == "gold" else 9999
	amount.step = 1
	amount.rounded = true
	amount.value = item.default_quantity
	amount.tooltip_text = "Количество: %s" % item.display_name
	row.add_child(amount)
	_item_amounts[item_id] = amount

	var amount_input := amount.get_line_edit()
	amount_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	amount_input.keep_editing_on_text_submit = false
	amount_input.text_submitted.connect(_on_amount_submitted.bind(amount))
	amount_input.focus_entered.connect(_on_amount_focused.bind(amount))
	check.toggled.connect(_on_item_toggled.bind(item_id))


func _toggle_group(category: String) -> void:
	var body: VBoxContainer = _group_contents[category]
	body.visible = not body.visible
	var header: Button = _group_buttons[category]
	header.text = ("▾  " if body.visible else "▸  ") + category


func configure(entity_id: String, contents: Array[String], gold_amount: int = 5, is_monster: bool = false, random_mode: bool = true, hidden: bool = false, quantities: Dictionary = {}, monster_ids: Array[String] = []) -> void:
	_random_check.show()
	_hidden_check.show()
	_entity_id = entity_id
	_editing_monster = is_monster
	_title.text = "Настройки монстров" if is_monster else "Содержимое сундука"
	_monster_party.visible = is_monster
	if is_monster:
		_primary_monster_id = monster_ids[0] if not monster_ids.is_empty() else MonsterCatalog.DEFAULT_MONSTER_ID
		var main_definition: MonsterDefinition = MonsterCatalog.get_monster(_primary_monster_id)
		_primary_monster.text = "1. %s" % main_definition.display_name
		_secondary_monster.clear()
		_secondary_monster.add_item("Нет второго монстра")
		_secondary_monster.set_item_metadata(0, "")
		var selected_id: String = monster_ids[1] if monster_ids.size() > 1 else ""
		var selection_index: int = 0
		for monster_id in MonsterCatalog.list_placeable_ids():
			var monster: MonsterDefinition = MonsterCatalog.get_monster(monster_id)
			var index: int = _secondary_monster.item_count
			_secondary_monster.add_icon_item(monster.icon, monster.display_name)
			_secondary_monster.set_item_metadata(index, monster_id)
			if monster_id == selected_id:
				selection_index = index
		_secondary_monster.select(selection_index)
	_unlisted_quantities.clear()
	for item_id in contents:
		if not _item_checks.has(item_id) and ItemCatalog.has(item_id):
			var item: ItemDefinition = ItemCatalog.get_item(item_id)
			_unlisted_quantities[item_id] = int(quantities.get(item_id, gold_amount if item_id == "gold" else item.default_quantity))
	_random_check.set_pressed_no_signal(random_mode)
	_hidden_check.set_pressed_no_signal(hidden)
	for item_id in _item_checks:
		var check: CheckBox = _item_checks[item_id]
		check.set_pressed_no_signal(item_id in contents or (item_id == "key" and "key_yellow" in contents))
		var definition: ItemDefinition = ItemCatalog.get_item(item_id)
		var fallback: int = gold_amount if item_id == "gold" else definition.default_quantity
		(_item_amounts[item_id] as SpinBox).value = int(quantities.get(item_id, fallback))
	for category in CATEGORY_NAMES:
		var body: VBoxContainer = _group_contents[category]
		body.visible = false
		(_group_buttons[category] as Button).text = "▸  " + category
	_refresh_enabled()


func _on_item_toggled(_pressed: bool, item_id: String) -> void:
	var amount: SpinBox = _item_amounts[item_id]
	amount.editable = not _random_check.button_pressed and (_item_checks[item_id] as CheckBox).button_pressed


func _refresh_enabled(_pressed: bool = false) -> void:
	var is_random: bool = _random_check.button_pressed
	for item_id in _item_checks:
		var check: CheckBox = _item_checks[item_id]
		check.disabled = is_random
		(_item_amounts[item_id] as SpinBox).editable = not is_random and check.button_pressed


func _on_amount_focused(amount: SpinBox) -> void:
	_editing_amount = amount
	# Поле прокручивается к видимой области после размещения/ресайза окна.
	_scroll.call_deferred("ensure_control_visible", amount)


func _keyboard_layout_changed(open: bool) -> void:
	%KeyboardDoneButton.visible = open
	if open and _editing_amount != null:
		_scroll.call_deferred("ensure_control_visible", _editing_amount)


func _on_amount_submitted(_text: String, amount: SpinBox) -> void:
	close_soft_keyboard(amount.get_line_edit())


func _finish_amount() -> void:
	if _editing_amount != null:
		_editing_amount.apply()
		close_soft_keyboard(_editing_amount.get_line_edit())


func _save() -> void:
	_finish_amount()
	var contents: Array[String] = []
	var quantities: Dictionary = {}
	for item_id in _item_checks:
		if (_item_checks[item_id] as CheckBox).button_pressed:
			var amount: SpinBox = _item_amounts[item_id]
			amount.apply()
			contents.append(item_id)
			quantities[item_id] = int(amount.value)
	for item_id in _unlisted_quantities:
		if item_id not in contents:
			contents.append(item_id)
			quantities[item_id] = _unlisted_quantities[item_id]
	var gold_amount: int = int(quantities.get("gold", 5))
	if _editing_monster:
		var party: Array[String] = [_primary_monster_id]
		var secondary_id: String = str(_secondary_monster.get_selected_metadata())
		if not secondary_id.is_empty():
			party.append(secondary_id)
		monster_configuration_changed.emit(_entity_id, party, contents, gold_amount, _random_check.button_pressed, _hidden_check.button_pressed, quantities)
	else:
		contents_changed.emit(_entity_id, contents, gold_amount, _random_check.button_pressed, _hidden_check.button_pressed, quantities)
	hide()


func configure_exit(entity: Dictionary) -> void:
	configure(str(entity["id"]), DungeonMap.chest_contents(entity), DungeonMap.chest_gold_amount(entity), false, false, false, DungeonMap.chest_item_quantities(entity))
	_title.text = "Награда за прохождение"
	_random_check.hide()
	_hidden_check.hide()

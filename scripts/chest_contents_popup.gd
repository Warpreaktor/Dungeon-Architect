class_name ChestContentsPopup
extends MobileKeyboardPopup

## Редактор количества наград для сундуков и монстров. Карта хранит ID и количества.
signal contents_changed(entity_id: String, contents: Array[String], gold_amount: int, random_mode: bool, hidden: bool, quantities: Dictionary, reward_level: int)
signal monster_configuration_changed(entity_id: String, party: Array[String], contents: Array[String], gold_amount: int, random_mode: bool, hidden: bool, quantities: Dictionary, reward_level: int)

@onready var _title: Label = %Title
@onready var _random_check: CheckBox = %RandomCheck
@onready var _reward_level: OptionButton = %RewardLevel
@onready var _loot_preview: Label = %LootPreview
@onready var _hidden_check: CheckBox = %HiddenCheck
@onready var _rows: VBoxContainer = %LootRows
@onready var _scroll: ScrollContainer = %LootScroll
@onready var _monster_party: VBoxContainer = %MonsterParty
@onready var _monster_slots: HBoxContainer = %MonsterSlots

const CATEGORY_NAMES := ["Ключи", "Зелья", "Оружие", "Щиты", "Шлемы", "Броня", "Перчатки", "Сапоги", "Пояса", "Амулеты", "Кольца", "Прочее"]
const CATEGORY_ICONS := {
	"Ключи": preload("res://assets/icons/keys/key.png"),
	"Зелья": preload("res://assets/icons/stats/24x24/potion.png"),
	"Оружие": preload("res://assets/icons/weapons/sword.png"),
	"Щиты": preload("res://assets/icons/shields/shield.png"),
	"Шлемы": preload("res://assets/icons/helmets/helmet_leather.png"),
	"Броня": preload("res://assets/icons/armors/armor_leather_vest.png"),
	"Перчатки": preload("res://assets/icons/gloves/gloves_cloth_wraps.png"),
	"Сапоги": preload("res://assets/icons/boots/boots_leather_ankle.png"),
	"Пояса": preload("res://assets/icons/belts/belt_rope.png"),
	"Амулеты": preload("res://assets/icons/amulets/amulet_knotted_cord.png"),
	"Кольца": preload("res://assets/icons/rings/ring_copper_wire.png"),
	"Прочее": preload("res://assets/icons/currency/gold.png"),
}
const AMOUNT_WIDTH := 94.0

var _entity_id: String = ""
var _editing_monster: bool = false
var _source: Dictionary = {}
var _monster_slot_ids: Array[String] = []
var _monster_slot_buttons: Array[Button] = []
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
	for level in range(1, LootProfile.REWARD_LEVELS.size() + 1):
		_reward_level.add_item("Уровень награды %d" % level, level)
	_reward_level.item_selected.connect(func(_index: int) -> void: _refresh_preview())
	_build_monster_slots()
	_build_item_rows()


func _build_monster_slots() -> void:
	for index in range(DungeonMap.MAX_MONSTERS_PER_ENCOUNTER):
		var button: Button
		if index == 0:
			button = Button.new()
			button.disabled = true
			button.add_theme_color_override("icon_disabled_color", Color.WHITE)
		else:
			var menu := MenuButton.new()
			var choices: PopupMenu = menu.get_popup()
			choices.add_theme_constant_override("icon_max_width", 32)
			choices.add_item("Очистить", 0)
			choices.set_item_metadata(0, "")
			for monster_id in MonsterCatalog.list_placeable_ids():
				var monster: MonsterDefinition = MonsterCatalog.get_monster(monster_id)
				if MonsterCatalog.is_exclusive_encounter(monster):
					continue
				var item_index: int = choices.item_count
				choices.add_icon_item(monster.icon, monster.display_name, item_index)
				choices.set_item_metadata(item_index, monster_id)
			choices.id_pressed.connect(_on_monster_slot_choice.bind(index))
			button = menu
		button.name = "MonsterSlot%d" % (index + 1)
		button.custom_minimum_size = Vector2(48, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_constant_override("icon_max_width", 44)
		_monster_slots.add_child(button)
		_monster_slot_buttons.append(button)


func _configure_monster_slots(monster_ids: Array[String]) -> void:
	var definitions: Array[MonsterDefinition] = []
	for monster_id in monster_ids:
		definitions.append(MonsterCatalog.get_monster(monster_id))
	var normalized: Array[MonsterDefinition] = MonsterCatalog.normalize_legacy_encounter(definitions)
	_monster_slot_ids.clear()
	for index in range(DungeonMap.MAX_MONSTERS_PER_ENCOUNTER):
		_monster_slot_ids.append(normalized[index].monster_id if index < normalized.size() else "")
	_refresh_monster_slots()


func _refresh_monster_slots() -> void:
	var exclusive: bool = MonsterCatalog.is_exclusive_encounter(MonsterCatalog.get_monster(_monster_slot_ids[0]))
	for index in range(_monster_slot_buttons.size()):
		var button: Button = _monster_slot_buttons[index]
		var monster_id: String = _monster_slot_ids[index]
		var monster: MonsterDefinition = MonsterCatalog.get_monster(monster_id) if not monster_id.is_empty() else null
		button.disabled = index == 0 or exclusive
		button.icon = monster.icon if monster != null else null
		button.text = ("×" if exclusive else "+") if monster == null else ""
		button.tooltip_text = monster.display_name if monster != null else ""


func _on_monster_slot_choice(item_id: int, slot_index: int) -> void:
	if not _editing_monster or slot_index <= 0 or slot_index >= _monster_slot_buttons.size():
		return
	var button: MenuButton = _monster_slot_buttons[slot_index] as MenuButton
	if button.disabled:
		return
	var choices: PopupMenu = button.get_popup()
	var item_index: int = choices.get_item_index(item_id)
	if item_index < 0:
		return
	var monster_id: String = str(choices.get_item_metadata(item_index))
	if not monster_id.is_empty() and (not MonsterCatalog.has(monster_id) or MonsterCatalog.is_bond_companion(monster_id) or MonsterCatalog.is_exclusive_encounter(MonsterCatalog.get_monster(monster_id))):
		return
	_monster_slot_ids[slot_index] = monster_id
	_refresh_monster_slots()
	_refresh_preview()


func _selected_monster_party() -> Array[String]:
	var party: Array[String] = []
	for monster_id in _monster_slot_ids:
		if not monster_id.is_empty():
			party.append(monster_id)
	return party


func _build_item_rows() -> void:
	var weapons: Array[String] = []
	var shields: Array[String] = []
	var helmets: Array[String] = []
	var armor: Array[String] = []
	var gloves: Array[String] = []
	var boots: Array[String] = []
	var belts: Array[String] = []
	var amulets: Array[String] = []
	var rings: Array[String] = []
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
			ItemDefinition.EquipmentSlot.BELT:
				belts.append(item_id)
			ItemDefinition.EquipmentSlot.NECK:
				amulets.append(item_id)
			ItemDefinition.EquipmentSlot.RING:
				rings.append(item_id)
	var potions: Array[String] = ItemCatalog.consumable_ids()
	var other: Array[String] = []
	for item_id in ItemCatalog.list_ids():
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		if item != null and item_id not in LockCatalog.LOCK_IDS and item.category not in [ItemDefinition.Category.CONSUMABLE, ItemDefinition.Category.EQUIPMENT]:
			other.append(item_id)
	var groups: Array[Dictionary] = [
		{"title": "Ключи", "items": LockCatalog.LOCK_IDS},
		{"title": "Зелья", "items": potions},
		{"title": "Оружие", "items": weapons},
		{"title": "Щиты", "items": shields},
		{"title": "Шлемы", "items": helmets},
		{"title": "Броня", "items": armor},
		{"title": "Перчатки", "items": gloves},
		{"title": "Сапоги", "items": boots},
		{"title": "Пояса", "items": belts},
		{"title": "Амулеты", "items": amulets},
		{"title": "Кольца", "items": rings},
		{"title": "Прочее", "items": other}
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


func configure(entity_id: String, contents: Array[String], gold_amount: int = 5, is_monster: bool = false, random_mode: bool = true, hidden: bool = false, quantities: Dictionary = {}, monster_ids: Array[String] = [], source: Dictionary = {}) -> void:
	_random_check.show()
	_hidden_check.show()
	_entity_id = entity_id
	_editing_monster = is_monster
	_source = source.duplicate(true)
	if _source.is_empty():
		_source = {"type": "monster" if is_monster else "chest", "properties": {}}
	_reward_level.select(DungeonMap.loot_level(_source) - 1)
	_title.text = "Настройки монстров" if is_monster else ("Содержимое сундука" if DungeonMap.chest_variant(_source) == "chest" else DungeonMap.chest_variant_name(DungeonMap.chest_variant(_source)))
	_monster_party.visible = is_monster
	if is_monster:
		_configure_monster_slots(monster_ids)
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
	_scroll.set_deferred("scroll_vertical", 0)
	_scroll.set_deferred("scroll_horizontal", 0)


func _on_item_toggled(_pressed: bool, item_id: String) -> void:
	var amount: SpinBox = _item_amounts[item_id]
	amount.editable = (_item_checks[item_id] as CheckBox).button_pressed


func _refresh_enabled(_pressed: bool = false) -> void:
	for item_id in _item_checks:
		var check: CheckBox = _item_checks[item_id]
		(_item_amounts[item_id] as SpinBox).editable = check.button_pressed
	_refresh_preview()


func reward_level() -> int:
	return LootProfile.normalize_level(_reward_level.get_selected_id())


func _preview_source() -> Dictionary:
	var source: Dictionary = _source.duplicate(true)
	if _editing_monster:
		var party: Array[String] = _selected_monster_party()
		if not party.is_empty():
			var properties: Dictionary = source.get("properties", {})
			properties["monster_id"] = party[0]
			properties["monster_ids"] = party.slice(1)
			source["properties"] = properties
	return source


func _refresh_preview() -> void:
	_loot_preview.visible = _random_check.button_pressed
	if not _loot_preview.visible:
		return
	var profile: LootProfile = LootProfileCatalog.for_source(_preview_source())
	var level: int = reward_level()
	var rules: LootRewardLevel = LootProfile.level_rules(level)
	var ids: Array[String] = profile.possible_item_ids(level) if profile != null else ItemCatalog.possible_loot_ids(rules.stage_for(ItemCatalog.LOOT_TABLE, 0, 0))
	var categories: PackedStringArray = []
	for item_id in ids:
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		if item == null:
			continue
		var category: String = _preview_category(item)
		if not categories.has(category):
			categories.append(category)
	var profile_name: String = profile.display_name if profile != null else "Обычная добыча"
	_loot_preview.text = "%s\nСлучайная добыча (без учёта прогресса): %s" % [profile_name, ", ".join(categories)]


func _preview_category(item: ItemDefinition) -> String:
	match item.category:
		ItemDefinition.Category.CURRENCY:
			return "Золото"
		ItemDefinition.Category.CONSUMABLE:
			return "Зелья"
		ItemDefinition.Category.QUEST:
			return "Ключи"
		ItemDefinition.Category.EQUIPMENT:
			match item.equipment_slot:
				ItemDefinition.EquipmentSlot.WEAPON: return "Оружие"
				ItemDefinition.EquipmentSlot.SHIELD: return "Щиты"
				ItemDefinition.EquipmentSlot.HEAD: return "Шлемы"
				ItemDefinition.EquipmentSlot.BODY: return "Броня"
				ItemDefinition.EquipmentSlot.GLOVES: return "Перчатки"
				ItemDefinition.EquipmentSlot.BOOTS: return "Сапоги"
				ItemDefinition.EquipmentSlot.BELT: return "Пояса"
				ItemDefinition.EquipmentSlot.NECK: return "Амулеты"
				ItemDefinition.EquipmentSlot.RING: return "Кольца"
	return "Прочее"


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
		var party: Array[String] = _selected_monster_party()
		if not DungeonMap.valid_monster_party(party):
			return
		monster_configuration_changed.emit(_entity_id, party, contents, gold_amount, _random_check.button_pressed, _hidden_check.button_pressed, quantities, reward_level())
	else:
		contents_changed.emit(_entity_id, contents, gold_amount, _random_check.button_pressed, _hidden_check.button_pressed, quantities, reward_level())
	hide()


func configure_exit(entity: Dictionary) -> void:
	configure(str(entity["id"]), DungeonMap.chest_contents(entity), DungeonMap.chest_gold_amount(entity), false, DungeonMap.chest_is_random(entity), false, DungeonMap.chest_item_quantities(entity), [], entity)
	_title.text = "Награда за прохождение"
	_hidden_check.hide()

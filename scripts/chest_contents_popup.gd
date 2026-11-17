class_name ChestContentsPopup
extends MobileKeyboardPopup

## Общая панель настройки наград сундуков и монстров; типы берутся из ItemCatalog.
signal contents_changed(entity_id: String, contents: Array[String], gold_amount: int, random_mode: bool, hidden: bool)

@onready var _title: Label = %Title
@onready var _random_check: CheckBox = %RandomCheck
@onready var _hidden_check: CheckBox = %HiddenCheck
@onready var _rows: VBoxContainer = %LootRows
@onready var _gold_amount: SpinBox = %GoldAmount
@onready var _gold_row: HBoxContainer = $ContentMargin/Content/GoldRow

var _entity_id: String = ""
var _item_checks: Dictionary = {} # item_id -> CheckBox


func _ready() -> void:
	%SaveButton.pressed.connect(_save)
	%CancelButton.pressed.connect(hide)
	_random_check.toggled.connect(_refresh_enabled)
	_build_item_rows()
	var amount_input := _gold_amount.get_line_edit()
	amount_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	amount_input.keep_editing_on_text_submit = false
	amount_input.text_submitted.connect(_on_amount_submitted)
	%KeyboardDoneButton.pressed.connect(_finish_amount)
	%KeyboardDoneButton.visible = OS.has_feature("mobile")


func _build_item_rows() -> void:
	var weapons: Array[String] = []
	var shields: Array[String] = []
	for item_id in ItemCatalog.equipment_ids():
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		if item.equipment_slot == ItemDefinition.EquipmentSlot.WEAPON:
			weapons.append(item_id)
		else:
			shields.append(item_id)
	var potions: Array[String] = ["potion"]
	for kind in ["health", "strength", "vitality", "vision"]:
		for grade in ["small", "medium", "large"]:
			potions.append("potion_%s_%s" % [kind, grade])
	var groups: Array = [
		{"title": "ПРЕДМЕТЫ", "items": LockCatalog.LOCK_IDS + ["gold"]},
		{"title": "ЗЕЛЬЯ", "items": potions},
		{"title": "ОРУЖИЕ", "items": weapons},
		{"title": "ЩИТЫ", "items": shields}
	]
	for group in groups:
		var title := Label.new()
		title.text = str(group["title"])
		title.add_theme_color_override("font_color", Color(0.84, 0.67, 0.40))
		_rows.add_child(title)
		for item_id in group["items"]:
			var item: ItemDefinition = ItemCatalog.get_item(item_id)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			var icon := TextureRect.new()
			icon.texture = item.icon
			icon.custom_minimum_size = Vector2(34, 34)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon)
			var check := CheckBox.new()
			check.mouse_filter = Control.MOUSE_FILTER_PASS
			check.text = item.display_name
			check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			check.toggled.connect(_refresh_enabled)
			row.add_child(check)
			_rows.add_child(row)
			_item_checks[item_id] = check


func configure(entity_id: String, contents: Array[String], gold_amount: int = 5, is_monster: bool = false, random_mode: bool = true, hidden: bool = false) -> void:
	_entity_id = entity_id
	_title.text = "Награда за победу" if is_monster else "Содержимое сундука"
	_random_check.set_pressed_no_signal(random_mode)
	_hidden_check.set_pressed_no_signal(hidden)
	for item_id in _item_checks:
		var check: CheckBox = _item_checks[item_id]
		check.set_pressed_no_signal(item_id in contents or (item_id == "key" and "key_yellow" in contents))
	_gold_amount.value = gold_amount
	_refresh_enabled()


func _refresh_enabled(_value: bool = false) -> void:
	var is_random: bool = _random_check.button_pressed
	for check in _item_checks.values():
		(check as CheckBox).disabled = is_random
	_gold_row.visible = not is_random and (_item_checks["gold"] as CheckBox).button_pressed


func _keyboard_layout_changed(open: bool) -> void:
	# Пока редактируется сумма, список наград уступает место полю и кнопкам.
	%LootScroll.visible = not open


func _on_amount_submitted(_text: String) -> void:
	close_soft_keyboard(_gold_amount.get_line_edit())


func _finish_amount() -> void:
	_gold_amount.apply()
	close_soft_keyboard(_gold_amount.get_line_edit())


func _save() -> void:
	_gold_amount.apply()
	close_soft_keyboard(_gold_amount.get_line_edit())
	var contents: Array[String] = []
	for item_id in _item_checks:
		if (_item_checks[item_id] as CheckBox).button_pressed:
			contents.append(item_id)
	contents_changed.emit(_entity_id, contents, int(_gold_amount.value), _random_check.button_pressed, _hidden_check.button_pressed)
	hide()

class_name EditorPartyRulesPanel
extends VBoxContainer

signal rules_applied(metadata: Dictionary)

enum Access { AVAILABLE, REQUIRED, BLOCKED }

var _selectors: Dictionary = {}
var _apply_button: Button


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for id in HeroCatalog.list_ids():
		var row := HBoxContainer.new()
		rows.add_child(row)
		var label := Label.new()
		label.text = HeroCatalog.get_hero(id).display_name
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(label)
		var selector := OptionButton.new()
		selector.custom_minimum_size.y = 44
		selector.add_item("Доступен", Access.AVAILABLE)
		selector.add_item("Обязателен", Access.REQUIRED)
		selector.add_item("Запрещён", Access.BLOCKED)
		selector.item_selected.connect(_on_access_changed)
		row.add_child(selector)
		_selectors[id] = selector
	_apply_button = Button.new()
	_apply_button.text = "Применить"
	_apply_button.custom_minimum_size.y = 44
	_apply_button.pressed.connect(_apply)
	add_child(_apply_button)
	_on_access_changed(0)


func show_rules(metadata: Dictionary) -> void:
	var rules: HeroPartyRules = HeroPartyRules.from_metadata(metadata)
	for id in _selectors:
		var selector: OptionButton = _selectors[id]
		var access: int = Access.REQUIRED if rules.required_ids.has(id) else (Access.AVAILABLE if rules.allows(id) else Access.BLOCKED)
		selector.select(access)
	_on_access_changed(0)


func _draft_metadata() -> Dictionary:
	var allowed: Array[String] = []
	var required: Array[String] = []
	for id in _selectors:
		var selector: OptionButton = _selectors[id]
		if selector.get_selected_id() != Access.BLOCKED:
			allowed.append(id)
		if selector.get_selected_id() == Access.REQUIRED:
			required.append(id)
	if allowed.size() == _selectors.size() and required.is_empty():
		return {}
	return {HeroPartyRules.METADATA_KEY: {"allowed_ids": allowed, "required_ids": required}}


func _on_access_changed(_index: int) -> void:
	_apply_button.disabled = HeroPartyRules.from_metadata(_draft_metadata()) == null


func _apply() -> void:
	var metadata: Dictionary = _draft_metadata()
	if HeroPartyRules.from_metadata(metadata) != null:
		rules_applied.emit(metadata)

class_name EditorTestHeroPanel
extends MarginContainer

signal party_selected(hero_ids: Array[String])

const PANEL_MARGIN: int = 12
const PROPERTY_SPACING: int = 12
const LABEL_FONT_SIZE: int = 15
const HERO_SELECTOR_HEIGHT: int = 44

var selector: OptionButton
var second_selector: OptionButton
var third_selector: OptionButton


func _init() -> void:
	for margin_side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		add_theme_constant_override(margin_side, PANEL_MARGIN)
	var properties := VBoxContainer.new()
	properties.name = "TestProperties"
	properties.add_theme_constant_override("separation", PROPERTY_SPACING)
	add_child(properties)
	var title := Label.new()
	title.text = "Отряд для тестирования"
	title.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	title.add_theme_color_override("font_color", Color("#d5e0e7"))
	properties.add_child(title)
	var first_label := Label.new()
	first_label.text = "Первый герой"
	properties.add_child(first_label)
	selector = _make_selector("TestHeroSelect")
	properties.add_child(selector)
	var second_label := Label.new()
	second_label.text = "Второй герой"
	properties.add_child(second_label)
	second_selector = _make_selector("TestSecondHeroSelect", true)
	properties.add_child(second_selector)
	var third_label := Label.new()
	third_label.text = "Третий герой"
	properties.add_child(third_label)
	third_selector = _make_selector("TestThirdHeroSelect", true)
	properties.add_child(third_selector)


func _make_selector(node_name: String, optional: bool = false) -> OptionButton:
	var control := OptionButton.new()
	control.name = node_name
	control.custom_minimum_size.y = HERO_SELECTOR_HEIGHT
	if optional:
		control.add_item("Без второго героя")
		control.set_item_metadata(0, "")
	for hero_id in HeroCatalog.list_ids():
		var definition: HeroDefinition = HeroCatalog.get_hero(hero_id)
		if definition == null:
			continue
		control.add_item(definition.display_name)
		control.set_item_metadata(control.item_count - 1, hero_id)
	control.item_selected.connect(_on_selected)
	return control


func select_party(hero_ids: Array[String]) -> void:
	var first_id: String = hero_ids[0] if not hero_ids.is_empty() else HeroCatalog.DEFAULT_HERO_ID
	_select_id(selector, first_id)
	var second_id: String = hero_ids[1] if hero_ids.size() > 1 else ""
	_select_id(second_selector, second_id)
	var third_id: String = hero_ids[2] if hero_ids.size() > 2 else ""
	_select_id(third_selector, third_id)
	_refresh_second_selector()


func select_hero(hero_id: String) -> void:
	select_party([hero_id])


func _select_id(control: OptionButton, hero_id: String) -> void:
	for index in range(control.item_count):
		if str(control.get_item_metadata(index)) == hero_id:
			control.select(index)
			return
	if control.item_count > 0:
		control.select(0)


func selected_party() -> Array[String]:
	var heroes: Array[String] = []
	for control in [selector, second_selector, third_selector]:
		var hero_id: String = str(control.get_selected_metadata())
		if HeroCatalog.has(hero_id) and not heroes.has(hero_id):
			heroes.append(hero_id)
	return heroes


func _refresh_second_selector() -> void:
	var chosen: Array[String] = []
	for control in [selector, second_selector, third_selector]:
		var current_id: String = str(control.get_selected_metadata())
		if chosen.has(current_id) and not current_id.is_empty():
			_select_id(control, "")
			current_id = str(control.get_selected_metadata())
		for index in range(control.item_count):
			var item_id: String = str(control.get_item_metadata(index))
			control.set_item_disabled(index, chosen.has(item_id))
		if not current_id.is_empty():
			chosen.append(current_id)


func _on_selected(_index: int) -> void:
	_refresh_second_selector()
	party_selected.emit(selected_party())

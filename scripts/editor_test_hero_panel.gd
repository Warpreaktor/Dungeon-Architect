class_name EditorTestHeroPanel
extends MarginContainer

signal hero_selected(hero_id: String)

const PANEL_MARGIN: int = 12
const PROPERTY_SPACING: int = 12
const LABEL_FONT_SIZE: int = 15
const HINT_FONT_SIZE: int = 13
const HERO_SELECTOR_HEIGHT: int = 44

var selector: OptionButton


func _init() -> void:
	for margin_side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		add_theme_constant_override(margin_side, PANEL_MARGIN)
	var properties := VBoxContainer.new()
	properties.name = "TestProperties"
	properties.add_theme_constant_override("separation", PROPERTY_SPACING)
	add_child(properties)
	var title := Label.new()
	title.text = "Тестовый герой"
	title.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	title.add_theme_color_override("font_color", Color("#d5e0e7"))
	properties.add_child(title)
	selector = OptionButton.new()
	selector.name = "TestHeroSelect"
	selector.custom_minimum_size.y = HERO_SELECTOR_HEIGHT
	selector.tooltip_text = "Герой для временного тестового прохождения карты"
	for hero_id in HeroCatalog.list_ids():
		var definition: HeroDefinition = HeroCatalog.get_hero(hero_id)
		if definition == null:
			continue
		selector.add_item(definition.display_name)
		selector.set_item_metadata(selector.item_count - 1, hero_id)
	selector.item_selected.connect(_on_selected)
	properties.add_child(selector)
	var info := Label.new()
	info.text = "Выбор действует только при запуске «Тест» и не сохраняется в карте."
	info.add_theme_font_size_override("font_size", HINT_FONT_SIZE)
	info.add_theme_color_override("font_color", Color("#9ab0bf"))
	properties.add_child(info)


func select_hero(hero_id: String) -> void:
	for index in range(selector.item_count):
		if str(selector.get_item_metadata(index)) == hero_id:
			selector.select(index)
			return
	if selector.item_count > 0:
		selector.select(0)


func _on_selected(index: int) -> void:
	if index < 0 or index >= selector.item_count:
		return
	hero_selected.emit(str(selector.get_item_metadata(index)))

class_name HeroPreviewPanel
extends PanelContainer

signal catalog_requested

const ABILITY_ICON_SCENE: PackedScene = preload("res://scenes/ability_icon.tscn")
const STAT_ICONS := {
	"max_health": preload("res://assets/icons/stats/24x24/health.png"),
	"energy": preload("res://assets/icons/stats/24x24/magic.png"),
	"strength": preload("res://assets/icons/stats/24x24/strength.png"),
	"agility": preload("res://assets/icons/stats/24x24/agility.png"),
	"defense": preload("res://assets/icons/stats/24x24/defense.png"),
	"damage": preload("res://assets/icons/stats/24x24/attack.png")
}
const STAT_NAMES := {"max_health": "Жизнь", "energy": "Энергия", "strength": "Сила", "agility": "Ловкость", "defense": "Броня", "damage": "Урон"}

@onready var portrait: TextureRect = $Content/Scroll/Details/Overview/Portrait
@onready var hero_name: Label = $Content/Title
@onready var overview: BoxContainer = $Content/Scroll/Details/Overview
@onready var stats: GridContainer = $Content/Scroll/Details/Overview/Stats
@onready var abilities: HFlowContainer = $Content/Scroll/Details/Abilities
@onready var ability_title: Label = $Content/Scroll/Details/AbilityTitle
@onready var scroll: ScrollContainer = $Content/Scroll
@onready var catalog_button: Button = $Content/CatalogBack

var _stat_labels: Dictionary = {}
var _stat_names: Dictionary = {}


func _ready() -> void:
	catalog_button.pressed.connect(func() -> void: catalog_requested.emit())
	for key in STAT_NAMES:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var icon := TextureRect.new()
		icon.texture = STAT_ICONS[key]
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label := Label.new()
		label.text = STAT_NAMES[key]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(label)
		_stat_names[key] = label
		var value := Label.new()
		value.add_theme_color_override("font_color", Color(0.96, 0.83, 0.61))
		row.add_child(value)
		_stat_labels[key] = value
		stats.add_child(row)


func show_hero(hero: HeroDefinition) -> void:
	for child in abilities.get_children():
		abilities.remove_child(child)
		child.queue_free()
	portrait.texture = hero.portrait if hero != null else null
	hero_name.text = hero.display_name if hero != null else "Персонаж"
	if hero == null:
		for label in _stat_labels.values():
			(label as Label).text = ""
		ability_title.hide()
		return
	var state := HeroState.new(hero)
	var values: Dictionary = CharacterStats.hero_values(state)
	var weapon: ItemDefinition = ItemCatalog.get_item(state.equipped_weapon_id)
	var ranged: bool = weapon != null and weapon.weapon_kind == ItemDefinition.WeaponKind.RANGED
	values["damage"] = values["ranged_attack"] if ranged else values["melee_attack"]
	(_stat_names["damage"] as Label).text = "Дальний урон" if ranged else "Ближний урон"
	values["energy"] = state.energy
	for key in _stat_labels:
		(_stat_labels[key] as Label).text = str(values[key])
	for ability_id in hero.personal_ability_ids:
		var ability: AbilityDefinition = AbilityCatalog.get_ability(ability_id)
		if ability == null:
			continue
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.tooltip_text = ability.display_name
		var icon: AbilityIcon = ABILITY_ICON_SCENE.instantiate() as AbilityIcon
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var label := Label.new()
		label.text = ability.display_name
		label.add_theme_font_size_override("font_size", 13)
		label.custom_minimum_size.x = 108
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		abilities.add_child(row)
		icon.configure_ability(ability)
	ability_title.visible = abilities.get_child_count() > 0
	scroll.scroll_vertical = 0


func adapt(horizontal_details: bool, separate_page: bool, available_height: float) -> void:
	overview.vertical = not horizontal_details
	stats.columns = 1 if horizontal_details else 2
	var side: float = 84.0 if horizontal_details else clampf(available_height * 0.37, 100.0, 240.0)
	portrait.custom_minimum_size = Vector2(side, side)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	catalog_button.visible = separate_page

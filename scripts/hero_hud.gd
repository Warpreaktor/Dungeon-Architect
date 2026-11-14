class_name HeroHUD
extends PanelContainer

## Экранное представление характеристик героя. Не управляет игровой сессией.
## Компоновка и внешний вид задаются сценой и темой Godot.

@onready var _health_bar: TextureProgressBar = %HealthBar
@onready var _health_value: Label = %HealthValue
@onready var _attack_value: Label = %AttackValue
@onready var _attack_icon: TextureRect = %AttackIcon
@onready var _defense_value: Label = %DefenseValue
@onready var _gold_value: Label = %GoldValue
var _default_attack_icon: Texture2D


func _ready() -> void:
	_default_attack_icon = _attack_icon.texture


func set_hero(hero: HeroState) -> void:
	if hero == null:
		return
	_health_bar.max_value = maxi(hero.max_health, 1)
	_health_bar.value = clampi(hero.health, 0, hero.max_health)
	_health_value.text = "%d / %d" % [hero.health, hero.max_health]
	_attack_value.text = str(hero.attack)
	var weapon := ItemCatalog.get_item(hero.equipped_weapon_id)
	_attack_icon.texture = weapon.icon if weapon != null else _default_attack_icon
	_defense_value.text = str(hero.defense)
	_gold_value.text = str(hero.gold)

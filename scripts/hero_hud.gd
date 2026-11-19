class_name HeroHUD
extends PanelContainer

## Экранное представление характеристик героя. Не управляет игровой сессией.
## Компоновка и внешний вид задаются сценой и темой Godot.

@onready var _health_meter: HealthMeter = $Content/HealthMeter
@onready var _attack_value: Label = %AttackValue
@onready var _attack_icon: TextureRect = %AttackIcon
@onready var _defense_value: Label = %DefenseValue
@onready var _defense_icon: TextureRect = %DefenseIcon
@onready var _gold_value: Label = %GoldValue
@onready var _effects_value: Label = %EffectsValue
var _default_attack_icon: Texture2D


func _ready() -> void:
	_default_attack_icon = _attack_icon.texture


func set_hero(hero: HeroState) -> void:
	if hero == null:
		return
	_health_meter.set_health(hero.health, hero.max_health)
	_attack_value.text = str(hero.melee_attack())
	_attack_value.tooltip_text = "Ближняя мощь без бонуса конкретного приёма"
	var weapon := ItemCatalog.get_item(hero.equipped_weapon_id)
	_attack_icon.texture = weapon.icon if weapon != null else _default_attack_icon
	# The equipped shield is potential block strength, not passive armor.
	_defense_value.text = "0"
	_defense_icon.modulate = Color(0.55, 0.60, 0.67, 0.65)
	_gold_value.text = str(hero.gold)
	_effects_value.text = hero.active_effects_summary()
	_effects_value.visible = not _effects_value.text.is_empty()

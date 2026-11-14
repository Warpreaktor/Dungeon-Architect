class_name HeroState
extends RefCounted

## Характеристики одного героя в рамках игрового прохождения.
## Не относятся к исходной карте и пока не сохраняются на диск.

const START_HEALTH: int = 20
const START_ATTACK: int = 1
const START_DEFENSE: int = 0

var max_health: int = START_HEALTH
var health: int = START_HEALTH
var attack: int = START_ATTACK
var defense: int = START_DEFENSE
var gold: int = 0
var equipped_weapon_id: String = ""


func equip_weapon(item: ItemDefinition) -> void:
	if item == null or item.category != ItemDefinition.Category.EQUIPMENT:
		return
	equipped_weapon_id = item.item_id
	attack = START_ATTACK + item.attack_bonus

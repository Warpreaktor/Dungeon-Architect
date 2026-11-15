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
var equipped_shield_id: String = ""


func equip_weapon(item: ItemDefinition) -> void:
	if item == null or item.category != ItemDefinition.Category.EQUIPMENT:
		return
	equipped_weapon_id = item.item_id
	attack = START_ATTACK + item.attack_bonus


func equip_shield(item: ItemDefinition) -> void:
	if item == null or item.category != ItemDefinition.Category.EQUIPMENT:
		return
	equipped_shield_id = item.item_id
	defense = START_DEFENSE + item.defense_bonus


## Лечит не выше максимума, возвращает фактически восстановленное здоровье.
func restore_health(amount: int) -> int:
	var restored: int = mini(maxi(amount, 0), maxi(max_health - health, 0))
	health += restored
	return restored


## Возвращает реально полученный урон; поглощение не уводит его ниже нуля.
func take_damage(incoming: int) -> int:
	var taken := maxi(incoming - defense, 0)
	health = maxi(health - taken, 0)
	return taken

class_name HeroState
extends RefCounted

## Характеристики одного героя в рамках игрового прохождения.
## Не относятся к исходной карте и пока не сохраняются на диск.

const START_HEALTH: int = 40
const START_ATTACK: int = 1
const START_DEFENSE: int = 0

var max_health: int = START_HEALTH
var health: int = START_HEALTH
var attack: int = START_ATTACK
var defense: int = START_DEFENSE
var gold: int = 0
var equipped_weapon_id: String = ""
var equipped_shield_id: String = ""


## Экипируем предмет в заданный ресурсом слот, не расходуя его из рюкзака.
## Если слот занят, прежний предмет остаётся в инвентаре.
func equip_item(item: ItemDefinition) -> bool:
	if item == null or item.category != ItemDefinition.Category.EQUIPMENT:
		return false
	match item.equipment_slot:
		ItemDefinition.EquipmentSlot.WEAPON:
			if equipped_weapon_id == item.item_id:
				return false
			equipped_weapon_id = item.item_id
		ItemDefinition.EquipmentSlot.SHIELD:
			if equipped_shield_id == item.item_id:
				return false
			equipped_shield_id = item.item_id
		_:
			return false
	_recalculate_equipment_stats()
	return true


func unequip_item(item_id: String) -> bool:
	if item_id.is_empty():
		return false
	if equipped_weapon_id == item_id:
		equipped_weapon_id = ""
	elif equipped_shield_id == item_id:
		equipped_shield_id = ""
	else:
		return false
	_recalculate_equipment_stats()
	return true


## Статистика вычисляется из базовых значений и бонусов реально надетых предметов.
func _recalculate_equipment_stats() -> void:
	attack = START_ATTACK
	defense = START_DEFENSE
	for item_id in [equipped_weapon_id, equipped_shield_id]:
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		if item != null:
			attack += item.attack_bonus
			defense += item.defense_bonus


## Совместимые методы для уже существующей игровой логики.
func equip_weapon(item: ItemDefinition) -> void:
	if item != null and item.equipment_slot == ItemDefinition.EquipmentSlot.WEAPON:
		equip_item(item)


func equip_shield(item: ItemDefinition) -> void:
	if item != null and item.equipment_slot == ItemDefinition.EquipmentSlot.SHIELD:
		equip_item(item)


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

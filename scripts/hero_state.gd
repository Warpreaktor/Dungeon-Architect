class_name HeroState
extends RefCounted

## Характеристики одного героя в рамках игрового прохождения.
## Не относятся к исходной карте и пока не сохраняются на диск.

const START_HEALTH: int = 40
const START_ATTACK: int = 1
const START_DEFENSE: int = 0

var definition: HeroDefinition
var max_health: int = START_HEALTH
var health: int = START_HEALTH
var base_attack: int = START_ATTACK
var base_defense: int = START_DEFENSE
var attack: int = START_ATTACK
var defense: int = START_DEFENSE
var gold: int = 0
var equipped_weapon_id: String = ""
var equipped_shield_id: String = ""
## Состояние экземпляров щитов: каждый найденный щит имеет собственную прочность.
var shield_durabilities: Dictionary = {} # item_id -> Array[int]
var last_shield_broken: String = ""



func _init(hero_definition: HeroDefinition = null) -> void:
	definition = hero_definition if hero_definition != null else HeroCatalog.get_hero(HeroCatalog.DEFAULT_HERO_ID)
	max_health = definition.max_health
	health = max_health
	base_attack = definition.base_attack
	base_defense = definition.base_defense
	_recalculate_equipment_stats()


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
	attack = base_attack
	defense = base_defense
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


## У нового щита полная прочность; копии одного типа изнашиваются независимо.
func register_shield(item: ItemDefinition) -> void:
	if item == null or item.equipment_slot != ItemDefinition.EquipmentSlot.SHIELD:
		return
	var values: Array = shield_durabilities.get(item.item_id, [])
	values.append(maxi(item.max_durability, item.defense_bonus))
	shield_durabilities[item.item_id] = values


func current_shield_durability(item_id: String) -> int:
	var values: Array = shield_durabilities.get(item_id, [])
	return int(values[0]) if not values.is_empty() else 0


## Возвращает реально полученный HP-урон. Щит расходует прочность на заблокированный
## урон и сообщает GameSession, какой экземпляр требуется удалить из рюкзака.
func take_damage(incoming: int) -> int:
	last_shield_broken = ""
	var remaining: int = maxi(incoming - base_defense, 0)
	if not equipped_shield_id.is_empty():
		var item: ItemDefinition = ItemCatalog.get_item(equipped_shield_id)
		if item != null:
			var durability: int = current_shield_durability(equipped_shield_id)
			var blocked: int = mini(remaining, mini(item.defense_bonus, durability))
			remaining -= blocked
			if blocked > 0:
				var values: Array = shield_durabilities.get(equipped_shield_id, [])
				values[0] = durability - blocked
				if int(values[0]) <= 0:
					last_shield_broken = equipped_shield_id
					values.remove_at(0)
				shield_durabilities[equipped_shield_id] = values
				if not last_shield_broken.is_empty():
					equipped_shield_id = ""
					_recalculate_equipment_stats()
	health = maxi(health - remaining, 0)
	return remaining

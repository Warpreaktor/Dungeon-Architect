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

# Временные эффекты принадлежат прохождению, а не карте или ресурсам предметов.
var strength_bonus: int = 0
var strength_steps: int = 0
var vitality_percent: int = 0
var vitality_steps: int = 0
var vision_bonus: int = 0
var vision_steps: int = 0



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
			if item.two_handed:
				# Щит остаётся в рюкзаке с прежней прочностью.
				equipped_shield_id = ""
		ItemDefinition.EquipmentSlot.SHIELD:
			if equipped_shield_id == item.item_id:
				return false
			var weapon: ItemDefinition = ItemCatalog.get_item(equipped_weapon_id)
			if weapon != null and weapon.two_handed:
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
	attack = base_attack + strength_bonus
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
	if vitality_steps > 0 and vitality_percent > 0 and remaining > 0:
		remaining = maxi(1, ceili(float(remaining) * float(100 - vitality_percent) / 100.0))
	health = maxi(health - remaining, 0)
	return remaining


## Эффекты повторного зелья обновляют силу/длительность, а не складывают значения.
func apply_potion(item: ItemDefinition) -> Dictionary:
	if item == null or item.category != ItemDefinition.Category.CONSUMABLE:
		return {"used": false, "message": "Предмет нельзя использовать."}
	match item.consumable_effect:
		ItemDefinition.ConsumableEffect.HEAL, ItemDefinition.ConsumableEffect.NONE:
			if item.healing_amount <= 0:
				return {"used": false, "message": "Предмет нельзя использовать."}
			if health >= max_health:
				return {"used": false, "message": "Здоровье уже полное."}
			var healed := restore_health(item.healing_amount)
			return {"used": healed > 0, "message": "+%d HP" % healed}
		ItemDefinition.ConsumableEffect.ATTACK:
			strength_bonus = maxi(strength_bonus, item.effect_value)
			strength_steps = maxi(strength_steps, item.effect_duration_steps)
			_recalculate_equipment_stats()
			return {"used": true, "message": "Атака +%d (%d шагов)" % [strength_bonus, strength_steps]}
		ItemDefinition.ConsumableEffect.RESIST:
			vitality_percent = maxi(vitality_percent, clampi(item.effect_value, 0, 90))
			vitality_steps = maxi(vitality_steps, item.effect_duration_steps)
			return {"used": true, "message": "Получаемый урон −%d%% (%d шагов)" % [vitality_percent, vitality_steps]}
		ItemDefinition.ConsumableEffect.VISION:
			vision_bonus = maxi(vision_bonus, item.effect_value)
			vision_steps = maxi(vision_steps, item.effect_duration_steps)
			return {"used": true, "message": "Обзор +%d (%d шагов)" % [vision_bonus, vision_steps]}
	return {"used": false, "message": "Предмет нельзя использовать."}


## Длительность отсчитывается по успешным шагам героя, не по кадровому времени.
func advance_effects() -> void:
	if strength_steps > 0:
		strength_steps -= 1
		if strength_steps == 0:
			strength_bonus = 0
			_recalculate_equipment_stats()
	if vitality_steps > 0:
		vitality_steps -= 1
		if vitality_steps == 0:
			vitality_percent = 0
	if vision_steps > 0:
		vision_steps -= 1
		if vision_steps == 0:
			vision_bonus = 0


func has_vision_effect() -> bool:
	return vision_steps > 0 and vision_bonus > 0


func active_effects_summary() -> String:
	var parts: Array[String] = []
	if strength_steps > 0:
		parts.append("Сила +%d · %d ш." % [strength_bonus, strength_steps])
	if vitality_steps > 0:
		parts.append("Живучесть %d%% · %d ш." % [vitality_percent, vitality_steps])
	if vision_steps > 0:
		parts.append("Всевиденье +%d · %d ш." % [vision_bonus, vision_steps])
	return "  |  ".join(parts)


## Отдельный боевой снимок, чтобы вычисления не меняли героя прохождения.
## Ресурс HeroDefinition остаётся общим и неизменяемым.
func copy_for_battle() -> HeroState:
	var copy := HeroState.new(definition)
	copy.max_health = max_health
	copy.health = health
	copy.base_attack = base_attack
	copy.base_defense = base_defense
	copy.attack = attack
	copy.defense = defense
	copy.gold = gold
	copy.equipped_weapon_id = equipped_weapon_id
	copy.equipped_shield_id = equipped_shield_id
	copy.shield_durabilities = shield_durabilities.duplicate(true)
	copy.last_shield_broken = last_shield_broken
	copy.strength_bonus = strength_bonus
	copy.strength_steps = strength_steps
	copy.vitality_percent = vitality_percent
	copy.vitality_steps = vitality_steps
	copy.vision_bonus = vision_bonus
	copy.vision_steps = vision_steps
	return copy


## Переносим из боя только изменяемые боевые поля. Золото, изученные
## предметы и остальные данные GameSession не должны перезаписываться.
func apply_battle_result(snapshot: HeroState) -> void:
	if snapshot == null:
		return
	health = snapshot.health
	equipped_weapon_id = snapshot.equipped_weapon_id
	equipped_shield_id = snapshot.equipped_shield_id
	shield_durabilities = snapshot.shield_durabilities.duplicate(true)
	last_shield_broken = snapshot.last_shield_broken
	_recalculate_equipment_stats()

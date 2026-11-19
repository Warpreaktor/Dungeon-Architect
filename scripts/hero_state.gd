class_name HeroState
extends RefCounted

## Характеристики одного героя в рамках игрового прохождения.
## Не относятся к исходной карте и пока не сохраняются на диск.

const START_HEALTH: int = 40
const START_DEFENSE: int = 0

var definition: HeroDefinition
var max_health: int = START_HEALTH
var health: int = START_HEALTH
var strength: int = 0
var agility: int = 0
var base_defense: int = START_DEFENSE
var defense: int = START_DEFENSE
var gold: int = 0
## Общие способности, изученные в ходе приключения (не меняют HeroDefinition).
var learned_ability_ids: Array[String] = []
## Последняя подтверждённая раскладка алгоритма в текущем прохождении.
## Пустые слоты сохраняются на месте. Данные принадлежат экземпляру героя.
var saved_action_slots: Array[String] = []
## Будущие артефакты и эффекты смогут изменять число доступных слотов.
var bonus_action_slots: int = 0
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
	strength = definition.strength
	agility = definition.agility
	base_defense = definition.base_defense
	_recalculate_equipment_stats()


## Ближний и дальний урон: собственная мощность оружия нужного типа +
## половина соответствующей характеристики + временное усиление атаки.
## Число из эффекта способности прибавляется в AbilityExecutor.
func weapon_damage(kind: int) -> int:
	var item: ItemDefinition = ItemCatalog.get_item(equipped_weapon_id)
	if item == null or item.equipment_slot != ItemDefinition.EquipmentSlot.WEAPON or item.weapon_kind != kind:
		return 0
	return maxi(item.weapon_damage, 0)


func melee_attack_value() -> float:
	return float(weapon_damage(ItemDefinition.WeaponKind.MELEE) + strength_bonus) + float(maxi(strength, 0)) * 0.5


func ranged_attack_value() -> float:
	return float(weapon_damage(ItemDefinition.WeaponKind.RANGED) + strength_bonus) + float(maxi(agility, 0)) * 0.5


func melee_attack() -> int:
	return floori(melee_attack_value())


func ranged_attack() -> int:
	return floori(ranged_attack_value())


func action_slot_capacity() -> int:
	return clampi(definition.base_action_slots + bonus_action_slots, 1, BattleChainPlanner.MAX_ACTIONS)


func get_saved_action_slots() -> Array[String]:
	## Выдаём копию: редактор боя не должен править сохранённый алгоритм до подтверждения.
	var result: Array[String] = []
	for index in range(action_slot_capacity()):
		result.append(saved_action_slots[index] if index < saved_action_slots.size() else "")
	return result


func save_action_slots(slots: Array[String]) -> bool:
	if slots.size() != action_slot_capacity():
		return false
	saved_action_slots = slots.duplicate()
	return true


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


## Пассивная защита не включает щит; тот работает только через «Блок».
## Постоянной атаки нет: урон вычисляется на момент применения способности.
func _recalculate_equipment_stats() -> void:
	defense = base_defense
	var weapon: ItemDefinition = ItemCatalog.get_item(equipped_weapon_id)
	if weapon != null and weapon.equipment_slot == ItemDefinition.EquipmentSlot.WEAPON:
		defense += weapon.defense_bonus


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


## Удар по щиту уменьшает прочность на ВСЮ силу удара после пассивной
## защиты, а не только на поглощённую часть. Даже щит с 1 прочности
## защищает этим ударом на полную величину брони, затем разрушается.
## Возвращает поглощённые HP; ID сломанного экземпляра сохраняется отдельно.
func consume_shield_block(incoming: int, maximum_absorption: int = -1) -> int:
	last_shield_broken = ""
	if equipped_shield_id.is_empty() or incoming <= 0:
		return 0
	var item: ItemDefinition = ItemCatalog.get_item(equipped_shield_id)
	var durability: int = current_shield_durability(equipped_shield_id)
	if item == null or durability <= 0:
		return 0
	var blocked: int = mini(incoming, maxi(item.defense_bonus, 0))
	if maximum_absorption >= 0:
		blocked = mini(blocked, maximum_absorption)
	var values: Array = shield_durabilities.get(equipped_shield_id, [])
	values[0] = durability - incoming
	if int(values[0]) <= 0:
		last_shield_broken = equipped_shield_id
		values.remove_at(0)
	shield_durabilities[equipped_shield_id] = values
	if not last_shield_broken.is_empty():
		equipped_shield_id = ""
		_recalculate_equipment_stats()
	return blocked


## Щит не защищает пассивно, но базовая броня и зелья работают по-прежнему.
func take_damage(incoming: int) -> int:
	var remaining: int = maxi(incoming - base_defense, 0)
	if vitality_steps > 0 and vitality_percent > 0 and remaining > 0:
		remaining = maxi(1, int(float(remaining) * float(100 - vitality_percent) / 100.0))
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
	copy.strength = strength
	copy.agility = agility
	copy.base_defense = base_defense
	copy.defense = defense
	copy.gold = gold
	copy.learned_ability_ids = learned_ability_ids.duplicate()
	copy.saved_action_slots = saved_action_slots.duplicate()
	copy.bonus_action_slots = bonus_action_slots
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

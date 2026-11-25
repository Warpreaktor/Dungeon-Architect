class_name HeroState
extends RefCounted

## Характеристики одного героя в рамках игрового прохождения.
## Не относятся к исходной карте и пока не сохраняются на диск.

var definition: HeroDefinition
var max_health: int = 0
var health: int = 0
var energy: int = 0
var strength: int = 0
var agility: int = 0
var perception: int = 0
var base_defense: int = 0
var defense: int = 0
var gold: int = 0
## Общие способности, изученные в ходе приключения (не меняют HeroDefinition).
var learned_ability_ids: Array[String] = []
## Подготовленный арсенал героя для следующих сражений.
## Пустые слоты сохраняются на месте. Данные принадлежат экземпляру героя.
var saved_action_slots: Array[String] = []
## Будущие артефакты и эффекты смогут изменять число доступных слотов.
var bonus_action_slots: int = 0
var equipped_weapon_id: String = ""
var equipped_shield_id: String = ""
var equipped_accessories: Dictionary = {}
var equipped_instance_ids: Dictionary = {}
var item_instances: Dictionary = {}
## Состояние экземпляров щитов: каждый найденный щит имеет собственную прочность.
var shield_durabilities: Dictionary = {} # item_id -> Array[int]
var last_shield_broken: String = ""

# Временные эффекты принадлежат прохождению, а не карте или ресурсам предметов.
var strength_bonus: int = 0
var strength_phases: int = 0
var vitality_percent: int = 0
var vitality_phases: int = 0
var vision_bonus: int = 0
var vision_phases: int = 0
## Активные состояния героя; боевой снимок использует тот же формат.
var overworld_statuses: Dictionary = {}
var _potion_phase_progress: int = 0



func _init(hero_definition: HeroDefinition = null) -> void:
	definition = hero_definition if hero_definition != null else HeroCatalog.get_hero(HeroCatalog.DEFAULT_HERO_ID)
	max_health = definition.max_health
	health = max_health
	energy = definition.max_energy
	strength = definition.strength
	agility = definition.agility
	perception = definition.perception
	base_defense = definition.base_defense
	equipped_weapon_id = definition.starting_weapon_id
	_recalculate_equipment_stats()
	for ability_id in definition.personal_ability_ids:
		if saved_action_slots.size() >= action_slot_capacity():
			break
		saved_action_slots.append(ability_id)


## Ближний и дальний урон: собственная мощность оружия нужного типа +
## коэффициент характеристики из боевых правил + временное усиление атаки.
## Число из эффекта способности прибавляется в AbilityExecutor.
func weapon_damage(kind: int) -> int:
	var item: ItemDefinition = ItemCatalog.get_item(equipped_weapon_id)
	if item == null or item.equipment_slot != ItemDefinition.EquipmentSlot.WEAPON or item.weapon_kind != kind:
		return 0
	return CharacterStats.slot_item_value(self, "main_hand", "weapon_damage")


func melee_attack_value() -> float:
	return float(CharacterStats.hero_values(self)["melee_power"])


func ranged_attack_value() -> float:
	return float(CharacterStats.hero_values(self)["ranged_power"])


func melee_attack() -> int:
	return int(CharacterStats.hero_values(self)["melee_attack"])


func ranged_attack() -> int:
	return int(CharacterStats.hero_values(self)["ranged_attack"])


func action_slot_capacity() -> int:
	return clampi(definition.base_action_slots + bonus_action_slots, 1, BattleChainPlanner.MAX_ACTIONS)


func get_saved_action_slots() -> Array[String]:
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


## Постоянная защита складывается из базовой брони и снаряжения.
func _recalculate_equipment_stats() -> void:
	defense = int(CharacterStats.hero_values(self, false)["defense"])


## Совместимые методы для уже существующей игровой логики.
func equip_weapon(item: ItemDefinition) -> void:
	if item != null and item.equipment_slot == ItemDefinition.EquipmentSlot.WEAPON:
		equip_item(item)


func equip_shield(item: ItemDefinition) -> void:
	if item != null and item.equipment_slot == ItemDefinition.EquipmentSlot.SHIELD:
		equip_item(item)


func equipment_bonus(property_name: String) -> int:
	return CharacterStats.equipment_bonus(self, property_name)


func effective_strength() -> int:
	return int(CharacterStats.hero_values(self)["strength"])


func effective_agility() -> int:
	return int(CharacterStats.hero_values(self)["agility"])


func effective_perception() -> int:
	return int(CharacterStats.hero_values(self)["perception"])


func effective_poison_resistance_percent() -> int:
	return int(CharacterStats.hero_values(self)["poison_resistance_percent"])


func effective_max_health() -> int:
	return int(CharacterStats.hero_values(self)["max_health"])


## Лечит не выше максимума, возвращает фактически восстановленное здоровье.
func restore_health(amount: int) -> int:
	var restored: int = mini(maxi(amount, 0), maxi(effective_max_health() - health, 0))
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
	var blocked: int = mini(incoming, CharacterStats.slot_item_value(self, "off_hand", "defense_bonus"))
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
func take_damage(incoming: int, apply_passive_armor: bool = true) -> int:
	var remaining: int = maxi(incoming, 0)
	if apply_passive_armor:
		remaining -= BattleMath.passive_armor_absorption(remaining, int(CharacterStats.hero_values(self)["defense"]))
	if vitality_phases > 0 and vitality_percent > 0 and remaining > 0:
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
			if health >= effective_max_health():
				return {"used": false, "message": "Здоровье уже полное."}
			var healed := restore_health(item.healing_amount)
			return {"used": healed > 0, "message": "+%d HP" % healed}
		ItemDefinition.ConsumableEffect.ATTACK:
			strength_bonus = maxi(strength_bonus, item.effect_value)
			strength_phases = maxi(strength_phases, item.effect_duration_phases)
			_recalculate_equipment_stats()
			return {"used": true, "message": "Атака +%d (%d фаз)" % [strength_bonus, strength_phases]}
		ItemDefinition.ConsumableEffect.RESIST:
			vitality_percent = maxi(vitality_percent, clampi(item.effect_value, 0, 90))
			vitality_phases = maxi(vitality_phases, item.effect_duration_phases)
			return {"used": true, "message": "Получаемый урон −%d%% (%d фаз)" % [vitality_percent, vitality_phases]}
		ItemDefinition.ConsumableEffect.VISION:
			vision_bonus = maxi(vision_bonus, item.effect_value)
			vision_phases = maxi(vision_phases, item.effect_duration_phases)
			return {"used": true, "message": "Обзор +%d (%d фаз)" % [vision_bonus, vision_phases]}
	return {"used": false, "message": "Предмет нельзя использовать."}


func exploration_phase_length() -> int:
	return action_slot_capacity() + BattleChainPlanner.REST_TICKS


func advance_effects() -> void:
	_potion_phase_progress += 1
	if _potion_phase_progress >= exploration_phase_length():
		_potion_phase_progress = 0
		advance_phase_effects()


func advance_phase_effects() -> void:
	if strength_phases > 0:
		strength_phases -= 1
		if strength_phases == 0:
			strength_bonus = 0
			_recalculate_equipment_stats()
	if vitality_phases > 0:
		vitality_phases -= 1
		if vitality_phases == 0:
			vitality_percent = 0
	if vision_phases > 0:
		vision_phases -= 1
		if vision_phases == 0:
			vision_bonus = 0


func has_vision_effect() -> bool:
	return vision_phases > 0 and vision_bonus > 0


func apply_overworld_status(status_id: String, label: String, damage: int, ticks: int, interval_steps: int) -> bool:
	var clean_id := status_id.strip_edges()
	if clean_id.is_empty() or damage <= 0 or ticks <= 0 or interval_steps <= 0:
		return false
	var current: Dictionary = overworld_statuses.get(clean_id, {})
	var effect := AbilityEffectDefinition.new()
	effect.kind = AbilityEffectDefinition.Kind.APPLY_STATUS
	effect.status_id = clean_id
	effect.status_clock = AbilityEffectDefinition.Clock.OWNER_PHASE
	effect.duration_ticks = maxi(ticks, int(current.get("ticks", 0)))
	effect.tick_damage = maxi(damage, int(current.get("tick_damage", 0)))
	BattleStatusRules.apply(overworld_statuses, effect, -1, false)
	var status: Dictionary = overworld_statuses[clean_id]
	status["label"] = label if not label.strip_edges().is_empty() else clean_id
	status["interval_steps"] = interval_steps
	status["steps_until_tick"] = mini(int(current.get("steps_until_tick", interval_steps)), interval_steps)
	return true


func reset_exploration_phase() -> void:
	_potion_phase_progress = 0
	for status_id in overworld_statuses:
		var status: Dictionary = overworld_statuses[status_id]
		status["steps_until_tick"] = int(status.get("interval_steps", exploration_phase_length()))
		status["applied_tick"] = -1
		status["skip_partial_phase"] = false
		var instances: Array = status.get("instance_ticks", [])
		for instance in instances:
			instance["applied_tick"] = -1
			instance["skip_partial_phase"] = false


func advance_overworld_statuses() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for status_id in overworld_statuses.keys():
		var status: Dictionary = overworld_statuses[status_id]
		var clock: int = int(status.get("clock", AbilityEffectDefinition.Clock.OWNER_PHASE))
		if clock == AbilityEffectDefinition.Clock.INCOMING_ATTACK:
			continue
		var interval: int = maxi(int(status.get("interval_steps", exploration_phase_length())), 1)
		status["steps_until_tick"] = int(status.get("steps_until_tick", interval)) - 1
		if int(status["steps_until_tick"]) > 0:
			continue
		var single: Dictionary = {status_id: status}
		for entry in BattleStatusRules.ticking_entries(single, clock):
			var before: int = health
			health = maxi(health - int(entry["damage"]), 0)
			events.append({"status_id": str(status_id), "label": str(status.get("label", status_id)),
				"damage": before - health, "ticks_remaining": maxi(int(status.get("ticks", 0)) - 1, 0)})
		var old_limit: int = effective_max_health()
		BattleStatusRules.advance(single, clock)
		if single.has(status_id):
			var updated: Dictionary = single[status_id]
			updated["steps_until_tick"] = interval
			overworld_statuses[status_id] = updated
		else:
			overworld_statuses.erase(status_id)
		var new_limit: int = effective_max_health()
		if new_limit > old_limit and health > 0:
			health = mini(health + new_limit - old_limit, new_limit)
		if health <= 0:
			break
	return events


func active_effects_summary() -> String:
	var parts: Array[String] = []
	if strength_phases > 0:
		parts.append("Сила +%d · %d ф." % [strength_bonus, strength_phases])
	if vitality_phases > 0:
		parts.append("Живучесть %d%% · %d ф." % [vitality_percent, vitality_phases])
	if vision_phases > 0:
		parts.append("Всевиденье +%d · %d ф." % [vision_bonus, vision_phases])
	for status_id in overworld_statuses:
		var status: Dictionary = overworld_statuses[status_id]
		parts.append("%s · %s" % [str(status.get("label", status_id)), BattleStatusRules.describe(status)])
	return "  |  ".join(parts)


## Отдельный боевой снимок, чтобы вычисления не меняли героя прохождения.
## Ресурс HeroDefinition остаётся общим и неизменяемым.
func copy_for_battle() -> HeroState:
	var copy := HeroState.new(definition)
	copy.max_health = max_health
	copy.health = health
	copy.energy = energy
	copy.strength = strength
	copy.agility = agility
	copy.perception = perception
	copy.base_defense = base_defense
	copy.defense = defense
	copy.gold = gold
	copy.learned_ability_ids = learned_ability_ids.duplicate()
	copy.saved_action_slots = saved_action_slots.duplicate()
	copy.bonus_action_slots = bonus_action_slots
	copy.equipped_weapon_id = equipped_weapon_id
	copy.equipped_shield_id = equipped_shield_id
	copy.equipped_accessories = equipped_accessories.duplicate(true)
	copy.equipped_instance_ids = equipped_instance_ids.duplicate(true)
	copy.item_instances = item_instances
	copy.shield_durabilities = shield_durabilities.duplicate(true)
	copy.last_shield_broken = last_shield_broken
	copy.strength_bonus = strength_bonus
	copy.strength_phases = strength_phases
	copy.vitality_percent = vitality_percent
	copy.vitality_phases = vitality_phases
	copy.vision_bonus = vision_bonus
	copy.vision_phases = vision_phases
	copy.overworld_statuses = overworld_statuses.duplicate(true)
	copy.reset_exploration_phase()
	return copy


## Переносим из боя только изменяемые боевые поля. Золото, изученные
## предметы и остальные данные GameSession не должны перезаписываться.
func apply_battle_result(snapshot: HeroState) -> void:
	if snapshot == null:
		return
	health = snapshot.health
	energy = snapshot.energy
	equipped_weapon_id = snapshot.equipped_weapon_id
	equipped_shield_id = snapshot.equipped_shield_id
	equipped_accessories = snapshot.equipped_accessories.duplicate(true)
	equipped_instance_ids = snapshot.equipped_instance_ids.duplicate(true)
	shield_durabilities = snapshot.shield_durabilities.duplicate(true)
	last_shield_broken = snapshot.last_shield_broken
	strength_bonus = snapshot.strength_bonus
	strength_phases = snapshot.strength_phases
	vitality_percent = snapshot.vitality_percent
	vitality_phases = snapshot.vitality_phases
	vision_bonus = snapshot.vision_bonus
	vision_phases = snapshot.vision_phases
	overworld_statuses = snapshot.overworld_statuses.duplicate(true)
	reset_exploration_phase()
	_recalculate_equipment_stats()

func to_snapshot() -> Dictionary:
	return {
		"hero_id": definition.hero_id,
		"max_health": max_health,
		"health": health,
		"energy": energy,
		"strength": strength,
		"agility": agility,
		"perception": perception,
		"base_defense": base_defense,
		"gold": gold,
		"learned_ability_ids": learned_ability_ids.duplicate(),
		"saved_action_slots": saved_action_slots.duplicate(),
		"bonus_action_slots": bonus_action_slots,
		"equipped_weapon_id": equipped_weapon_id,
		"equipped_shield_id": equipped_shield_id,
		"equipped_accessories": equipped_accessories.duplicate(true),
		"equipped_instance_ids": equipped_instance_ids.duplicate(true),
		"shield_durabilities": shield_durabilities.duplicate(true),
		"last_shield_broken": last_shield_broken,
		"strength_bonus": strength_bonus,
		"strength_phases": strength_phases,
		"vitality_percent": vitality_percent,
		"vitality_phases": vitality_phases,
		"vision_bonus": vision_bonus,
		"vision_phases": vision_phases,
		"overworld_statuses": overworld_statuses.duplicate(true),
		"potion_phase_progress": _potion_phase_progress
	}


static func from_snapshot(data: Dictionary) -> HeroState:
	var hero_id: String = str(data.get("hero_id", ""))
	if not HeroCatalog.has(hero_id):
		return null
	var required_numbers: Array[String] = [
		"max_health", "health", "strength", "agility", "base_defense", "gold",
		"bonus_action_slots", "strength_bonus", "strength_phases", "vitality_percent",
		"vitality_phases", "vision_bonus", "vision_phases", "potion_phase_progress"
	]
	for key in required_numbers:
		if not data.has(key) or typeof(data[key]) not in [TYPE_INT, TYPE_FLOAT]:
			return null
		if int(data[key]) != float(data[key]):
			return null
	if data.has("perception") and (typeof(data["perception"]) not in [TYPE_INT, TYPE_FLOAT] or float(data["perception"]) != float(int(data["perception"])) or int(data["perception"]) < 0):
		return null
	if int(data["max_health"]) <= 0 or int(data["health"]) < 0:
		return null
	if int(data["gold"]) < 0 or int(data["strength_phases"]) < 0 or int(data["vitality_phases"]) < 0 or int(data["vision_phases"]) < 0:
		return null
	if int(data["bonus_action_slots"]) < 0 or int(data["potion_phase_progress"]) < 0:
		return null
	if not (data.get("learned_ability_ids") is Array) or not (data.get("saved_action_slots") is Array):
		return null
	if not (data.get("equipped_accessories") is Dictionary) or not (data.get("shield_durabilities") is Dictionary):
		return null
	if not (data.get("overworld_statuses") is Dictionary):
		return null
	var result := HeroState.new(HeroCatalog.get_hero(hero_id))
	result.max_health = int(data["max_health"])
	result.health = int(data["health"])
	if data.has("energy"):
		if typeof(data["energy"]) not in [TYPE_INT, TYPE_FLOAT] or float(data["energy"]) != float(int(data["energy"])):
			return null
		result.energy = mini(int(data["energy"]), result.definition.max_energy)
	result.strength = int(data["strength"])
	result.agility = int(data["agility"])
	result.perception = int(data.get("perception", result.definition.perception))
	result.base_defense = int(data["base_defense"])
	result.gold = int(data["gold"])
	result.bonus_action_slots = int(data["bonus_action_slots"])
	var learned: Array[String] = []
	for learned_id_raw in data["learned_ability_ids"]:
		if typeof(learned_id_raw) != TYPE_STRING or str(learned_id_raw).is_empty() or AbilityCatalog.get_ability(str(learned_id_raw)) == null or learned.has(str(learned_id_raw)):
			return null
		learned.append(str(learned_id_raw))
	result.learned_ability_ids = learned
	var prepared: Array[String] = []
	for action_id_raw in data["saved_action_slots"]:
		if typeof(action_id_raw) != TYPE_STRING:
			return null
		if not str(action_id_raw).is_empty() and AbilityCatalog.get_ability(str(action_id_raw)) == null:
			return null
		prepared.append(str(action_id_raw))
	if prepared.size() > result.action_slot_capacity():
		return null
	result.saved_action_slots = prepared
	result.equipped_weapon_id = str(data.get("equipped_weapon_id", ""))
	result.equipped_shield_id = str(data.get("equipped_shield_id", ""))
	for slot_id in ["main_hand", "off_hand"]:
		var equipped_id: String = result.equipped_weapon_id if slot_id == "main_hand" else result.equipped_shield_id
		if not equipped_id.is_empty() and not EquipmentSlotRules.accepts(slot_id, ItemCatalog.get_item(equipped_id)):
			return null
	var weapon: ItemDefinition = ItemCatalog.get_item(result.equipped_weapon_id)
	if weapon != null and weapon.two_handed and not result.equipped_shield_id.is_empty():
		return null
	var accessories: Dictionary = data["equipped_accessories"]
	for raw_slot in accessories:
		var slot_id: String = str(raw_slot)
		var accessory_item_id: String = str(accessories[raw_slot])
		if slot_id not in EquipmentSlotRules.SLOT_IDS or slot_id in ["main_hand", "off_hand"]:
			return null
		if not accessory_item_id.is_empty() and not EquipmentSlotRules.accepts(slot_id, ItemCatalog.get_item(accessory_item_id)):
			return null
	result.equipped_accessories = accessories.duplicate(true)
	if data.has("equipped_instance_ids"):
		if not (data["equipped_instance_ids"] is Dictionary):
			return null
		for slot in data["equipped_instance_ids"]:
			if typeof(slot) != TYPE_STRING or str(slot) not in EquipmentSlotRules.SLOT_IDS or typeof(data["equipped_instance_ids"][slot]) != TYPE_STRING:
				return null
			if str(data["equipped_instance_ids"][slot]).is_empty():
				return null
		result.equipped_instance_ids = data["equipped_instance_ids"].duplicate(true)
	var durabilities: Dictionary = data["shield_durabilities"]
	for durability_id in durabilities:
		var shield_item_id: String = str(durability_id)
		var item: ItemDefinition = ItemCatalog.get_item(shield_item_id)
		if item == null or item.equipment_slot != ItemDefinition.EquipmentSlot.SHIELD:
			return null
		if not (durabilities[durability_id] is Array):
			return null
		for durability in durabilities[durability_id]:
			if typeof(durability) not in [TYPE_INT, TYPE_FLOAT] or int(durability) <= 0 or float(durability) != float(int(durability)):
				return null
	result.shield_durabilities = durabilities.duplicate(true)
	result.last_shield_broken = str(data.get("last_shield_broken", ""))
	result.strength_bonus = int(data["strength_bonus"])
	result.strength_phases = int(data["strength_phases"])
	result.vitality_percent = int(data["vitality_percent"])
	result.vitality_phases = int(data["vitality_phases"])
	result.vision_bonus = int(data["vision_bonus"])
	result.vision_phases = int(data["vision_phases"])
	var statuses: Dictionary = data["overworld_statuses"]
	for status_id in statuses:
		if typeof(status_id) != TYPE_STRING or not (statuses[status_id] is Dictionary):
			return null
	result.overworld_statuses = statuses.duplicate(true)
	result._potion_phase_progress = int(data["potion_phase_progress"])
	result._recalculate_equipment_stats()
	if result.health > result.effective_max_health() and result.equipped_instance_ids.is_empty():
		return null
	return result

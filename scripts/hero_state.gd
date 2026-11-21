class_name HeroState
extends RefCounted

## Характеристики одного героя в рамках игрового прохождения.
## Не относятся к исходной карте и пока не сохраняются на диск.

var definition: HeroDefinition
var max_health: int = 0
var health: int = 0
var strength: int = 0
var agility: int = 0
var base_defense: int = 0
var defense: int = 0
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
	strength = definition.strength
	agility = definition.agility
	base_defense = definition.base_defense
	_recalculate_equipment_stats()


## Ближний и дальний урон: собственная мощность оружия нужного типа +
## коэффициент характеристики из боевых правил + временное усиление атаки.
## Число из эффекта способности прибавляется в AbilityExecutor.
func weapon_damage(kind: int) -> int:
	var item: ItemDefinition = ItemCatalog.get_item(equipped_weapon_id)
	if item == null or item.equipment_slot != ItemDefinition.EquipmentSlot.WEAPON or item.weapon_kind != kind:
		return 0
	return maxi(item.weapon_damage, 0)


func melee_attack_value() -> float:
	return BattleMath.melee_power(weapon_damage(ItemDefinition.WeaponKind.MELEE), strength_bonus, strength)


func ranged_attack_value() -> float:
	return BattleMath.ranged_power(weapon_damage(ItemDefinition.WeaponKind.RANGED), strength_bonus, agility)


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
	# No passive block, including defensive bonuses on weapons.
	# Future armor will have a separate dedicated calculation.
	defense = 0


## Совместимые методы для уже существующей игровой логики.
func equip_weapon(item: ItemDefinition) -> void:
	if item != null and item.equipment_slot == ItemDefinition.EquipmentSlot.WEAPON:
		equip_item(item)


func equip_shield(item: ItemDefinition) -> void:
	if item != null and item.equipment_slot == ItemDefinition.EquipmentSlot.SHIELD:
		equip_item(item)


## Лечит не выше максимума, возвращает фактически восстановленное здоровье.
func effective_max_health() -> int:
	return BattleStatusRules.health_limit(max_health, overworld_statuses)


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
	var remaining: int = maxi(incoming, 0)
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
	equipped_weapon_id = snapshot.equipped_weapon_id
	equipped_shield_id = snapshot.equipped_shield_id
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

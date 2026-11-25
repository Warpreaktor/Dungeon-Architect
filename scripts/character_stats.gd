class_name CharacterStats
extends RefCounted

const EQUIPMENT_FIELDS: Array[String] = [
	"armor_bonus", "health_bonus", "strength_bonus", "agility_bonus", "perception_bonus",
	"dodge_bonus_percent", "accuracy_bonus_percent", "poison_resistance_percent"
]
const EQUIPMENT_LABELS: Dictionary = {
	"armor_bonus": "Броня", "health_bonus": "HP", "strength_bonus": "Сила",
	"agility_bonus": "Ловкость", "perception_bonus": "Чутьё",
	"dodge_bonus_percent": "Уклонение", "accuracy_bonus_percent": "Меткость",
	"poison_resistance_percent": "Сопротивление яду"
}
const COMPARISON_FIELDS: Array[String] = [
	"max_health", "strength", "agility", "perception", "defense",
	"dodge_percent", "accuracy_percent", "poison_resistance_percent",
	"melee_attack", "ranged_attack", "block_rating"
]
const COMPARISON_LABELS: Dictionary = {
	"max_health": "Максимум HP", "strength": "Сила", "agility": "Ловкость",
	"perception": "Чутьё", "defense": "Броня", "dodge_percent": "Уклонение",
	"accuracy_percent": "Меткость", "poison_resistance_percent": "Сопротивление яду",
	"melee_attack": "Ближний урон", "ranged_attack": "Дальний урон",
	"block_rating": "Блок щита"
}
const PERCENT_FIELDS: Array[String] = ["dodge_percent", "accuracy_percent", "poison_resistance_percent"]


static func equipment_values(ids: Array[String]) -> Dictionary:
	var totals: Dictionary = {}
	for key in EQUIPMENT_FIELDS:
		totals[key] = 0
	for item_id in ids:
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		if item == null or item.category != ItemDefinition.Category.EQUIPMENT:
			continue
		for key in EQUIPMENT_FIELDS:
			if key == "armor_bonus" and item.equipment_slot in [ItemDefinition.EquipmentSlot.WEAPON, ItemDefinition.EquipmentSlot.SHIELD]:
				continue
			totals[key] += ItemMagicCatalog.effective_value(item, null, key)
	return totals


static func slot_item_value(hero: Variant, slot_id: String, field: String) -> int:
	var item_id: String = ""
	match slot_id:
		"main_hand":
			item_id = str(hero.equipped_weapon_id)
		"off_hand":
			item_id = str(hero.equipped_shield_id)
		_:
			item_id = str(hero.equipped_accessories.get(slot_id, ""))
	var definition: ItemDefinition = ItemCatalog.get_item(item_id)
	if definition == null:
		return 0
	var instance: ItemInstance = hero.item_instances.get(str(hero.equipped_instance_ids.get(slot_id, ""))) as ItemInstance
	if instance != null and instance.item_id != item_id:
		instance = null
	return ItemMagicCatalog.effective_value(definition, instance, field)


static func equipment_values_for_hero(hero: Variant) -> Dictionary:
	var totals: Dictionary = {}
	for field in EQUIPMENT_FIELDS:
		totals[field] = 0
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		if slot_id in ["main_hand", "off_hand"]:
			var weapon_id: String = str(hero.equipped_weapon_id if slot_id == "main_hand" else hero.equipped_shield_id)
			if weapon_id.is_empty():
				continue
		elif str(hero.equipped_accessories.get(slot_id, "")).is_empty():
			continue
		for field in EQUIPMENT_FIELDS:
			if field == "armor_bonus" and slot_id in ["main_hand", "off_hand"]:
				continue
			totals[field] += slot_item_value(hero, slot_id, field)
	return totals


static func equipped_ids(hero: Variant) -> Array[String]:
	var result: Array[String] = []
	result.append(str(hero.equipped_weapon_id))
	result.append(str(hero.equipped_shield_id))
	for item_id in hero.equipped_accessories.values():
		result.append(str(item_id))
	return result


static func equipment_bonus(hero: Variant, field: String) -> int:
	return int(equipment_values_for_hero(hero).get(field, 0))


static func energy_factor(amount: int, maximum: int) -> float:
	if maximum <= 0:
		return 1.0
	var rules: BattleRules = BattleMath.RULES
	if amount < 0:
		return rules.energy_negative_factor
	if amount == 0:
		return rules.energy_zero_factor
	if float(amount) <= float(maximum) * rules.energy_fatigue_threshold:
		return rules.energy_fatigue_factor
	return 1.0


static func _weapon_kind(item_id: String) -> int:
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	return item.weapon_kind if item != null and item.equipment_slot == ItemDefinition.EquipmentSlot.WEAPON else -1


static func hero_values(hero: Variant, include_temporary: bool = true) -> Dictionary:
	if hero == null:
		return {}
	var equipment: Dictionary = equipment_values_for_hero(hero)
	var definition: HeroDefinition = hero.definition
	var accuracy_bonus: int = definition.accuracy_bonus if definition != null else 0
	if definition != null and definition.base_accuracy_percent >= 0:
		accuracy_bonus += definition.base_accuracy_percent - BattleMath.accuracy_total(definition.agility, 0, 0)
	var base: Dictionary = {
		"max_health": hero.max_health, "strength": hero.strength, "agility": hero.agility,
		"perception": hero.perception, "defense": hero.base_defense,
		"base_dodge_percent": definition.base_dodge_percent if definition != null else 0,
		"accuracy_bonus": accuracy_bonus,
		"attack_power_bonus": hero.strength_bonus if hero.strength_phases > 0 else 0,
		"melee_weapon_damage": slot_item_value(hero, "main_hand", "weapon_damage") if _weapon_kind(hero.equipped_weapon_id) == ItemDefinition.WeaponKind.MELEE else 0,
		"ranged_weapon_damage": slot_item_value(hero, "main_hand", "weapon_damage") if _weapon_kind(hero.equipped_weapon_id) == ItemDefinition.WeaponKind.RANGED else 0,
		"block_rating": slot_item_value(hero, "off_hand", "defense_bonus")
	}
	var statuses: Dictionary = hero.overworld_statuses if include_temporary else {}
	var factor: float = energy_factor(hero.energy, definition.max_energy) if include_temporary and definition != null else 1.0
	return resolve(base, equipment, statuses, factor)


static func participant_values(participant: Variant) -> Dictionary:
	if participant == null:
		return {}
	var base: Dictionary = {
		"max_health": participant._base_max_health,
		"strength": participant.strength, "agility": participant.agility,
		"defense": participant.defense, "base_dodge_percent": participant.base_dodge_percent,
		"accuracy_bonus": participant.accuracy_bonus,
		"attack_power_bonus": int(participant.effects.get("strength_bonus", 0)) if int(participant.effects.get("strength_phases", 0)) > 0 else 0,
		"melee_weapon_damage": participant.weapon_damage(ItemDefinition.WeaponKind.MELEE),
		"ranged_weapon_damage": participant.weapon_damage(ItemDefinition.WeaponKind.RANGED),
		"block_rating": participant.block_armor
	}
	return resolve(base, {}, participant.statuses, energy_factor(participant.current_energy(), participant.max_energy))


static func resolve(base: Dictionary, equipment: Dictionary, statuses: Dictionary = {}, factor: float = 1.0) -> Dictionary:
	var strength: int = maxi(floori(float(maxi(int(base.get("strength", 0)) + int(equipment.get("strength_bonus", 0)), 0)) * factor), 0)
	var agility_raw: int = int(base.get("agility", 0)) + int(equipment.get("agility_bonus", 0)) + BattleStatusRules.modifier(statuses, AbilityEffectDefinition.Stat.AGILITY)
	var agility: int = maxi(floori(float(maxi(agility_raw, 0)) * factor), 0)
	var armor_raw: int = int(base.get("defense", 0)) + int(equipment.get("armor_bonus", 0))
	var defense: int = maxi(floori(float(maxi(armor_raw, 0)) * factor), 0)
	var maximum: int = BattleStatusRules.health_limit(int(base.get("max_health", 0)) + int(equipment.get("health_bonus", 0)), statuses)
	var dodge_base: int = int(base.get("base_dodge_percent", 0)) + int(equipment.get("dodge_bonus_percent", 0))
	var accuracy_bonus: int = int(base.get("accuracy_bonus", 0)) + int(equipment.get("accuracy_bonus_percent", 0))
	var attack_status: int = BattleStatusRules.modifier(statuses, AbilityEffectDefinition.Stat.ATTACK_POWER)
	var melee: float = BattleMath.melee_power(int(base.get("melee_weapon_damage", 0)), int(base.get("attack_power_bonus", 0)), strength)
	var ranged: float = BattleMath.ranged_power(int(base.get("ranged_weapon_damage", 0)), int(base.get("attack_power_bonus", 0)), agility)
	return {
		"max_health": maximum,
		"strength": strength, "agility": agility,
		"perception": maxi(int(base.get("perception", 0)) + int(equipment.get("perception_bonus", 0)), 0),
		"defense": defense,
		"base_dodge_percent": dodge_base,
		"accuracy_bonus": accuracy_bonus,
		"dodge_percent": maxi(dodge_base + agility + BattleStatusRules.modifier(statuses, AbilityEffectDefinition.Stat.DODGE_PERCENT), 0),
		"accuracy_percent": BattleMath.accuracy_total(agility, accuracy_bonus, BattleStatusRules.modifier(statuses, AbilityEffectDefinition.Stat.ACCURACY)),
		"poison_resistance_percent": clampi(int(equipment.get("poison_resistance_percent", 0)), 0, 100),
		"melee_power": melee, "ranged_power": ranged,
		"melee_attack": maxi(floori(melee) + attack_status, 0),
		"ranged_attack": maxi(floori(ranged) + attack_status, 0),
		"block_rating": int(base.get("block_rating", 0))
	}


static func preview_equipment(hero: Variant, slot_id: String, item: ItemDefinition, instance: ItemInstance = null) -> Dictionary:
	if hero == null or not EquipmentSlotRules.accepts(slot_id, item):
		return {}
	var preview = hero.copy_for_battle()
	match slot_id:
		"main_hand":
			preview.equipped_weapon_id = item.item_id
			if item.two_handed:
				preview.equipped_shield_id = ""
				preview.equipped_instance_ids.erase("off_hand")
		"off_hand":
			var weapon: ItemDefinition = ItemCatalog.get_item(preview.equipped_weapon_id)
			if weapon != null and weapon.two_handed:
				return {}
			preview.equipped_shield_id = item.item_id
		_:
			preview.equipped_accessories[slot_id] = item.item_id
	if instance != null and instance.item_id == item.item_id:
		preview.equipped_instance_ids[slot_id] = instance.instance_id
	else:
		preview.equipped_instance_ids.erase(slot_id)
	return hero_values(preview)

class_name ItemMagicCatalog
extends RefCounted

const RULES: ItemMagicRules = preload("res://data/item_magic_rules.tres")
const SCALED_FIELDS: Array[String] = ["weapon_damage", "defense_bonus", "armor_bonus", "max_durability"]
const MODIFIER_FIELDS: Array[String] = [
	"weapon_damage", "defense_bonus", "armor_bonus", "health_bonus", "strength_bonus",
	"agility_bonus", "perception_bonus", "dodge_bonus_percent", "accuracy_bonus_percent",
	"poison_resistance_percent"
]


static func quality(quality_id: String) -> ItemQualityDefinition:
	for entry in RULES.qualities:
		if entry != null and entry.quality_id == quality_id:
			return entry
	return null


static func rarity(tier: int) -> ItemRarityDefinition:
	for entry in RULES.rarities:
		if entry != null and entry.tier == tier:
			return entry
	return null


static func affix(affix_id: String) -> ItemAffixDefinition:
	for entry in RULES.affixes:
		if entry != null and entry.affix_id == affix_id:
			return entry
	return null


static func modifier_is_valid(item: ItemDefinition, key: String) -> bool:
	if item == null or not MODIFIER_FIELDS.has(key):
		return false
	if key == "weapon_damage":
		return item.equipment_slot == ItemDefinition.EquipmentSlot.WEAPON
	if key == "defense_bonus":
		return item.equipment_slot == ItemDefinition.EquipmentSlot.SHIELD
	if key == "armor_bonus":
		return item.equipment_slot not in [ItemDefinition.EquipmentSlot.WEAPON, ItemDefinition.EquipmentSlot.SHIELD]
	return true


static func effective_value(item: ItemDefinition, instance: ItemInstance, field: String) -> int:
	if item == null or not (field in MODIFIER_FIELDS or field == "max_durability"):
		return 0
	var base: int = int(item.get(field))
	if instance == null:
		return base
	var quality_definition: ItemQualityDefinition = quality(instance.quality_id)
	if quality_definition != null and quality_definition.accepts(item) and field in SCALED_FIELDS:
		base = roundi(float(base) * float(quality_definition.scaling_percent) / 100.0)
	var modifier: int = 0
	if modifier_is_valid(item, field) and instance.modifiers.has(field):
		var minimum: int = 0
		var maximum: int = 0
		for affix_id in instance.affix_ids:
			var definition: ItemAffixDefinition = affix(affix_id)
			if definition != null and definition.stat_id == field and definition.accepts(item):
				minimum += mini(definition.minimum_value, definition.maximum_value)
				maximum += maxi(definition.minimum_value, definition.maximum_value)
		var candidate: int = int(instance.modifiers[field])
		if (minimum != 0 or maximum != 0) and candidate >= minimum and candidate <= maximum:
			modifier = candidate
	var value: int = base + modifier
	return maxi(value, 0) if field in SCALED_FIELDS else value


static func display_name(item: ItemDefinition, instance: ItemInstance) -> String:
	if item == null:
		return ""
	if instance == null:
		return item.display_name
	var parts: Array[String] = [item.display_name]
	var quality_definition: ItemQualityDefinition = quality(instance.quality_id)
	if quality_definition != null and instance.quality_id != RULES.default_quality_id:
		parts.append(quality_definition.display_name)
	var rarity_definition: ItemRarityDefinition = rarity(instance.rarity)
	if rarity_definition != null and instance.rarity != ItemInstance.Rarity.COMMON:
		parts.append(rarity_definition.display_name)
	return " · ".join(parts)


static func display_color(instance: ItemInstance) -> Color:
	var rarity_definition: ItemRarityDefinition = rarity(instance.rarity) if instance != null else null
	return rarity_definition.color if rarity_definition != null else Color.WHITE


static func affix_lines(instance: ItemInstance) -> PackedStringArray:
	var lines := PackedStringArray()
	if instance == null:
		return lines
	for affix_id in instance.affix_ids:
		var definition: ItemAffixDefinition = affix(affix_id)
		if definition != null:
			lines.append(definition.display_name)
	return lines


static func _weight(entry: Resource, rarity_weights: Dictionary) -> int:
	if entry is ItemRarityDefinition:
		var rarity_definition: ItemRarityDefinition = entry as ItemRarityDefinition
		return maxi(int(rarity_weights.get(rarity_definition.tier, rarity_definition.roll_weight)), 0)
	return maxi(int(entry.get("roll_weight")), 0)


static func _draw(entries: Array, rng: RandomNumberGenerator, rarity_weights: Dictionary = {}) -> Resource:
	var total: int = 0
	for entry in entries:
		total += _weight(entry, rarity_weights)
	if total <= 0:
		return null
	var roll: int = rng.randi_range(1, total)
	for entry in entries:
		roll -= _weight(entry, rarity_weights)
		if roll <= 0:
			return entry
	return null


static func roll(instance: ItemInstance, item: ItemDefinition, rng: RandomNumberGenerator, loot_stage: int = -1, rarity_weights: Dictionary = {}) -> void:
	if instance == null or item == null or rng == null or item.category != ItemDefinition.Category.EQUIPMENT:
		return
	var qualities: Array = []
	for entry in RULES.qualities:
		if entry != null and entry.roll_weight > 0 and entry.accepts(item) and (loot_stage < 0 or loot_stage >= entry.minimum_loot_stage):
			qualities.append(entry)
	var selected_quality: ItemQualityDefinition = _draw(qualities, rng) as ItemQualityDefinition
	instance.quality_id = selected_quality.quality_id if selected_quality != null else RULES.default_quality_id
	var pool: Array = []
	for entry in RULES.affixes:
		if entry != null and entry.roll_weight > 0 and modifier_is_valid(item, entry.stat_id) and entry.accepts(item):
			pool.append(entry)
	var rarities: Array = []
	for entry in RULES.rarities:
		if entry != null and entry.roll_weight > 0 and entry.accepts(item) and (loot_stage < 0 or loot_stage >= entry.minimum_loot_stage) and (entry.minimum_affixes == 0 or pool.size() >= entry.minimum_affixes):
			rarities.append(entry)
	var selected_rarity: ItemRarityDefinition = _draw(rarities, rng, rarity_weights) as ItemRarityDefinition
	instance.rarity = selected_rarity.tier if selected_rarity != null else ItemInstance.Rarity.COMMON
	instance.modifiers.clear()
	instance.affix_ids.clear()
	if selected_rarity == null:
		return
	var count: int = mini(rng.randi_range(selected_rarity.minimum_affixes, maxi(selected_rarity.maximum_affixes, selected_rarity.minimum_affixes)), pool.size())
	for index in range(count):
		var selected: ItemAffixDefinition = _draw(pool, rng) as ItemAffixDefinition
		if selected == null:
			break
		instance.affix_ids.append(selected.affix_id)
		var modifier: int = rng.randi_range(mini(selected.minimum_value, selected.maximum_value), maxi(selected.minimum_value, selected.maximum_value))
		instance.modifiers[selected.stat_id] = int(instance.modifiers.get(selected.stat_id, 0)) + modifier
		pool.erase(selected)

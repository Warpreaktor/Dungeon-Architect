class_name BattleMath
extends RefCounted

const PERCENT_SCALE: int = 100
const RULES: BattleRules = preload("res://data/battle_rules.tres")
const USE_DEFAULT_BLOCK_ARMOR: int = -1


static func melee_power(weapon_damage: int, bonus_damage: int, strength: int) -> float:
	return float(weapon_damage + bonus_damage) + float(maxi(strength, 0)) * RULES.melee_strength_factor


static func ranged_power(weapon_damage: int, bonus_damage: int, agility: int) -> float:
	return float(weapon_damage + bonus_damage) + float(maxi(agility, 0)) * RULES.ranged_agility_factor


static func passive_armor_absorption(incoming: int, armor_rating: int) -> int:
	return mini(maxi(incoming, 0), maxi(armor_rating, 0) * RULES.passive_armor_reduction_per_point)


static func accuracy_total(agility: int, bonus: int, status_modifier: int) -> int:
	return maxi(RULES.base_accuracy_percent + maxi(agility, 0) + bonus + status_modifier, 0)

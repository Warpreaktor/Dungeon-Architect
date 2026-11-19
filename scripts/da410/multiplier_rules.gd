class_name DA410MultiplierRules
extends RefCounted

## Stateless conditional multiplier lookup. The caller supplies its already
## calculated attack power (including Strength/Agility, weapon and buffs).
## The combat executor remains responsible for rounding, dodge and armor.

const MULTIPLICATIVE_IDENTITY: float = 1.0 # Neutral coefficient, not balance.
const FIRST_SLOT_INDEX: int = 0 # Structural position, not a balance value.


static func get_multiplier(ability: Dictionary, slot_index: int, target_blocking: bool, target_resting: bool) -> float:
	var base: float = float(ability.get("base_multiplier", MULTIPLICATIVE_IDENTITY))
	var conditions: Array = ability.get("conditional_multipliers", [])
	var by_condition: Dictionary = {}
	for entry in conditions:
		if entry is Dictionary:
			by_condition[StringName(str(entry.get("when", "")))] = float(entry.get("value", base))

	# Explicit priority lets the creator resolve simultaneous status flags.
	var precedence: Array = ability.get("conditional_precedence", [&"target_is_blocking", &"target_is_resting", &"first_configured_slot"])
	for condition in precedence:
		var key: StringName = StringName(str(condition))
		if not by_condition.has(key):
			continue
		if key == &"target_is_blocking" and target_blocking:
			return float(by_condition[key])
		if key == &"target_is_resting" and target_resting:
			return float(by_condition[key])
		if key == &"first_configured_slot" and slot_index == FIRST_SLOT_INDEX:
			return float(by_condition[key])
	return base


static func get_subhit_powers(ability: Dictionary, attack_power: float, slot_index: int, target_blocking: bool, target_resting: bool) -> Array[float]:
	var powers: Array[float] = []
	var hits: int = maxi(int(ability.get("hits", 0)), 0)
	var multiplier: float = get_multiplier(ability, slot_index, target_blocking, target_resting)
	for i in range(hits):
		powers.append(maxf(attack_power, 0.0) * multiplier)
	return powers

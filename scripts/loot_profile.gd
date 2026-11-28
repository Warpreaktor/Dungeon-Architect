class_name LootProfile
extends Resource

const REWARD_LEVELS = [
	preload("res://data/loot_reward_levels/1.tres"),
	preload("res://data/loot_reward_levels/2.tres"),
	preload("res://data/loot_reward_levels/3.tres")
]

@export var display_name: String = ""
@export var progression: WeightedLootTable
@export var pools: Array[LootPool] = []
@export var rarity_weights: Dictionary = {}
@export_range(0, 100, 1, "suffix:%") var no_drop_chance: int = 0


func prepare() -> void:
	for pool in pools:
		if pool != null:
			pool.prepare()


static func normalize_level(level: int) -> int:
	return clampi(level, 1, REWARD_LEVELS.size())


static func level_rules(level: int) -> LootRewardLevel:
	return REWARD_LEVELS[normalize_level(level) - 1] as LootRewardLevel


func possible_item_ids(level: int = 1) -> Array[String]:
	var ids: Array[String] = []
	if no_drop_chance >= 100:
		return ids
	var stage: int = level_rules(level).stage_for(progression, 0, 0)
	for pool in pools:
		if pool == null:
			continue
		for item_id in pool.possible_item_ids(stage):
			if item_id not in ids:
				ids.append(item_id)
	return ids


func roll(rng: RandomNumberGenerator, victories: int, depth: int, level: int = 1) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	if rng == null or no_drop_chance >= 100:
		return rewards
	if no_drop_chance > 0 and rng.randi_range(1, 100) <= no_drop_chance:
		return rewards
	var rules: LootRewardLevel = level_rules(level)
	var stage: int = rules.stage_for(progression, victories, depth)
	for pool in pools:
		if pool == null:
			continue
		for reward in pool.roll(rng, stage):
			if bool(reward.get("roll_magic", false)):
				reward["loot_stage"] = stage
				reward["rarity_weights"] = rarity_weights.duplicate()
			rules.apply_quantity(reward)
			rewards.append(reward)
	return rewards

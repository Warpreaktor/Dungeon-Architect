class_name LootProfile
extends Resource

@export var display_name: String = ""
@export var progression: WeightedLootTable
@export var pools: Array[LootPool] = []
@export var rarity_weights: Dictionary = {}


func prepare() -> void:
	for pool in pools:
		if pool != null:
			pool.prepare()


func roll(rng: RandomNumberGenerator, victories: int, depth: int) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	var stage: int = progression.stage_for_progress(victories, depth) if progression != null else 0
	for pool in pools:
		if pool == null:
			continue
		for reward in pool.roll(rng, stage):
			if bool(reward.get("roll_magic", false)):
				reward["loot_stage"] = stage
				reward["rarity_weights"] = rarity_weights.duplicate()
			rewards.append(reward)
	return rewards

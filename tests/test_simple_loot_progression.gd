extends SceneTree


func _initialize() -> void:
	_test_available_items()
	_test_quality_and_rarity_stages()
	_test_fixed_chest_and_save()
	print("Loot: base item stages, magic and chest persistence OK")
	quit()


func _test_available_items() -> void:
	var table: WeightedLootTable = ItemCatalog.LOOT_TABLE
	assert(table.stage_for_victories(0) == 0)
	assert(table.stage_for_victories(1) == 1)
	assert(table.stage_for_victories(2) == 1)
	assert(table.stage_for_victories(3) == 2)
	assert(table.allows("sword", 0))
	assert(not table.allows("warhammer", 0))
	assert(table.allows("warhammer", 2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9213
	for stage in range(3):
		for i in range(500):
			var reward: Dictionary = ItemCatalog.roll_loot(rng, table, stage)
			assert(not reward.is_empty())
			assert(table.allows(str(reward["item_id"]), stage))
			assert(ItemCatalog.get_item(str(reward["item_id"])).category != ItemDefinition.Category.QUEST)


func _test_quality_and_rarity_stages() -> void:
	var sword: ItemDefinition = ItemCatalog.get_item("sword")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9214
	var middle_magic: bool = false
	var late_masterwork: bool = false
	var late_rare: bool = false
	for i in range(1200):
		var starter: ItemInstance = ItemInstance.create("starter_%d" % i, sword)
		ItemMagicCatalog.roll(starter, sword, rng, 0)
		assert(starter.quality_id == "standard")
		assert(starter.rarity == ItemInstance.Rarity.COMMON)
		var middle: ItemInstance = ItemInstance.create("middle_%d" % i, sword)
		ItemMagicCatalog.roll(middle, sword, rng, 1)
		assert(middle.quality_id != "masterwork")
		assert(middle.rarity in [ItemInstance.Rarity.COMMON, ItemInstance.Rarity.MAGIC])
		middle_magic = middle_magic or middle.rarity == ItemInstance.Rarity.MAGIC
		var late: ItemInstance = ItemInstance.create("late_%d" % i, sword)
		ItemMagicCatalog.roll(late, sword, rng, 2)
		late_masterwork = late_masterwork or late.quality_id == "masterwork"
		late_rare = late_rare or late.rarity == ItemInstance.Rarity.RARE
	assert(middle_magic and late_masterwork and late_rare)


func _test_fixed_chest_and_save() -> void:
	var dungeon: DungeonMap = DungeonMap.create_blank(7, 7)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("chest", 3, 2))
	var chest: Dictionary = dungeon.entities_at(3, 2)[0]
	assert(dungeon.set_chest_contents(str(chest["id"]), ["warhammer"], 5, false))
	var session: GameSession = GameSession.start_for(dungeon)
	assert(session != null)
	assert(session.move_by(1, 0))
	assert(session.is_chest_open(chest))
	var instance: ItemInstance = session.item_instance("item_%d" % session._next_item_instance_number)
	assert(instance != null and instance.item_id == "warhammer")
	assert(instance.quality_id == "standard" and instance.rarity == ItemInstance.Rarity.COMMON)
	session.loot_victories = 3
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	assert(not snapshot.is_empty())
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {dungeon.map_id: dungeon})
	assert(restored != null and restored.loot_victories == 3)
	assert(restored.is_chest_open(chest))
	var copy: ItemInstance = restored.item_instance(instance.instance_id)
	assert(copy != null and copy.to_dict() == instance.to_dict())
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy["party"].erase("loot_victories")
	var legacy_restored: GameSession = GameSession.from_progress_snapshot(legacy, {dungeon.map_id: dungeon})
	assert(legacy_restored != null and legacy_restored.loot_victories == 0)

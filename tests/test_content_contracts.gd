extends SceneTree


func _initialize() -> void:
	_check_catalog(HeroCatalog.list_ids(), "res://heroes")
	_check_catalog(MonsterCatalog.list_ids(), "res://monsters")
	_check_catalog(ItemCatalog.list_ids(), "res://items")
	assert(not HeroCatalog.list_ids().is_empty())
	assert(not MonsterCatalog.list_ids().is_empty())
	assert(not ItemCatalog.list_ids().is_empty())
	assert(not ResourceCatalog.is_valid_id("../other"))
	assert(ResourceCatalog.load_by_id("res://heroes", "../other") == null)
	assert(HeroCatalog.get_hero(HeroCatalog.DEFAULT_HERO_ID) != null)
	assert(MonsterCatalog.get_monster(MonsterCatalog.DEFAULT_MONSTER_ID) != null)
	assert(MonsterCatalog.get_monster("small_monster") == MonsterCatalog.get_monster(MonsterCatalog.LEGACY_IDS["small_monster"]))
	_check_loot()
	_check_equipment()
	quit()


func _check_catalog(ids: Array[String], directory: String) -> void:
	var sorted_ids: Array[String] = ids.duplicate()
	sorted_ids.sort()
	assert(ids == sorted_ids)
	for id in ids:
		var resource: Resource = ResourceCatalog.load_by_id(directory, id)
		assert(resource != null)
		assert(ResourceCatalog.is_valid_id(id))


func _check_loot() -> void:
	var table: WeightedLootTable = ItemCatalog.LOOT_TABLE
	assert(not table.weights.is_empty())
	for id in table.weights:
		assert(ItemCatalog.get_item(str(id)) != null)
		assert(int(table.weights[id]) > 0)
	var left := RandomNumberGenerator.new()
	var right := RandomNumberGenerator.new()
	var same_seed: int = randi()
	left.seed = same_seed
	right.seed = same_seed
	for _draw in range(table.weights.size()):
		var first: Dictionary = ItemCatalog.roll_loot(left)
		var second: Dictionary = ItemCatalog.roll_loot(right)
		assert(first == second)
		assert(table.weights.has(first.get("item_id", "")))
		var item: ItemDefinition = ItemCatalog.get_item(str(first.get("item_id", "")))
		assert(item.category != ItemDefinition.Category.QUEST)
		assert(int(first.get("quantity", 0)) > 0)
	var empty_table := WeightedLootTable.new()
	assert(empty_table.draw_id({}).is_empty())
	assert(ItemCatalog.roll_loot(null, empty_table).is_empty())


func _check_equipment() -> void:
	var shield: ItemDefinition
	for item_id in ItemCatalog.equipment_ids():
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		if item.equipment_slot == ItemDefinition.EquipmentSlot.SHIELD and item.defense_bonus > 0:
			shield = item
			break
	assert(shield != null)
	var hero := HeroState.new(HeroCatalog.get_hero(HeroCatalog.DEFAULT_HERO_ID))
	hero.register_shield(shield)
	assert(hero.equip_item(shield))
	var participant: BattleParticipant = BattleParticipant.from_hero(hero)
	assert(participant.has_serviceable_shield())
	assert(participant.shield_durability(shield.item_id) == hero.current_shield_durability(shield.item_id))
	assert(participant.preview_block_armor() == maxi(shield.defense_bonus, 0))
	participant.prepare_block(BattleMath.RULES.unarmed_block_armor)
	var incoming: int = maxi(participant.block_armor, 1)
	var initial_durability: int = participant.shield_durability(shield.item_id)
	participant.receive_damage(incoming)
	assert(participant.block_armor == 0)
	assert(participant.shield_durability(shield.item_id) <= initial_durability)
	assert(hero.current_shield_durability(shield.item_id) == initial_durability)

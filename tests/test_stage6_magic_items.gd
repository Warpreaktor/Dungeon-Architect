extends SceneTree


func _initialize() -> void:
	_test_resource_catalog_and_roll()
	_test_quality_rarity_and_description()
	_test_equipment_battle_and_preview()
	_test_save_restore_and_legacy()
	_test_magic_health_roundtrip()
	_test_enchanted_shield_block()
	_test_random_loot_pipeline()
	print("DA-6.06: quality, rarity, affixes, equipment and inventory OK")
	quit()


func _session() -> GameSession:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return GameSession.start_for_party(dungeon, ["petushan", "volcha"])


func _test_resource_catalog_and_roll() -> void:
	assert(ItemMagicCatalog.quality("standard") != null)
	assert(ItemMagicCatalog.quality("masterwork") != null)
	assert(ItemMagicCatalog.rarity(ItemInstance.Rarity.MAGIC) != null)
	assert(ItemMagicCatalog.rarity(ItemInstance.Rarity.RARE) != null)
	assert(ItemMagicCatalog.affix("edge").accepts(ItemCatalog.get_item("sword")))
	assert(not ItemMagicCatalog.affix("edge").accepts(ItemCatalog.get_item("shield")))
	assert(not ItemMagicCatalog.affix("guard").accepts(ItemCatalog.get_item("sword")))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7119
	var magic_count: int = 0
	for index in range(150):
		var definition: ItemDefinition = ItemCatalog.get_item("sword")
		var instance: ItemInstance = ItemInstance.create("roll_%d" % index, definition)
		ItemMagicCatalog.roll(instance, definition, rng)
		assert(ItemMagicCatalog.quality(instance.quality_id) != null)
		assert(instance.rarity in [ItemInstance.Rarity.COMMON, ItemInstance.Rarity.MAGIC, ItemInstance.Rarity.RARE])
		for stat_id in instance.modifiers:
			assert(ItemMagicCatalog.modifier_is_valid(definition, str(stat_id)))
		if instance.rarity != ItemInstance.Rarity.COMMON:
			magic_count += 1
			assert(not instance.affix_ids.is_empty())
	assert(magic_count > 0)


func _test_quality_rarity_and_description() -> void:
	var sword: ItemDefinition = ItemCatalog.get_item("sword")
	var regular: ItemInstance = ItemInstance.create("item_100", sword)
	var magic: ItemInstance = ItemInstance.create("item_101", sword)
	magic.quality_id = "masterwork"
	magic.rarity = ItemInstance.Rarity.MAGIC
	magic.affix_ids = ["edge"]
	magic.modifiers["weapon_damage"] = 2
	assert(magic.item_id == regular.item_id)
	assert(magic.stat("weapon_damage") > regular.stat("weapon_damage"))
	assert(magic.display_name() != regular.display_name())
	assert(not sword.get_description(magic).is_empty())
	assert(sword.get_description(magic).contains("Острота"))
	assert(ItemMagicCatalog.display_color(magic) != ItemMagicCatalog.display_color(regular))
	var copy: ItemInstance = ItemInstance.from_dict(magic.to_dict())
	assert(copy != null)
	assert(copy.quality_id == magic.quality_id)
	assert(copy.modifiers == magic.modifiers)
	assert(copy.affix_ids == magic.affix_ids)


func _test_equipment_battle_and_preview() -> void:
	var session: GameSession = _session()
	var armor: ItemDefinition = ItemCatalog.get_item("armor_chain_shirt")
	assert(session._receive_item(armor.item_id, 2) == 2)
	var bag: Array[String] = session.inventory_slot_ids()
	var first: int = bag.find(armor.item_id)
	var second: int = bag.find(armor.item_id, first + 1)
	assert(first >= 0 and second >= 0)
	var magic: ItemInstance = session.item_instance(session.inventory_instance_id(first))
	var regular: ItemInstance = session.item_instance(session.inventory_instance_id(second))
	assert(magic != null and regular != null and magic.instance_id != regular.instance_id)
	magic.quality_id = "masterwork"
	magic.rarity = ItemInstance.Rarity.MAGIC
	magic.affix_ids = ["warding"]
	magic.modifiers["armor_bonus"] = 2
	var before: Dictionary = CharacterStats.hero_values(session.hero)
	var preview: Dictionary = CharacterStats.preview_equipment(session.hero, "body", armor, magic)
	assert(int(preview["defense"]) > int(before["defense"]) + armor.armor_bonus)
	assert(session.transfer_inventory_item("bag", first, "equipment", "body"))
	assert(int(CharacterStats.hero_values(session.hero)["defense"]) == int(preview["defense"]))
	assert(session.hero.equipment_bonus("armor_bonus") == magic.stat("armor_bonus"))
	var actor: BattleParticipant = BattleParticipant.from_hero(session.hero)
	assert(actor.effective_defense() == int(preview["defense"]))
	assert(actor.receive_damage(15) == 15 - BattleMath.passive_armor_absorption(15, int(preview["defense"])))
	assert(session.transfer_inventory_item("bag", second, "equipment", "body"))
	assert(session.hero.equipment_bonus("armor_bonus") == armor.armor_bonus)
	assert(magic.instance_id != regular.instance_id)
	var scene: PackedScene = load("res://scenes/inventory_view.tscn") as PackedScene
	assert(scene != null)
	var view: InventoryView = scene.instantiate() as InventoryView
	root.add_child(view)
	view.open_for(session)
	var magic_index: int = session.inventory_slot_ids().find(armor.item_id)
	assert(magic_index >= 0)
	view._show_item(magic_index)
	assert(view._item_name.text.contains("волшебное"))
	assert(view._item_comparison.text.contains("После замены"))
	assert(view._item_description.text.contains("Броня:"))
	view.queue_free()


func _test_save_restore_and_legacy() -> void:
	var session: GameSession = _session()
	assert(session._receive_item("sword", 1) == 1)
	var index: int = session.inventory_slot_ids().find("sword")
	var instance: ItemInstance = session.item_instance(session.inventory_instance_id(index))
	instance.rarity = ItemInstance.Rarity.MAGIC
	instance.quality_id = "sturdy"
	instance.affix_ids = ["edge"]
	instance.modifiers["weapon_damage"] = 2
	var save: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var maps: Dictionary = {session.map_data.map_id: session.map_data}
	var restored: GameSession = GameSession.from_progress_snapshot(save, maps)
	assert(restored != null)
	var loaded: ItemInstance = restored.item_instance(restored.inventory_instance_id(index))
	assert(loaded != null and loaded.to_dict() == instance.to_dict())
	var legacy: Dictionary = instance.to_dict()
	legacy.erase("quality_id")
	legacy.erase("affix_ids")
	assert(ItemInstance.from_dict(legacy) != null)


func _test_magic_health_roundtrip() -> void:
	var session: GameSession = _session()
	assert(session._receive_item("ring_copper_wire", 1) == 1)
	var index: int = session.inventory_slot_ids().find("ring_copper_wire")
	var instance: ItemInstance = session.item_instance(session.inventory_instance_id(index))
	instance.rarity = ItemInstance.Rarity.MAGIC
	instance.affix_ids = ["vigor"]
	instance.modifiers["health_bonus"] = 5
	assert(session.transfer_inventory_item("bag", index, "equipment", "ring_left"))
	var maximum: int = session.hero.effective_max_health()
	assert(maximum > session.hero.max_health)
	session.hero.health = maximum
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {session.map_data.map_id: session.map_data})
	assert(restored != null)
	assert(restored.hero.health == maximum)
	assert(restored.hero.effective_max_health() == maximum)


func _test_enchanted_shield_block() -> void:
	var session: GameSession = _session()
	assert(session._receive_item("shield", 1) == 1)
	var instance: ItemInstance = session.item_instance(session.equipment_instance_id("off_hand"))
	assert(instance != null)
	instance.quality_id = "masterwork"
	instance.rarity = ItemInstance.Rarity.MAGIC
	instance.affix_ids = ["guard"]
	instance.modifiers["defense_bonus"] = 2
	var shield: ItemDefinition = ItemCatalog.get_item("shield")
	assert(instance.stat("defense_bonus") > shield.defense_bonus)
	var actor: BattleParticipant = BattleParticipant.from_hero(session.hero)
	actor.prepare_block(BattleMath.RULES.unarmed_block_armor)
	assert(actor.block_armor == instance.stat("defense_bonus"))
	assert(actor.effective_defense() == int(CharacterStats.hero_values(session.hero)["defense"]))


func _test_random_loot_pipeline() -> void:
	var session: GameSession = _session()
	session.trap_random.seed = 7119
	assert(session._receive_item("sword", 1, [], true) == 1)
	var index: int = session.inventory_slot_ids().find("sword")
	var instance: ItemInstance = session.item_instance(session.inventory_instance_id(index))
	assert(instance != null)
	assert(ItemMagicCatalog.quality(instance.quality_id) != null)
	assert(ItemMagicCatalog.rarity(instance.rarity) != null)
	var reward: Dictionary = ItemCatalog.roll_loot(session.trap_random)
	assert(reward.has("item_id"))
	if ItemCatalog.get_item(str(reward["item_id"])).category == ItemDefinition.Category.EQUIPMENT:
		assert(bool(reward.get("roll_magic", false)))

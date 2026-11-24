extends SceneTree

const BOOT_IDS: Array[String] = [
	"boots_bast_shoes", "boots_canvas_shoes", "boots_felt",
	"boots_leather_ankle", "boots_ranger", "boots_miner",
	"boots_high_leather", "boots_hobnailed", "boots_chainmail",
	"boots_iron_sabatons"
]


func _initialize() -> void:
	_test_catalog_and_random_loot()
	_test_equipment_and_save()
	_test_editor_palette_and_legacy_rewards()
	print("DA-6: boots, loot, equipment and legacy rewards OK")
	quit()


func _session() -> GameSession:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return GameSession.start_for_party(dungeon, ["petushan", "volcha"])


func _test_catalog_and_random_loot() -> void:
	var ids: Array[String] = ItemCatalog.list_ids()
	for item_id in BOOT_IDS:
		assert(ids.has(item_id))
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		assert(item != null)
		assert(item.category == ItemDefinition.Category.EQUIPMENT)
		assert(item.equipment_slot == ItemDefinition.EquipmentSlot.BOOTS)
		assert(not item.stackable)
		assert(item.icon != null)
		assert(item.icon.get_width() == 64 and item.icon.get_height() == 64)
		assert(EquipmentSlotRules.accepts("boots", item))
		assert(not EquipmentSlotRules.accepts("gloves", item))
		assert(DescriptionTemplate.unresolved_tokens(item.get_description()).is_empty())
		assert(int(ItemCatalog.LOOT_TABLE.weights.get(item_id, 0)) > 0)
		assert(DungeonMap.CHEST_REWARDS.has(item_id))
	var found_ids: Array[String] = []
	for item_id in ids:
		if item_id.begins_with("boots_"):
			found_ids.append(item_id)
	assert(found_ids.size() == BOOT_IDS.size())
	assert(ItemCatalog.get_item("boots_iron_sabatons").armor_bonus == 2)
	assert(ItemCatalog.get_item("boots_iron_sabatons").agility_bonus == -2)
	assert(ItemCatalog.get_item("boots_ranger").perception_bonus == 1)
	var table: WeightedLootTable = WeightedLootTable.new()
	table.weights = {"boots_miner": 1}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1909
	assert(ItemCatalog.roll_loot(rng, table) == {"item_id": "boots_miner", "quantity": 1})
	assert(ItemCatalog.get_item("leather_boots") != null)
	assert(not ids.has("leather_boots"))
	assert(DungeonMap.CHEST_REWARDS.has("leather_boots"))


func _test_equipment_and_save() -> void:
	var session: GameSession = _session()
	var first: HeroState = session.party[0]
	var second: HeroState = session.party[1]
	var light: ItemDefinition = ItemCatalog.get_item("boots_leather_ankle")
	var heavy: ItemDefinition = ItemCatalog.get_item("boots_iron_sabatons")
	assert(session._receive_item(light.item_id, 1) == 1)
	var light_slot: int = session.inventory_slot_ids().find(light.item_id)
	assert(light_slot >= 0)
	var light_id: String = session.inventory_instance_id(light_slot)
	assert(session.transfer_inventory_item("bag", light_slot, "equipment", "boots"))
	assert(session.equipment_instance_id("boots", first) == light_id)
	assert(first.effective_agility() == first.agility + light.agility_bonus)
	assert(not session.transfer_inventory_item("equipment", "boots", "equipment", "head"))

	assert(session._receive_item(heavy.item_id, 2) == 2)
	var first_heavy_slot: int = session.inventory_slot_ids().find(heavy.item_id)
	assert(first_heavy_slot >= 0)
	var first_heavy_id: String = session.inventory_instance_id(first_heavy_slot)
	assert(session.transfer_inventory_item("bag", first_heavy_slot, "equipment", "boots"))
	assert(session.equipment_instance_id("boots", first) == first_heavy_id)
	assert(session.inventory_instance_id(first_heavy_slot) == light_id)
	assert(session.inventory_slot_ids()[first_heavy_slot] == light.item_id)
	assert(first.effective_max_health() == first.max_health + heavy.health_bonus)
	assert(first.effective_agility() == maxi(0, first.agility + heavy.agility_bonus))
	var fighter: BattleParticipant = BattleParticipant.from_hero(first)
	assert(fighter.max_health == first.effective_max_health())
	assert(fighter.agility == first.effective_agility())
	assert(fighter.base_dodge_percent == first.definition.base_dodge_percent + heavy.dodge_bonus_percent)
	assert(first.defense == 0)
	session.item_instance(first_heavy_id).rarity = ItemInstance.Rarity.MAGIC
	session.item_instance(first_heavy_id).modifiers["perception"] = 1

	session.inventory_member = second
	var second_heavy_slot: int = session.inventory_slot_ids().find(heavy.item_id)
	assert(second_heavy_slot >= 0)
	var second_heavy_id: String = session.inventory_instance_id(second_heavy_slot)
	assert(second_heavy_id != first_heavy_id)
	assert(session.transfer_inventory_item("bag", second_heavy_slot, "equipment", "boots"))
	assert(session.equipment_instance_id("boots", second) == second_heavy_id)
	assert(session.equipment_instance_id("boots", first) == first_heavy_id)

	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {session.map_data.map_id: session.map_data})
	assert(restored != null)
	assert(restored.equipment_instance_id("boots", restored.party[0]) == first_heavy_id)
	assert(restored.equipment_instance_id("boots", restored.party[1]) == second_heavy_id)
	assert(restored.item_instance(first_heavy_id).rarity == ItemInstance.Rarity.MAGIC)
	assert(restored.item_instance(first_heavy_id).modifiers["perception"] == 1)
	assert(restored.party[0].effective_max_health() == first.effective_max_health())
	restored.inventory_member = restored.party[0]
	var empty_slot: int = restored.inventory_slot_ids().find("")
	assert(empty_slot >= 0)
	assert(restored.unequip_equipment_slot("boots"))
	assert(restored.equipment_instance_id("boots", restored.party[0]).is_empty())
	assert(restored.inventory_instance_id(empty_slot) == first_heavy_id)
	assert(restored.equipment_instance_id("boots", restored.party[1]) == second_heavy_id)


func _test_editor_palette_and_legacy_rewards() -> void:
	var scene: PackedScene = load("res://scenes/chest_contents_popup.tscn") as PackedScene
	assert(scene != null)
	var popup: ChestContentsPopup = scene.instantiate() as ChestContentsPopup
	root.add_child(popup)
	assert(popup._group_contents.has("Сапоги"))
	assert(popup._group_contents.has("Снаряжение"))
	for item_id in BOOT_IDS:
		assert(popup._item_checks.has(item_id))
	assert(not popup._item_checks.has("leather_boots"))
	var captured: Dictionary = {}
	popup.contents_changed.connect(func(_entity_id: String, contents: Array[String], _gold: int, _random: bool, _hidden: bool, quantities: Dictionary) -> void:
		captured["items"] = contents.duplicate()
		captured["quantities"] = quantities.duplicate()
	)
	var old_contents: Array[String] = ["leather_boots", "boots_canvas_shoes"]
	popup.configure("legacy_chest", old_contents, 5, false, false, false, {"leather_boots": 2, "boots_canvas_shoes": 1})
	popup._save()
	assert((captured.get("items", []) as Array).has("leather_boots"))
	assert(int((captured.get("quantities", {}) as Dictionary).get("leather_boots", 0)) == 2)
	popup.queue_free()

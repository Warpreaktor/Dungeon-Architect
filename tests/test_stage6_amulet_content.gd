extends SceneTree

const AMULET_IDS: Array[String] = [
	"amulet_knotted_cord", "amulet_clay_bead", "amulet_wooden_disc",
	"amulet_bone_fang", "amulet_copper_coin", "amulet_river_pebble",
	"amulet_braided_cord", "amulet_iron_tag", "amulet_brass_plate",
	"amulet_flint_shard"
]


func _initialize() -> void:
	_test_catalog_and_loot()
	_test_equipment_and_save()
	_test_accuracy_bonus()
	_test_editor_and_legacy_rewards()
	print("DA-6: amulets, loot, equipment and legacy rewards OK")
	quit()


func _session() -> GameSession:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return GameSession.start_for_party(dungeon, ["petushan", "volcha"])


func _test_catalog_and_loot() -> void:
	var ids: Array[String] = ItemCatalog.list_ids()
	for item_id in AMULET_IDS:
		assert(ids.has(item_id))
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		assert(item != null)
		assert(item.category == ItemDefinition.Category.EQUIPMENT)
		assert(item.equipment_slot == ItemDefinition.EquipmentSlot.NECK)
		assert(not item.stackable)
		assert(item.icon != null)
		assert(item.icon.get_width() == 64 and item.icon.get_height() == 64)
		assert(EquipmentSlotRules.accepts("neck", item))
		assert(not EquipmentSlotRules.accepts("ring_left", item))
		assert(DescriptionTemplate.unresolved_tokens(item.get_description()).is_empty())
		assert(int(ItemCatalog.LOOT_TABLE.weights.get(item_id, 0)) > 0)
		assert(DungeonMap.CHEST_REWARDS.has(item_id))
	var found: Array[String] = []
	for item_id in ids:
		if item_id.begins_with("amulet_"):
			found.append(item_id)
	assert(found.size() == AMULET_IDS.size())
	assert(ItemCatalog.get_item("amulet_braided_cord").agility_bonus == 1)
	assert(ItemCatalog.get_item("amulet_iron_tag").agility_bonus == -1)
	assert(ItemCatalog.get_item("amulet_wooden_disc").perception_bonus == 1)
	assert(ItemCatalog.get_item("amulet_brass_plate").accuracy_bonus_percent == 2)
	var table: WeightedLootTable = WeightedLootTable.new()
	table.weights = {"amulet_river_pebble": 1}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2116
	assert(ItemCatalog.roll_loot(rng, table) == {"item_id": "amulet_river_pebble", "quantity": 1})
	assert(ItemCatalog.get_item("plain_amulet") != null)
	assert(not ids.has("plain_amulet"))
	assert(DungeonMap.CHEST_REWARDS.has("plain_amulet"))


func _test_equipment_and_save() -> void:
	var session: GameSession = _session()
	var first: HeroState = session.party[0]
	var second: HeroState = session.party[1]
	var light: ItemDefinition = ItemCatalog.get_item("amulet_braided_cord")
	var heavy: ItemDefinition = ItemCatalog.get_item("amulet_flint_shard")
	assert(session._receive_item(light.item_id, 1) == 1)
	var light_slot: int = session.inventory_slot_ids().find(light.item_id)
	assert(light_slot >= 0)
	var light_id: String = session.inventory_instance_id(light_slot)
	assert(session.transfer_inventory_item("bag", light_slot, "equipment", "neck"))
	assert(session.equipment_instance_id("neck", first) == light_id)
	assert(first.effective_agility() == first.agility + light.agility_bonus)
	assert(not session.transfer_inventory_item("equipment", "neck", "equipment", "head"))

	assert(session._receive_item(heavy.item_id, 2) == 2)
	var first_heavy_slot: int = session.inventory_slot_ids().find(heavy.item_id)
	assert(first_heavy_slot >= 0)
	var first_heavy_id: String = session.inventory_instance_id(first_heavy_slot)
	assert(session.transfer_inventory_item("bag", first_heavy_slot, "equipment", "neck"))
	assert(session.equipment_instance_id("neck", first) == first_heavy_id)
	assert(session.inventory_instance_id(first_heavy_slot) == light_id)
	assert(session.inventory_slot_ids()[first_heavy_slot] == light.item_id)
	assert(first.effective_max_health() == first.max_health + heavy.health_bonus)
	assert(first.effective_strength() == first.strength + heavy.strength_bonus)
	assert(first.effective_agility() == maxi(first.agility + heavy.agility_bonus, 0))
	var fighter: BattleParticipant = BattleParticipant.from_hero(first)
	assert(fighter.max_health == first.effective_max_health())
	assert(fighter.strength == first.effective_strength())
	assert(fighter.agility == first.effective_agility())
	session.item_instance(first_heavy_id).rarity = ItemInstance.Rarity.MAGIC
	session.item_instance(first_heavy_id).modifiers["perception"] = 1

	session.inventory_member = second
	var second_slot: int = session.inventory_slot_ids().find(heavy.item_id)
	assert(second_slot >= 0)
	var second_heavy_id: String = session.inventory_instance_id(second_slot)
	assert(second_heavy_id != first_heavy_id)
	assert(session.transfer_inventory_item("bag", second_slot, "equipment", "neck"))
	assert(session.equipment_instance_id("neck", second) == second_heavy_id)
	assert(session.equipment_instance_id("neck", first) == first_heavy_id)

	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {session.map_data.map_id: session.map_data})
	assert(restored != null)
	assert(restored.equipment_instance_id("neck", restored.party[0]) == first_heavy_id)
	assert(restored.equipment_instance_id("neck", restored.party[1]) == second_heavy_id)
	assert(restored.item_instance(first_heavy_id).rarity == ItemInstance.Rarity.MAGIC)
	assert(restored.item_instance(first_heavy_id).modifiers["perception"] == 1)
	assert(restored.party[0].effective_max_health() == first.effective_max_health())
	restored.inventory_member = restored.party[0]
	var empty_slot: int = restored.inventory_slot_ids().find("")
	assert(empty_slot >= 0)
	assert(restored.unequip_equipment_slot("neck"))
	assert(restored.equipment_instance_id("neck", restored.party[0]).is_empty())
	assert(restored.inventory_instance_id(empty_slot) == first_heavy_id)
	assert(restored.equipment_instance_id("neck", restored.party[1]) == second_heavy_id)


func _test_accuracy_bonus() -> void:
	var session: GameSession = _session()
	var hero: HeroState = session.party[0]
	var item: ItemDefinition = ItemCatalog.get_item("amulet_brass_plate")
	assert(session._receive_item(item.item_id, 1) == 1)
	var slot: int = session.inventory_slot_ids().find(item.item_id)
	assert(slot >= 0)
	assert(session.transfer_inventory_item("bag", slot, "equipment", "neck"))
	assert(BattleParticipant.from_hero(hero).accuracy_bonus == hero.definition.accuracy_bonus + item.accuracy_bonus_percent)


func _test_editor_and_legacy_rewards() -> void:
	var scene: PackedScene = load("res://scenes/chest_contents_popup.tscn") as PackedScene
	assert(scene != null)
	var popup: ChestContentsPopup = scene.instantiate() as ChestContentsPopup
	root.add_child(popup)
	assert(popup._group_contents.has("Амулеты"))
	for item_id in AMULET_IDS:
		assert(popup._item_checks.has(item_id))
	assert(not popup._item_checks.has("plain_amulet"))
	var captured: Dictionary = {}
	popup.contents_changed.connect(func(_entity_id: String, contents: Array[String], _gold: int, _random: bool, _hidden: bool, quantities: Dictionary, _reward_level: int) -> void:
		captured["items"] = contents.duplicate()
		captured["quantities"] = quantities.duplicate()
	)
	var old_contents: Array[String] = ["plain_amulet", "amulet_clay_bead"]
	popup.configure("legacy_chest", old_contents, 5, false, false, false, {"plain_amulet": 2, "amulet_clay_bead": 1})
	popup._save()
	assert((captured.get("items", []) as Array).has("plain_amulet"))
	assert(int((captured.get("quantities", {}) as Dictionary).get("plain_amulet", 0)) == 2)
	popup.queue_free()

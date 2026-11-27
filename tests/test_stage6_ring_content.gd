extends SceneTree

const RING_IDS: Array[String] = [
	"ring_copper_wire", "ring_braided_wire", "ring_wooden", "ring_bone_carved",
	"ring_copper_band", "ring_leather_wrapped", "ring_brass_notched",
	"ring_blacksmith", "ring_river_pebble", "ring_militia_signet"
]


func _initialize() -> void:
	_test_catalog_and_loot()
	_test_two_ring_slots_and_save()
	_test_editor_and_legacy_rewards()
	print("DA-6: rings, two equipment slots, loot and legacy rewards OK")
	quit()


func _session() -> GameSession:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return GameSession.start_for_party(dungeon, ["petushan", "volcha"])


func _test_catalog_and_loot() -> void:
	var ids: Array[String] = ItemCatalog.list_ids()
	var found: Array[String] = []
	for item_id in ids:
		if item_id.begins_with("ring_"):
			found.append(item_id)
	assert(found.size() == RING_IDS.size())
	for item_id in RING_IDS:
		assert(ids.has(item_id))
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		assert(item != null)
		assert(item.category == ItemDefinition.Category.EQUIPMENT)
		assert(item.equipment_slot == ItemDefinition.EquipmentSlot.RING)
		assert(not item.stackable)
		assert(item.icon != null)
		assert(item.icon.get_width() == 64 and item.icon.get_height() == 64)
		assert(EquipmentSlotRules.accepts("ring_left", item))
		assert(EquipmentSlotRules.accepts("ring_right", item))
		assert(not EquipmentSlotRules.accepts("neck", item))
		assert(DescriptionTemplate.unresolved_tokens(item.get_description()).is_empty())
		assert(int(ItemCatalog.LOOT_TABLE.weights.get(item_id, 0)) > 0)
		assert(DungeonMap.CHEST_REWARDS.has(item_id))
	assert(ItemCatalog.get_item("ring_copper_wire").health_bonus == 1)
	assert(ItemCatalog.get_item("ring_brass_notched").accuracy_bonus_percent == 2)
	assert(ItemCatalog.get_item("ring_blacksmith").agility_bonus == -1)
	assert(ItemCatalog.get_item("ring_wooden").perception_bonus == 1)
	var table: WeightedLootTable = WeightedLootTable.new()
	table.weights = {"ring_bone_carved": 1}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 611
	assert(ItemCatalog.roll_loot(rng, table) == {"item_id": "ring_bone_carved", "quantity": 1})
	assert(ItemCatalog.get_item("copper_ring") != null)
	assert(not ids.has("copper_ring"))
	assert(DungeonMap.CHEST_REWARDS.has("copper_ring"))


func _test_two_ring_slots_and_save() -> void:
	var session: GameSession = _session()
	var first: HeroState = session.party[0]
	var second: HeroState = session.party[1]
	assert(session._receive_item("ring_copper_wire", 2) == 2)
	var first_index: int = session.inventory_slot_ids().find("ring_copper_wire")
	assert(first_index >= 0)
	var left_instance: String = session.inventory_instance_id(first_index)
	assert(session.transfer_inventory_item("bag", first_index, "equipment", "ring_left"))
	var second_index: int = session.inventory_slot_ids().find("ring_copper_wire")
	assert(second_index >= 0)
	var right_instance: String = session.inventory_instance_id(second_index)
	assert(right_instance != left_instance)
	assert(session.transfer_inventory_item("bag", second_index, "equipment", "ring_right"))
	assert(session.equipment_instance_id("ring_left", first) == left_instance)
	assert(session.equipment_instance_id("ring_right", first) == right_instance)
	assert(first.effective_max_health() == first.max_health + 2 * ItemCatalog.get_item("ring_copper_wire").health_bonus)
	assert(session.inventory_slot_ids().count("ring_copper_wire") == 0)
	assert(not session.transfer_inventory_item("equipment", "ring_left", "equipment", "gloves"))

	assert(session._receive_item("ring_blacksmith", 1) == 1)
	var blacksmith_index: int = session.inventory_slot_ids().find("ring_blacksmith")
	assert(blacksmith_index >= 0)
	var blacksmith_instance: String = session.inventory_instance_id(blacksmith_index)
	session.item_instance(blacksmith_instance).rarity = ItemInstance.Rarity.MAGIC
	session.item_instance(blacksmith_instance).modifiers["perception"] = 2
	assert(session.transfer_inventory_item("bag", blacksmith_index, "equipment", "ring_right"))
	assert(session.equipment_instance_id("ring_right", first) == blacksmith_instance)
	assert(session.inventory_instance_id(blacksmith_index) == right_instance)
	assert(session.inventory_slot_ids()[blacksmith_index] == "ring_copper_wire")
	assert(first.effective_strength() == first.strength + ItemCatalog.get_item("ring_blacksmith").strength_bonus)
	assert(first.effective_agility() == maxi(0, first.agility + ItemCatalog.get_item("ring_blacksmith").agility_bonus))

	session.inventory_member = second
	var for_second: int = session.inventory_slot_ids().find("ring_copper_wire")
	assert(for_second >= 0)
	assert(session.transfer_inventory_item("bag", for_second, "equipment", "ring_right"))
	assert(session.equipment_instance_id("ring_right", second) == right_instance)
	assert(session._receive_item("ring_bone_carved", 1) == 1)
	var bone_index: int = session.inventory_slot_ids().find("ring_bone_carved")
	assert(bone_index >= 0)
	var bone_instance: String = session.inventory_instance_id(bone_index)
	assert(session.transfer_inventory_item("bag", bone_index, "equipment", "ring_left"))
	assert(session.equipment_instance_id("ring_left", second) == bone_instance)
	assert(session.equipment_instance_id("ring_left", first) == left_instance)
	assert(session.equipment_instance_id("ring_right", first) == blacksmith_instance)
	var fighter: BattleParticipant = BattleParticipant.from_hero(second)
	assert(fighter.accuracy_bonus == second.definition.accuracy_bonus + ItemCatalog.get_item("ring_bone_carved").accuracy_bonus_percent)

	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {session.map_data.map_id: session.map_data})
	assert(restored != null)
	assert(restored.equipment_instance_id("ring_left", restored.party[0]) == left_instance)
	assert(restored.equipment_instance_id("ring_right", restored.party[0]) == blacksmith_instance)
	assert(restored.equipment_instance_id("ring_right", restored.party[1]) == right_instance)
	assert(restored.equipment_instance_id("ring_left", restored.party[1]) == bone_instance)
	assert(restored.item_instance(blacksmith_instance).rarity == ItemInstance.Rarity.MAGIC)
	assert(restored.item_instance(blacksmith_instance).modifiers["perception"] == 2)
	assert(restored.party[0].effective_max_health() == first.effective_max_health())
	restored.inventory_member = restored.party[1]
	var empty_index: int = restored.inventory_slot_ids().find("")
	assert(empty_index >= 0)
	assert(restored.unequip_equipment_slot("ring_left"))
	assert(restored.equipment_instance_id("ring_left", restored.party[1]).is_empty())
	assert(restored.inventory_instance_id(empty_index) == bone_instance)
	assert(restored.equipment_instance_id("ring_right", restored.party[1]) == right_instance)
	assert(restored.equipment_instance_id("ring_left", restored.party[0]) == left_instance)


func _test_editor_and_legacy_rewards() -> void:
	var scene: PackedScene = load("res://scenes/chest_contents_popup.tscn") as PackedScene
	assert(scene != null)
	var popup: ChestContentsPopup = scene.instantiate() as ChestContentsPopup
	root.add_child(popup)
	assert(popup._group_contents.has("Кольца"))
	for item_id in RING_IDS:
		assert(popup._item_checks.has(item_id))
	assert(not popup._item_checks.has("copper_ring"))
	var captured: Dictionary = {}
	popup.contents_changed.connect(func(_entity_id: String, contents: Array[String], _gold: int, _random: bool, _hidden: bool, quantities: Dictionary, _reward_level: int) -> void:
		captured["items"] = contents.duplicate()
		captured["quantities"] = quantities.duplicate()
	)
	var old_contents: Array[String] = ["copper_ring", "ring_copper_wire"]
	popup.configure("legacy_chest", old_contents, 5, false, false, false, {"copper_ring": 2, "ring_copper_wire": 1})
	popup._save()
	assert((captured.get("items", []) as Array).has("copper_ring"))
	assert(int((captured.get("quantities", {}) as Dictionary).get("copper_ring", 0)) == 2)
	popup.queue_free()

extends SceneTree

const GLOVE_IDS: Array[String] = [
	"gloves_cloth_wraps", "gloves_canvas_mittens", "gloves_fingerless_leather",
	"gloves_miner_mittens", "gloves_ranger", "gloves_quilted_mittens",
	"gloves_tanned_leather", "gloves_chainmail_mittens",
	"gloves_studded_combat", "gloves_militia_plate"
]


func _initialize() -> void:
	_test_catalog_and_random_loot()
	_test_equipment_and_save()
	_test_editor_palette_and_legacy_rewards()
	print("DA-6: gloves, loot, equipment and legacy rewards OK")
	quit()


func _session() -> GameSession:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return GameSession.start_for_party(dungeon, ["petushan", "volcha"])


func _test_catalog_and_random_loot() -> void:
	var ids: Array[String] = ItemCatalog.list_ids()
	for item_id in GLOVE_IDS:
		assert(ids.has(item_id))
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		assert(item != null)
		assert(item.category == ItemDefinition.Category.EQUIPMENT)
		assert(item.equipment_slot == ItemDefinition.EquipmentSlot.GLOVES)
		assert(not item.stackable)
		assert(item.icon != null)
		assert(item.icon.get_width() == 64 and item.icon.get_height() == 64)
		assert(EquipmentSlotRules.accepts("gloves", item))
		assert(not EquipmentSlotRules.accepts("boots", item))
		assert(DescriptionTemplate.unresolved_tokens(item.get_description()).is_empty())
		assert(int(ItemCatalog.LOOT_TABLE.weights.get(item_id, 0)) > 0)
		assert(DungeonMap.CHEST_REWARDS.has(item_id))
	var glove_ids: Array[String] = []
	for item_id in ids:
		if item_id.begins_with("gloves_"):
			glove_ids.append(item_id)
	assert(glove_ids.size() == GLOVE_IDS.size())
	assert(ItemCatalog.get_item("gloves_militia_plate").armor_bonus == 2)
	assert(ItemCatalog.get_item("gloves_ranger").perception_bonus == 1)
	assert(ItemCatalog.get_item("gloves_fingerless_leather").accuracy_bonus_percent == 1)
	var table: WeightedLootTable = WeightedLootTable.new()
	table.weights = {"gloves_miner_mittens": 1}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2406
	assert(ItemCatalog.roll_loot(rng, table) == {"item_id": "gloves_miner_mittens", "quantity": 1})
	assert(ItemCatalog.get_item("leather_gloves") != null)
	assert(not ids.has("leather_gloves"))
	assert(DungeonMap.CHEST_REWARDS.has("leather_gloves"))


func _test_equipment_and_save() -> void:
	var session: GameSession = _session()
	var first: HeroState = session.party[0]
	var second: HeroState = session.party[1]
	var light: ItemDefinition = ItemCatalog.get_item("gloves_fingerless_leather")
	var heavy: ItemDefinition = ItemCatalog.get_item("gloves_militia_plate")
	assert(session._receive_item(light.item_id, 1) == 1)
	var light_slot: int = session.inventory_slot_ids().find(light.item_id)
	assert(light_slot >= 0)
	var light_id: String = session.inventory_instance_id(light_slot)
	assert(session.transfer_inventory_item("bag", light_slot, "equipment", "gloves"))
	assert(session.equipment_instance_id("gloves", first) == light_id)
	assert(first.effective_agility() == first.agility + light.agility_bonus)
	assert(not session.transfer_inventory_item("equipment", "gloves", "equipment", "head"))

	assert(session._receive_item(heavy.item_id, 2) == 2)
	var heavy_slot: int = session.inventory_slot_ids().find(heavy.item_id)
	assert(heavy_slot >= 0)
	var first_heavy_id: String = session.inventory_instance_id(heavy_slot)
	assert(session.transfer_inventory_item("bag", heavy_slot, "equipment", "gloves"))
	assert(session.equipment_instance_id("gloves", first) == first_heavy_id)
	assert(session.inventory_instance_id(heavy_slot) == light_id)
	assert(session.inventory_slot_ids()[heavy_slot] == light.item_id)
	assert(first.effective_max_health() == first.max_health + heavy.health_bonus)
	assert(first.effective_strength() == first.strength + heavy.strength_bonus)
	assert(first.effective_agility() == maxi(0, first.agility + heavy.agility_bonus))
	var fighter: BattleParticipant = BattleParticipant.from_hero(first)
	assert(fighter.max_health == first.effective_max_health())
	assert(fighter.strength == first.effective_strength())
	assert(fighter.base_dodge_percent == first.definition.base_dodge_percent + heavy.dodge_bonus_percent)
	assert(fighter.accuracy_bonus == first.definition.accuracy_bonus + heavy.accuracy_bonus_percent)
	session.item_instance(first_heavy_id).rarity = ItemInstance.Rarity.MAGIC
	session.item_instance(first_heavy_id).modifiers["poison_resistance_percent"] = 5

	session.inventory_member = second
	var second_slot: int = session.inventory_slot_ids().find(heavy.item_id)
	assert(second_slot >= 0)
	var second_heavy_id: String = session.inventory_instance_id(second_slot)
	assert(second_heavy_id != first_heavy_id)
	assert(session.transfer_inventory_item("bag", second_slot, "equipment", "gloves"))
	assert(session.equipment_instance_id("gloves", second) == second_heavy_id)
	assert(session.equipment_instance_id("gloves", first) == first_heavy_id)

	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {session.map_data.map_id: session.map_data})
	assert(restored != null)
	assert(restored.equipment_instance_id("gloves", restored.party[0]) == first_heavy_id)
	assert(restored.equipment_instance_id("gloves", restored.party[1]) == second_heavy_id)
	assert(restored.item_instance(first_heavy_id).rarity == ItemInstance.Rarity.MAGIC)
	assert(restored.item_instance(first_heavy_id).modifiers["poison_resistance_percent"] == 5)
	assert(restored.party[0].effective_max_health() == first.effective_max_health())
	restored.inventory_member = restored.party[0]
	var empty_slot: int = restored.inventory_slot_ids().find("")
	assert(empty_slot >= 0)
	assert(restored.unequip_equipment_slot("gloves"))
	assert(restored.equipment_instance_id("gloves", restored.party[0]).is_empty())
	assert(restored.inventory_instance_id(empty_slot) == first_heavy_id)
	assert(restored.equipment_instance_id("gloves", restored.party[1]) == second_heavy_id)


func _test_editor_palette_and_legacy_rewards() -> void:
	var scene: PackedScene = load("res://scenes/chest_contents_popup.tscn") as PackedScene
	assert(scene != null)
	var popup: ChestContentsPopup = scene.instantiate() as ChestContentsPopup
	root.add_child(popup)
	assert(popup._group_contents.has("Перчатки"))
	assert(not popup._group_contents.has("Снаряжение"))
	for item_id in GLOVE_IDS:
		assert(popup._item_checks.has(item_id))
	assert(not popup._item_checks.has("leather_gloves"))
	var captured: Dictionary = {}
	popup.contents_changed.connect(func(_entity_id: String, contents: Array[String], _gold: int, _random: bool, _hidden: bool, quantities: Dictionary) -> void:
		captured["items"] = contents.duplicate()
		captured["quantities"] = quantities.duplicate()
	)
	var old_contents: Array[String] = ["leather_gloves", "gloves_canvas_mittens"]
	popup.configure("legacy_chest", old_contents, 5, false, false, false, {"leather_gloves": 2, "gloves_canvas_mittens": 1})
	popup._save()
	assert((captured.get("items", []) as Array).has("leather_gloves"))
	assert(int((captured.get("quantities", {}) as Dictionary).get("leather_gloves", 0)) == 2)
	popup.queue_free()

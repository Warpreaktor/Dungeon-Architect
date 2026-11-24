extends SceneTree

const ARMOR_IDS: Array[String] = [
	"armor_canvas_jacket", "armor_wool_doublet", "armor_quilted_gambeson",
	"armor_leather_vest", "armor_ranger_jacket", "armor_reinforced_leather",
	"armor_chain_shirt", "armor_lamellar_cuirass",
	"armor_militia_brigandine", "armor_iron_cuirass"
]


func _initialize() -> void:
	_test_catalog_and_random_loot()
	_test_equipment_and_save()
	_test_editor_palette_and_legacy_rewards()
	print("DA-6: chest armor, loot, equipment and legacy rewards OK")
	quit()


func _session() -> GameSession:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return GameSession.start_for_party(dungeon, ["petushan", "volcha"])


func _test_catalog_and_random_loot() -> void:
	var ids: Array[String] = ItemCatalog.list_ids()
	for item_id in ARMOR_IDS:
		assert(ids.has(item_id))
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		assert(item != null)
		assert(item.category == ItemDefinition.Category.EQUIPMENT)
		assert(item.equipment_slot == ItemDefinition.EquipmentSlot.BODY)
		assert(not item.stackable)
		assert(item.icon != null)
		assert(item.icon.get_width() == 64 and item.icon.get_height() == 64)
		assert(EquipmentSlotRules.accepts("body", item))
		assert(not EquipmentSlotRules.accepts("head", item))
		assert(DescriptionTemplate.unresolved_tokens(item.get_description()).is_empty())
		assert(int(ItemCatalog.LOOT_TABLE.weights.get(item_id, 0)) > 0)
		assert(DungeonMap.CHEST_REWARDS.has(item_id))
	var armor_ids: Array[String] = []
	for item_id in ids:
		if item_id.begins_with("armor_"):
			armor_ids.append(item_id)
	assert(armor_ids.size() == ARMOR_IDS.size())
	var table: WeightedLootTable = WeightedLootTable.new()
	table.weights = {"armor_chain_shirt": 1}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1214
	assert(ItemCatalog.roll_loot(rng, table) == {"item_id": "armor_chain_shirt", "quantity": 1})
	assert(ItemCatalog.get_item("leather_armor") != null)
	assert(not ids.has("leather_armor"))
	assert(DungeonMap.CHEST_REWARDS.has("leather_armor"))


func _test_equipment_and_save() -> void:
	var session: GameSession = _session()
	var first: HeroState = session.party[0]
	var second: HeroState = session.party[1]
	var chain: ItemDefinition = ItemCatalog.get_item("armor_chain_shirt")
	var cuirass: ItemDefinition = ItemCatalog.get_item("armor_iron_cuirass")
	assert(session._receive_item(chain.item_id, 1) == 1)
	var chain_slot: int = session.inventory_slot_ids().find(chain.item_id)
	assert(chain_slot >= 0)
	var chain_id: String = session.inventory_instance_id(chain_slot)
	assert(session.transfer_inventory_item("bag", chain_slot, "equipment", "body"))
	assert(session.equipment_instance_id("body", first) == chain_id)
	assert(first.effective_max_health() == first.max_health + chain.health_bonus)
	assert(first.effective_agility() == maxi(first.agility + chain.agility_bonus, 0))
	assert(not session.transfer_inventory_item("equipment", "body", "equipment", "head"))

	assert(session._receive_item(cuirass.item_id, 2) == 2)
	var cuirass_slot: int = session.inventory_slot_ids().find(cuirass.item_id)
	var first_cuirass_id: String = session.inventory_instance_id(cuirass_slot)
	assert(session.transfer_inventory_item("bag", cuirass_slot, "equipment", "body"))
	assert(session.equipment_instance_id("body", first) == first_cuirass_id)
	session.item_instance(first_cuirass_id).rarity = ItemInstance.Rarity.MAGIC
	session.item_instance(first_cuirass_id).modifiers["perception"] = 1
	assert(session.inventory_instance_id(cuirass_slot) == chain_id)
	assert(session.inventory_slot_ids()[cuirass_slot] == chain.item_id)
	var fighter: BattleParticipant = BattleParticipant.from_hero(first)
	assert(fighter.max_health == first.effective_max_health())
	assert(fighter.agility == first.effective_agility())
	assert(fighter.base_dodge_percent == first.definition.base_dodge_percent + cuirass.dodge_bonus_percent)
	assert(fighter.accuracy_bonus == first.definition.accuracy_bonus + cuirass.accuracy_bonus_percent)
	assert(first.defense == 0)

	session.inventory_member = second
	var second_slot: int = session.inventory_slot_ids().find(cuirass.item_id)
	var second_cuirass_id: String = session.inventory_instance_id(second_slot)
	assert(second_cuirass_id != first_cuirass_id)
	assert(session.transfer_inventory_item("bag", second_slot, "equipment", "body"))
	assert(session.equipment_instance_id("body", second) == second_cuirass_id)
	assert(session.equipment_instance_id("body", first) == first_cuirass_id)

	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {session.map_data.map_id: session.map_data})
	assert(restored != null)
	assert(restored.equipment_instance_id("body", restored.party[0]) == first_cuirass_id)
	assert(restored.item_instance(first_cuirass_id).rarity == ItemInstance.Rarity.MAGIC)
	assert(restored.item_instance(first_cuirass_id).modifiers["perception"] == 1)
	assert(restored.equipment_instance_id("body", restored.party[1]) == second_cuirass_id)
	assert(restored.party[0].effective_max_health() == first.effective_max_health())
	restored.inventory_member = restored.party[0]
	var empty_slot: int = restored.inventory_slot_ids().find("")
	assert(empty_slot >= 0)
	assert(restored.unequip_equipment_slot("body"))
	assert(restored.equipment_instance_id("body", restored.party[0]).is_empty())
	assert(restored.inventory_instance_id(empty_slot) == first_cuirass_id)
	assert(restored.equipment_instance_id("body", restored.party[1]) == second_cuirass_id)


func _test_editor_palette_and_legacy_rewards() -> void:
	var scene: PackedScene = load("res://scenes/chest_contents_popup.tscn") as PackedScene
	assert(scene != null)
	var popup: ChestContentsPopup = scene.instantiate() as ChestContentsPopup
	root.add_child(popup)
	assert(popup._group_contents.has("Броня"))
	assert(popup._group_contents.has("Снаряжение"))
	for item_id in ARMOR_IDS:
		assert(popup._item_checks.has(item_id))
	assert(not popup._item_checks.has("leather_armor"))
	var captured: Dictionary = {}
	popup.contents_changed.connect(func(_entity_id: String, contents: Array[String], _gold: int, _random: bool, _hidden: bool, quantities: Dictionary) -> void:
		captured["items"] = contents.duplicate()
		captured["quantities"] = quantities.duplicate()
	)
	var old_contents: Array[String] = ["leather_armor", "armor_canvas_jacket"]
	popup.configure("legacy_chest", old_contents, 5, false, false, false, {"leather_armor": 2, "armor_canvas_jacket": 1})
	popup._save()
	assert((captured.get("items", []) as Array).has("leather_armor"))
	assert(int((captured.get("quantities", {}) as Dictionary).get("leather_armor", 0)) == 2)
	popup.queue_free()

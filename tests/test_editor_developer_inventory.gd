extends SceneTree


func _initialize() -> void:
	_test_runtime_gate()
	_test_instance_properties_and_snapshot()
	_test_item_constraints()
	print("Editor developer inventory: access, item instances and snapshot OK")
	quit()


func _test_runtime_gate() -> void:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	var session: GameSession = GameSession.start_for_party(dungeon, ["volcha", "burolom"])
	assert(session != null)
	assert(session.developer_add_item("sword") == {})
	assert(not session.developer_remove_bag_slot(0))
	if not OS.has_feature("editor"):
		assert(not DeveloperMode.is_available())
		assert(not DeveloperMode.is_enabled())
		assert(not DeveloperMode.set_enabled(true))
		session.is_editor_test = true
		assert(session.developer_add_item("sword") == {})


func _test_instance_properties_and_snapshot() -> void:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	var session: GameSession = GameSession.start_for_party(dungeon, ["volcha", "burolom"])
	assert(session._receive_item("armor_chain_shirt", 1) == 1)
	var slot: int = session.inventory_slot_ids().find("armor_chain_shirt")
	assert(slot >= 0)
	var instance: ItemInstance = session.item_instance(session.inventory_instance_id(slot))
	assert(instance != null)
	instance.quality_id = "masterwork"
	instance.rarity = ItemInstance.Rarity.MAGIC
	instance.affix_ids = ["warding"]
	instance.modifiers = {"armor_bonus": 2}
	assert(ItemInstance.from_dict(instance.to_dict()) != null)
	var before: Dictionary = instance.to_dict()
	var snapshot: Dictionary = session.party_state_snapshot()
	var restored: GameSession = GameSession.start_for_party(dungeon, ["volcha", "burolom"])
	assert(restored.restore_party_state(snapshot))
	var restored_slot: int = restored.inventory_slot_ids().find("armor_chain_shirt")
	var restored_instance: ItemInstance = restored.item_instance(restored.inventory_instance_id(restored_slot))
	assert(restored_instance != null)
	assert(restored_instance.to_dict() == before)
	assert(restored.party.size() == 2)


func _test_item_constraints() -> void:
	var rules: ItemMagicRules = ItemMagicCatalog.RULES
	var sword: ItemDefinition = ItemCatalog.get_item("sword")
	var shield: ItemDefinition = ItemCatalog.get_item("shield")
	assert(rules != null and sword != null and shield != null)
	assert(ItemMagicCatalog.affix("edge").accepts(sword))
	assert(not ItemMagicCatalog.affix("edge").accepts(shield))
	assert(ItemMagicCatalog.affix("guard").accepts(shield))
	assert(not ItemMagicCatalog.affix("guard").accepts(sword))
	var snapshot: Dictionary = ItemInstance.create("item_77", sword).to_dict()
	snapshot["rarity"] = ItemInstance.Rarity.MAGIC
	snapshot["affix_ids"] = ["guard"]
	snapshot["modifiers"] = {"defense_bonus": 1}
	assert(ItemInstance.from_dict(snapshot) == null)

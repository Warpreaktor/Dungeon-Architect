extends SceneTree


const SLOT_ITEMS: Dictionary = {
	"head": "leather_cap",
	"neck": "plain_amulet",
	"body": "leather_armor",
	"main_hand": "sword",
	"off_hand": "shield",
	"ring_left": "copper_ring",
	"ring_right": "copper_ring",
	"belt": "cloth_belt",
	"gloves": "leather_gloves",
	"boots": "leather_boots"
}


func _initialize() -> void:
	_test_all_slots_and_instances()
	_test_party_ownership_and_restore()
	_test_two_handed_and_full_bag()
	print("DA-6.03: equipment slots and identities OK")
	quit()


func _session() -> GameSession:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return GameSession.start_for_party(dungeon, ["petushan", "volcha"])


func _assert_integrity(session: GameSession) -> void:
	var ids: Dictionary = {}
	var bag: Array[String] = session.inventory_slot_ids()
	for index in range(bag.size()):
		var item_id: String = bag[index]
		var definition: ItemDefinition = ItemCatalog.get_item(item_id)
		var instance_id: String = session.inventory_instance_id(index)
		if definition == null or definition.category != ItemDefinition.Category.EQUIPMENT:
			assert(instance_id.is_empty())
			continue
		assert(not instance_id.is_empty())
		assert(not ids.has(instance_id))
		ids[instance_id] = true
		assert(session.item_instance(instance_id).item_id == item_id)
	for member in session.party:
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			var item_id: String = session._member_equipment_id(member, slot_id)
			var instance_id: String = session.equipment_instance_id(slot_id, member)
			assert(item_id.is_empty() == instance_id.is_empty())
			if item_id.is_empty():
				continue
			assert(EquipmentSlotRules.accepts(slot_id, ItemCatalog.get_item(item_id)))
			assert(not ids.has(instance_id))
			ids[instance_id] = true
			assert(session.item_instance(instance_id).item_id == item_id)
	assert(ids.size() == session._item_instances.size())
	for item_id in session.carried_items:
		var definition: ItemDefinition = ItemCatalog.get_item(str(item_id))
		if definition == null or definition.category != ItemDefinition.Category.EQUIPMENT:
			continue
		var count: int = bag.count(str(item_id))
		for member in session.party:
			count += session._equipment_snapshot(member).values().count(item_id)
		assert(count == int(session.carried_items[item_id]))


func _test_all_slots_and_instances() -> void:
	var session: GameSession = _session()
	assert(EquipmentSlotRules.SLOT_IDS.size() == SLOT_ITEMS.size())
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		var item_id: String = SLOT_ITEMS[slot_id]
		var definition: ItemDefinition = ItemCatalog.get_item(item_id)
		assert(definition != null and not definition.stackable)
		assert(EquipmentSlotRules.accepts(slot_id, definition))
		assert(session._receive_item(item_id, 1) == 1)
		if session.equipment_item_id(slot_id).is_empty():
			var index: int = session.inventory_slot_ids().find(item_id)
			assert(index >= 0)
			var before_id: String = session.inventory_instance_id(index)
			assert(session.transfer_inventory_item("bag", index, "equipment", slot_id))
			assert(session.equipment_instance_id(slot_id) == before_id)
		assert(session.equipment_item_id(slot_id) == item_id)
	_assert_integrity(session)
	assert(session.inventory_slot_ids().count("copper_ring") == 0)
	assert(session._receive_item("copper_ring", 1) == 1)
	var third_slot: int = session.inventory_slot_ids().find("copper_ring")
	var new_ring_id: String = session.inventory_instance_id(third_slot)
	var old_ring_id: String = session.equipment_instance_id("ring_left")
	session.item_instance(new_ring_id).rarity = ItemInstance.Rarity.MAGIC
	session.item_instance(new_ring_id).modifiers["agility"] = 2
	assert(session.equip_item("copper_ring"))
	assert(session.equipment_instance_id("ring_left") == new_ring_id)
	assert(session.inventory_instance_id(third_slot) == old_ring_id)
	assert(session.item_instance(new_ring_id).modifiers["agility"] == 2)
	assert(not session.transfer_inventory_item("equipment", "ring_left", "equipment", "neck"))
	var empty: int = session.inventory_slot_ids().find("")
	assert(session.unequip_equipment_slot("ring_right"))
	assert(session.equipment_item_id("ring_right").is_empty())
	assert(session.inventory_slot_ids()[empty] == "copper_ring")
	assert(session.transfer_inventory_item("bag", empty, "equipment", "ring_right"))
	_assert_integrity(session)


func _test_party_ownership_and_restore() -> void:
	var session: GameSession = _session()
	var first: HeroState = session.party[0]
	var second: HeroState = session.party[1]
	assert(session._receive_item("leather_cap", 2) == 2)
	var first_slot: int = session.inventory_slot_ids().find("leather_cap")
	var first_id: String = session.inventory_instance_id(first_slot)
	assert(session.transfer_inventory_item("bag", first_slot, "equipment", "head"))
	session.inventory_member = second
	var second_slot: int = session.inventory_slot_ids().find("leather_cap")
	var second_id: String = session.inventory_instance_id(second_slot)
	assert(first_id != second_id)
	assert(session.transfer_inventory_item("bag", second_slot, "equipment", "head"))
	assert(session.equipment_instance_id("head", first) == first_id)
	assert(session.equipment_instance_id("head", second) == second_id)
	assert(session.inventory_slot_ids().count("leather_cap") == 0)
	assert(session._receive_item("cloth_belt", 1) == 1)
	var belt_slot: int = session.inventory_slot_ids().find("cloth_belt")
	assert(session.transfer_inventory_item("bag", belt_slot, "equipment", "belt"))
	assert(session._member_equipment_id(first, "belt").is_empty())
	assert(session._member_equipment_id(second, "belt") == "cloth_belt")
	_assert_integrity(session)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {session.map_data.map_id: session.map_data})
	assert(restored != null)
	assert(restored.equipment_instance_id("head", restored.party[0]) == first_id)
	assert(restored.equipment_instance_id("head", restored.party[1]) == second_id)
	assert(restored._member_equipment_id(restored.party[1], "belt") == "cloth_belt")
	_assert_integrity(restored)


func _test_two_handed_and_full_bag() -> void:
	var session: GameSession = _session()
	assert(session._receive_item("shield", 1, [4]) == 1)
	var shield_id: String = session.equipment_instance_id("off_hand")
	assert(session._receive_item("warhammer", 1) == 1)
	var hammer_slot: int = session.inventory_slot_ids().find("warhammer")
	assert(session.transfer_inventory_item("bag", hammer_slot, "equipment", "main_hand"))
	assert(session.equipment_item_id("main_hand") == "warhammer")
	assert(session.equipment_item_id("off_hand").is_empty())
	var shield_slot: int = session.inventory_slot_ids().find("shield")
	assert(shield_slot >= 0 and session.inventory_instance_id(shield_slot) == shield_id)
	assert(session.item_instance(shield_id).durability == 4)
	assert(not session.transfer_inventory_item("bag", shield_slot, "equipment", "off_hand"))
	_assert_integrity(session)

	var full: GameSession = _session()
	assert(full._receive_item("shield", 1) == 1)
	assert(full._receive_item("sword", 40) == 40)
	assert(full._receive_item("warhammer", 1) == 1)
	assert(full.inventory_slot_ids().find("") == -1)
	var before: Dictionary = JSON.parse_string(JSON.stringify(full.party_state_snapshot()))
	var index: int = full.inventory_slot_ids().find("warhammer")
	assert(not full.transfer_inventory_item("bag", index, "equipment", "main_hand"))
	assert(full.party_state_snapshot() == before)
	assert(not full.unequip_equipment_slot("off_hand"))
	assert(full.party_state_snapshot() == before)
	_assert_integrity(full)

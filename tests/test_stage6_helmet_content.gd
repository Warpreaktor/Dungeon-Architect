extends SceneTree


func _initialize() -> void:
	_test_helmets_and_drops()
	_test_equipment_and_persistence()
	_test_precision_and_substitution()
	_test_editor_reward_palette()
	print("DA-6: helmets, loot tables, inventory and party persistence OK")
	quit()


func _test_helmets_and_drops() -> void:
	var helmet_ids: Array[String] = []
	for item_id in ItemCatalog.list_ids():
		if not item_id.begins_with("helmet_"):
			continue
		helmet_ids.append(item_id)
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		assert(item != null)
		assert(item.category == ItemDefinition.Category.EQUIPMENT)
		assert(item.equipment_slot == ItemDefinition.EquipmentSlot.HEAD)
		assert(not item.stackable)
		assert(item.icon != null)
		assert(item.icon.get_width() == 64)
		assert(item.icon.get_height() == 64)
		assert(not item.display_name.is_empty())
		assert(DescriptionTemplate.unresolved_tokens(item.get_description()).is_empty())
		assert(int(ItemCatalog.LOOT_TABLE.weights.get(item_id, 0)) > 0)
		assert(DungeonMap.CHEST_REWARDS.has(item_id))
	assert(helmet_ids.size() == 20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 451
	var table := WeightedLootTable.new()
	table.weights = {"helmet_miner": 1}
	assert(ItemCatalog.roll_loot(rng, table) == {"item_id": "helmet_miner", "quantity": 1})


func _session() -> GameSession:
	var map_data: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(map_data.place_entity("player_spawn", 2, 2))
	return GameSession.start_for_party(map_data, ["petushan", "volcha"])


func _test_equipment_and_persistence() -> void:
	var session: GameSession = _session()
	var first: HeroState = session.party[0]
	var second: HeroState = session.party[1]
	var helmet: ItemDefinition = ItemCatalog.get_item("helmet_berserker")
	assert(helmet != null)
	assert(session._receive_item(helmet.item_id, 2) == 2)
	var index: int = session.inventory_slot_ids().find(helmet.item_id)
	assert(index >= 0)
	var instance_id: String = session.inventory_instance_id(index)
	assert(session.transfer_inventory_item("bag", index, "equipment", "head"))
	assert(session.equipment_instance_id("head", first) == instance_id)
	assert(first.effective_strength() == first.strength + helmet.strength_bonus)
	assert(first.effective_max_health() == first.max_health + helmet.health_bonus)
	var fighter: BattleParticipant = BattleParticipant.from_hero(first)
	assert(fighter.strength == first.effective_strength())
	assert(fighter.max_health == first.effective_max_health())
	assert(fighter.dodge_percent() == maxi(first.definition.base_dodge_percent + first.effective_agility() + helmet.dodge_bonus_percent, 0))
	assert(second.effective_strength() == second.strength)
	assert(second.effective_max_health() == second.max_health)

	session.inventory_member = second
	index = session.inventory_slot_ids().find(helmet.item_id)
	var second_id: String = session.inventory_instance_id(index)
	assert(second_id != instance_id)
	assert(session.transfer_inventory_item("bag", index, "equipment", "head"))
	assert(session.equipment_instance_id("head", second) == second_id)
	assert(session.equipment_instance_id("head", first) == instance_id)
	assert(second.effective_strength() == second.strength + helmet.strength_bonus)

	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {session.map_data.map_id: session.map_data})
	assert(restored != null)
	assert(restored.equipment_instance_id("head", restored.party[0]) == instance_id)
	assert(restored.equipment_instance_id("head", restored.party[1]) == second_id)
	assert(restored.party[0].effective_strength() == first.effective_strength())
	assert(restored.party[1].effective_max_health() == second.effective_max_health())

	var boosted_health: int = restored.party[0].effective_max_health()
	restored.party[0].health = boosted_health
	assert(HeroState.from_snapshot(restored.party[0].to_snapshot()) != null)
	restored.inventory_member = restored.party[0]
	var free_index: int = restored.inventory_slot_ids().find("")
	assert(free_index >= 0)
	assert(restored.transfer_inventory_item("equipment", "head", "bag", free_index))
	assert(restored.party[0].health == restored.party[0].effective_max_health())
	assert(restored.party[0].health < boosted_health)
	assert(restored.inventory_instance_id(free_index) == instance_id)


func _test_editor_reward_palette() -> void:
	var scene: PackedScene = load("res://scenes/chest_contents_popup.tscn") as PackedScene
	assert(scene != null)
	var popup: ChestContentsPopup = scene.instantiate() as ChestContentsPopup
	root.add_child(popup)
	assert(popup._group_contents.has("Шлемы"))
	assert(popup._item_checks.has("helmet_berserker"))
	assert(popup._item_checks.has("helmet_miner"))
	assert(not popup._group_contents.has("Снаряжение"))
	popup.queue_free()


func _test_precision_and_substitution() -> void:
	var session: GameSession = _session()
	var hero: HeroState = session.party[0]
	var agile_helmet: ItemDefinition = ItemCatalog.get_item("helmet_shadow_hunter")
	var heavy_helmet: ItemDefinition = ItemCatalog.get_item("helmet_closed_knight")
	assert(session._receive_item(agile_helmet.item_id, 1) == 1)
	var first_slot: int = session.inventory_slot_ids().find(agile_helmet.item_id)
	var agile_id: String = session.inventory_instance_id(first_slot)
	assert(session.transfer_inventory_item("bag", first_slot, "equipment", "head"))
	var agile_fighter: BattleParticipant = BattleParticipant.from_hero(hero)
	assert(agile_fighter.agility == hero.agility + agile_helmet.agility_bonus)
	assert(agile_fighter.base_dodge_percent == hero.definition.base_dodge_percent + agile_helmet.dodge_bonus_percent)
	assert(agile_fighter.accuracy_bonus == hero.definition.accuracy_bonus + agile_helmet.accuracy_bonus_percent)
	assert(session._receive_item(heavy_helmet.item_id, 1) == 1)
	var second_slot: int = session.inventory_slot_ids().find(heavy_helmet.item_id)
	assert(session.transfer_inventory_item("bag", second_slot, "equipment", "head"))
	var heavy_fighter: BattleParticipant = BattleParticipant.from_hero(hero)
	assert(heavy_fighter.agility == hero.effective_agility())
	assert(heavy_fighter.accuracy_bonus == hero.definition.accuracy_bonus + heavy_helmet.accuracy_bonus_percent)
	assert(session.inventory_instance_id(second_slot) == agile_id)
	assert(session.inventory_slot_ids()[second_slot] == agile_helmet.item_id)
	assert(hero.effective_max_health() == hero.max_health + heavy_helmet.health_bonus)
	assert(ItemCatalog.get_item("helmet_plague_alchemist").poison_resistance_percent > 0)
	var changed: ItemDefinition = heavy_helmet.duplicate() as ItemDefinition
	changed.health_bonus += 7
	assert(changed.get_description().contains(str(changed.health_bonus)))

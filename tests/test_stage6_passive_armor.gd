extends SceneTree

const SLOT_ITEMS: Dictionary = {
	"head": "helmet_iron_shishak",
	"body": "armor_iron_cuirass",
	"gloves": "gloves_chainmail_mittens",
	"boots": "boots_chainmail",
	"belt": "belt_wide_leather",
	"neck": "amulet_iron_tag",
	"ring_left": "ring_copper_wire",
	"ring_right": "ring_blacksmith"
}


func _initialize() -> void:
	_test_data_driven_stats_and_slots()
	_test_passive_armor_and_block()
	print("DA-6.04: equipment stats, passive armor and shield blocking OK")
	quit()


func _session() -> GameSession:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return GameSession.start_for_party(dungeon, ["petushan", "volcha"])


func _test_data_driven_stats_and_slots() -> void:
	var session: GameSession = _session()
	var first: HeroState = session.party[0]
	var second: HeroState = session.party[1]
	var total_armor: int = first.base_defense
	var total_health: int = first.max_health
	var total_strength: int = first.strength
	var total_agility: int = first.agility
	var total_perception: int = first.perception
	var total_dodge: int = first.definition.base_dodge_percent
	var total_accuracy: int = first.definition.accuracy_bonus
	for slot_id in SLOT_ITEMS:
		var item_id: String = str(SLOT_ITEMS[slot_id])
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		assert(item != null and EquipmentSlotRules.accepts(slot_id, item))
		assert(session._receive_item(item_id, 1) == 1)
		var index: int = session.inventory_slot_ids().find(item_id)
		assert(index >= 0)
		assert(session.transfer_inventory_item("bag", index, "equipment", slot_id))
		total_armor += item.armor_bonus
		total_health += item.health_bonus
		total_strength += item.strength_bonus
		total_agility += item.agility_bonus
		total_perception += item.perception_bonus
		total_dodge += item.dodge_bonus_percent
		total_accuracy += item.accuracy_bonus_percent
	assert(first.defense == total_armor)
	assert(first.effective_max_health() == total_health)
	assert(first.effective_strength() == maxi(total_strength, 0))
	assert(first.effective_agility() == maxi(total_agility, 0))
	assert(first.effective_perception() == maxi(total_perception, 0))
	assert(second.defense == second.base_defense)
	var fighter: BattleParticipant = BattleParticipant.from_hero(first)
	assert(fighter.defense == total_armor)
	assert(fighter.max_health == total_health)
	assert(fighter.strength == maxi(total_strength, 0))
	assert(fighter.agility == maxi(total_agility, 0))
	assert(fighter.base_dodge_percent == total_dodge)
	assert(fighter.accuracy_bonus == total_accuracy)

	var original_body_id: String = session.equipment_instance_id("body", first)
	assert(session._receive_item("armor_canvas_jacket", 1) == 1)
	var replacement_slot: int = session.inventory_slot_ids().find("armor_canvas_jacket")
	assert(replacement_slot >= 0)
	assert(session.transfer_inventory_item("bag", replacement_slot, "equipment", "body"))
	assert(session.inventory_instance_id(replacement_slot) == original_body_id)
	var body_diff: int = ItemCatalog.get_item("armor_iron_cuirass").armor_bonus - ItemCatalog.get_item("armor_canvas_jacket").armor_bonus
	assert(first.defense == total_armor - body_diff)
	assert(BattleParticipant.from_hero(first).defense == first.defense)
	assert(session.unequip_equipment_slot("head"))
	assert(first.defense == total_armor - body_diff - ItemCatalog.get_item("helmet_iron_shishak").armor_bonus)
	assert(second.defense == second.base_defense)

	assert(session._receive_item("helmet_plague_alchemist", 1) == 1)
	var helmet_slot: int = session.inventory_slot_ids().find("helmet_plague_alchemist")
	assert(helmet_slot >= 0)
	assert(session.transfer_inventory_item("bag", helmet_slot, "equipment", "head"))
	assert(first.effective_poison_resistance_percent() == ItemCatalog.get_item("helmet_plague_alchemist").poison_resistance_percent)
	assert(first.effective_perception() == maxi(total_perception + ItemCatalog.get_item("helmet_plague_alchemist").perception_bonus, 0))

	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {session.map_data.map_id: session.map_data})
	assert(restored != null)
	assert(restored.party[0].defense == first.defense)
	assert(restored.party[1].defense == second.defense)
	assert(restored.party[0].effective_max_health() == first.effective_max_health())


func _test_passive_armor_and_block() -> void:
	var hero: HeroState = HeroState.new(HeroCatalog.get_hero("petushan"))
	var shirt: ItemDefinition = ItemCatalog.get_item("armor_chain_shirt")
	hero.equipped_accessories["body"] = shirt.item_id
	hero._recalculate_equipment_stats()
	assert(hero.defense == hero.base_defense + shirt.armor_bonus)
	assert(hero.take_damage(10) == 10 - hero.defense)

	var fighter: BattleParticipant = BattleParticipant.from_hero(hero)
	assert(fighter.receive_damage(10) == 10 - hero.defense)
	assert(fighter.last_shield_blocked == 0)
	assert(fighter.receive_damage(10, 0.5) == 5 + maxi(5 - hero.defense, 0))

	var shield: ItemDefinition = ItemCatalog.get_item("shield")
	hero.register_shield(shield)
	assert(hero.equip_item(shield))
	assert(hero.defense == hero.base_defense + shirt.armor_bonus)
	fighter = BattleParticipant.from_hero(hero)
	var initial_durability: int = fighter.shield_durability(shield.item_id)
	assert(fighter.receive_damage(10) == 10 - hero.defense)
	assert(fighter.shield_durability(shield.item_id) == initial_durability)
	fighter.prepare_block(2)
	var hit: int = fighter.receive_damage(4)
	var remaining: int = 4 - hero.defense
	assert(hit == remaining - mini(remaining, shield.defense_bonus))
	assert(fighter.last_shield_blocked == mini(remaining, shield.defense_bonus))
	assert(fighter.shield_durability(shield.item_id) == initial_durability - remaining)
	assert(fighter.block_armor == 0)
	assert(fighter.receive_damage(10) == 10 - hero.defense)

	var monster: MonsterDefinition = MonsterDefinition.new()
	monster.monster_id = "test_armored_monster"
	monster.max_health = 100
	monster.defense = 3
	var enemy: BattleParticipant = BattleParticipant.from_monster(monster)
	enemy.defense = monster.defense
	assert(enemy.defense == 3)
	assert(enemy.receive_damage(8) == 5)

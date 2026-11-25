extends SceneTree


func _initialize() -> void:
	_test_item_resource_drives_stats_and_text()
	_test_temporary_stats_once()
	_test_comparison_and_inventory()
	_test_shield_is_not_passive_armor()
	print("DA-6.05: unified equipment, temporary effects, preview and description OK")
	quit()


func _test_item_resource_drives_stats_and_text() -> void:
	var body: ItemDefinition = ItemCatalog.get_item("armor_iron_cuirass")
	assert(body != null)
	var original: int = body.armor_bonus
	var hero: HeroState = HeroState.new(HeroCatalog.get_hero("petushan"))
	hero.equipped_accessories["body"] = body.item_id
	hero._recalculate_equipment_stats()
	body.armor_bonus = original + 2
	var expected: int = hero.base_defense + original + 2
	var model: Dictionary = CharacterStats.hero_values(hero)
	assert(int(model["defense"]) == expected)
	assert(body.get_description().contains("Броня: +%d" % (original + 2)))
	var actor: BattleParticipant = BattleParticipant.from_hero(hero)
	assert(actor.effective_defense() == expected)
	assert(actor.receive_damage(16) == 16 - BattleMath.passive_armor_absorption(16, expected))
	body.armor_bonus = original
	assert(int(CharacterStats.hero_values(hero)["defense"]) == hero.base_defense + original)


func _test_temporary_stats_once() -> void:
	var hero: HeroState = HeroState.new(HeroCatalog.get_hero("burolom"))
	var ring: ItemDefinition = ItemCatalog.get_item("ring_copper_wire")
	hero.equipped_accessories["ring_left"] = ring.item_id
	hero.equipped_accessories["ring_right"] = ring.item_id
	assert(hero.equipment_bonus("health_bonus") == 2 * ring.health_bonus)
	var effect: AbilityEffectDefinition = AbilityEffectDefinition.new()
	effect.kind = AbilityEffectDefinition.Kind.APPLY_STATUS
	effect.status_id = "da605_test_agility"
	effect.status_stat = AbilityEffectDefinition.Stat.AGILITY
	effect.status_modifier = 2
	effect.duration_ticks = 3
	BattleStatusRules.apply(hero.overworld_statuses, effect, 1, false)
	hero.strength_bonus = 3
	hero.strength_phases = 2
	for amount in [hero.definition.max_energy, 0, -2]:
		hero.energy = amount
		var model: Dictionary = CharacterStats.hero_values(hero)
		var actor: BattleParticipant = BattleParticipant.from_hero(hero)
		assert(actor.effective_strength() == int(model["strength"]))
		assert(actor.effective_agility() == int(model["agility"]))
		assert(actor.effective_defense() == int(model["defense"]))
		assert(actor.dodge_percent() == int(model["dodge_percent"]))
		assert(BattleParticipant.PERCENT_SCALE + actor.accuracy_percent() == int(model["accuracy_percent"]))
		assert(actor.max_health == int(model["max_health"]))
		assert(is_equal_approx(actor.melee_attack_value(), float(model["melee_power"])))
		assert(hero.effective_agility() == int(model["agility"]))
		assert(hero.effective_strength() == int(model["strength"]))
		assert(hero.melee_attack() == int(model["melee_attack"]))
		assert(model["accuracy_percent"] == BattleMath.accuracy_total(int(model["agility"]), actor.accuracy_bonus, 0))


func _test_comparison_and_inventory() -> void:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	var session: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha"])
	var hero: HeroState = session.party[0]
	var item: ItemDefinition = ItemCatalog.get_item("armor_chain_shirt")
	assert(session._receive_item(item.item_id, 1) == 1)
	var before: Dictionary = CharacterStats.hero_values(hero)
	var after: Dictionary = CharacterStats.preview_equipment(hero, "body", item)
	assert(int(after["defense"]) == int(before["defense"]) + item.armor_bonus)
	assert(hero.equipped_accessories.is_empty())
	var lines: PackedStringArray = DescriptionTemplate.comparison(before, after)
	assert("Броня: +%d" % item.armor_bonus in lines)
	var scene: PackedScene = load("res://scenes/inventory_view.tscn") as PackedScene
	assert(scene != null)
	var view: InventoryView = scene.instantiate() as InventoryView
	root.add_child(view)
	view.open_for(session)
	var index: int = session.inventory_slot_ids().find(item.item_id)
	assert(index >= 0)
	view._show_item(index)
	assert(view._item_comparison.text.contains("После замены"))
	assert(view._item_comparison.text.contains("Броня:") and view._item_comparison.text.contains("(+%d)" % item.armor_bonus))
	view.queue_free()
	assert(hero.equipped_accessories.is_empty())


func _test_shield_is_not_passive_armor() -> void:
	var hero: HeroState = HeroState.new(HeroCatalog.get_hero("petushan"))
	var shield: ItemDefinition = ItemCatalog.get_item("shield")
	var before: Dictionary = CharacterStats.hero_values(hero)
	var after: Dictionary = CharacterStats.preview_equipment(hero, "off_hand", shield)
	assert(after["defense"] == before["defense"])
	assert(int(after["block_rating"]) == shield.defense_bonus)
	hero.register_shield(shield)
	assert(hero.equip_item(shield))
	var actor: BattleParticipant = BattleParticipant.from_hero(hero)
	assert(actor.effective_defense() == int(before["defense"]))
	actor.prepare_block(2)
	assert(actor.preview_block_armor() == shield.defense_bonus)

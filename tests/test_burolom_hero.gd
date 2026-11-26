extends SceneTree

const STARTER_ABILITIES: Array[String] = [
	"burolom_control_pass", "burolom_notch", "burolom_strata_break", "burolom_brace"
]
const FUTURE_ABILITIES: Array[String] = [
	"burolom_deep_drill", "burolom_double_auger", "burolom_seismic_sense",
	"burolom_gear_break", "burolom_reverse", "burolom_collapse"
]
const ABILITY_ICONS: Array[String] = [
	"control_pass", "deep_drill", "double_auger", "notch", "strata_break",
	"brace", "seismic_sense", "gear_break", "reverse", "collapse"
]


func _initialize() -> void:
	_test_catalog_and_abilities()
	_test_damage_and_crack()
	_test_block_and_equipment_requirement()
	_test_party_save_and_editor()
	print("DA-6: Burolom, abilities, party, equipment, saves and UI OK")
	quit()


func _test_catalog_and_abilities() -> void:
	assert(HeroCatalog.has("burolom"))
	var definition: HeroDefinition = HeroCatalog.get_hero("burolom")
	assert(definition.display_name == "Буролом")
	assert(definition.max_health == 54)
	assert(definition.strength == 9 and definition.agility == 3 and definition.perception == 9)
	assert(definition.base_action_slots == 3 and definition.base_dodge_percent == 0)
	assert(definition.portrait != null and definition.portrait.get_width() == 320)
	assert(definition.map_icon != null and definition.map_icon.get_width() == 80)
	assert(definition.personal_ability_ids == STARTER_ABILITIES)
	var hero := HeroState.new(definition)
	assert(hero.perception == 9)
	assert(hero.equipped_weapon_id == "burolom_drill")
	assert(hero.get_saved_action_slots() == STARTER_ABILITIES.slice(0, 3))
	var actor := BattleParticipant.from_hero(hero)
	assert(actor.equipped_weapon_id == "burolom_drill")
	assert(BattleMath.accuracy_total(actor.agility, actor.accuracy_bonus, 0) == 85)
	for ability_id in STARTER_ABILITIES:
		var ability: AbilityDefinition = AbilityCatalog.get_ability(ability_id)
		assert(ability != null and ability.validation_error().is_empty())
		assert(ability.icon != null and ability.icon.get_size() == Vector2(64, 64))
		assert(DescriptionTemplate.unresolved_tokens(ability.get_description()).is_empty())
		assert(AbilityCatalog.can_prepare(actor, ability_id))
	for ability_id in FUTURE_ABILITIES:
		assert(not actor.personal_ability_ids.has(ability_id))
		assert(not AbilityCatalog.can_prepare(actor, ability_id))
	for icon_name in ABILITY_ICONS:
		var texture: Texture2D = load("res://assets/abilities/burolom/%s.png" % icon_name) as Texture2D
		assert(texture != null and texture.get_size() == Vector2(64, 64))
	var weapon: ItemDefinition = ItemCatalog.get_item("burolom_drill")
	assert(weapon != null and weapon.two_handed and weapon.weapon_damage == 0)
	assert(weapon.equipment_slot == ItemDefinition.EquipmentSlot.WEAPON)
	assert(not ItemCatalog.LOOT_TABLE.weights.has("burolom_drill"))
	assert(not ItemCatalog.list_ids().has("burolom_drill"))
	assert(not DungeonMap.CHEST_REWARDS.has("burolom_drill"))


func _battle() -> BattleState:
	var source := HeroState.new(HeroCatalog.get_hero("burolom"))
	var state: BattleState = BattleState.begin(MonsterCatalog.get_monster("hunter"), source, 2106)
	var target: BattleParticipant = state.get_enemy()
	state.get_hero().accuracy_bonus += 20
	target.health = 100
	target.max_health = 100
	target._base_max_health = 100
	target.agility = 0
	target.base_dodge_percent = 0
	return state


func _test_damage_and_crack() -> void:
	var state: BattleState = _battle()
	var hero: BattleParticipant = state.get_hero()
	var target: BattleParticipant = state.get_enemy()
	var notch: AbilityDefinition = AbilityCatalog.get_ability("burolom_notch")
	var break_ability: AbilityDefinition = AbilityCatalog.get_ability("burolom_strata_break")
	var regular: int = AbilityExecutor.preview_damage(hero, break_ability, break_ability.effects[0], target)
	var notch_result: Dictionary = state.execute_ability("hero", "enemy", "burolom_notch")
	assert(notch_result.success)
	assert(target.statuses.has("burolom_crack"))
	assert(int(target.statuses["burolom_crack"]["next_block_penalty"]) == notch.effects[1].next_block_penalty)
	assert(int(target.statuses["burolom_crack"]["ticks"]) == notch.effects[1].duration_ticks)
	var enhanced: int = AbilityExecutor.preview_damage(hero, break_ability, break_ability.effects[0], target)
	assert(enhanced > regular)
	var break_result: Dictionary = state.execute_ability("hero", "enemy", "burolom_strata_break")
	assert(break_result.success)
	assert(not target.statuses.has("burolom_crack"))
	var after: int = AbilityExecutor.preview_damage(hero, break_ability, break_ability.effects[0], target)
	assert(after == regular)
	var weak: BattleState = _battle()
	var victim: BattleParticipant = weak.get_enemy()
	victim.prepare_block(100)
	assert(weak.execute_ability("hero", "enemy", "burolom_notch").success)
	assert(not victim.statuses.has("burolom_crack"))
	var control_pass: AbilityDefinition = AbilityCatalog.get_ability("burolom_control_pass")
	assert(control_pass.effects[0].accuracy_offset_percent == 15)
	assert(control_pass.effects[0].damage_multiplier == 0.9)


func _test_block_and_equipment_requirement() -> void:
	var state: BattleState = _battle()
	var attacker: BattleParticipant = state.get_hero()
	var defender: BattleParticipant = state.get_enemy()
	assert(state.execute_ability("hero", "hero", "burolom_brace").success)
	assert(attacker.block_armor == 4)
	assert(attacker.block_attack_bonus_percent == BattleMath.RULES.block_attack_bonus_percent)
	attacker.equipped_weapon_id = ""
	assert(not state.execute_ability("hero", "hero", "burolom_brace").success)
	attacker.equipped_weapon_id = "burolom_drill"
	var crack: AbilityEffectDefinition = AbilityCatalog.get_ability("burolom_notch").effects[1]
	defender.apply_status(crack, 1)
	assert(defender.statuses.has("burolom_crack"))
	assert(defender.preview_block_armor(4) == 2)
	defender.prepare_block(4)
	assert(defender.block_armor == 2)
	assert(not defender.statuses.has("burolom_crack"))
	assert(defender.block_attack_bonus_percent == BattleMath.RULES.block_attack_bonus_percent)
	var expiration: BattleParticipant = _battle().get_enemy()
	expiration.apply_status(crack, 1)
	assert(expiration.statuses.has("burolom_crack"))
	expiration.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE, 2)
	assert(int(expiration.statuses["burolom_crack"]["ticks"]) == 1)
	expiration.apply_status(crack, 3)
	assert(int(expiration.statuses["burolom_crack"]["ticks"]) == 2)
	expiration.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE, 4)
	assert(expiration.statuses.has("burolom_crack"))
	expiration.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE, 5)
	assert(not expiration.statuses.has("burolom_crack"))


func _test_party_save_and_editor() -> void:
	var map_data: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(map_data.place_entity("player_spawn", 2, 2))
	var session: GameSession = GameSession.start_for_party(map_data, ["burolom", "petushan", "volcha"])
	assert(session != null and session.party.size() == 3)
	assert(session.party[0].definition.hero_id == "burolom")
	assert(int(session.carried_items.get("burolom_drill", 0)) == 1)
	var legacy_data: Dictionary = session.party[0].to_snapshot()
	legacy_data.erase("perception")
	var compatible_hero: HeroState = HeroState.from_snapshot(legacy_data)
	assert(compatible_hero != null and compatible_hero.perception == 9)
	var starting_id: String = session.equipment_instance_id("main_hand", session.party[0])
	assert(not starting_id.is_empty())
	assert(session.item_instance(starting_id).item_id == "burolom_drill")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {map_data.map_id: map_data})
	assert(restored != null and restored.party.size() == 3)
	assert(restored.party[0].perception == 9)
	assert(restored.party[0].definition.hero_id == "burolom")
	assert(restored.equipment_instance_id("main_hand", restored.party[0]) == starting_id)
	restored.inventory_member = restored.party[0]
	assert(restored.unequip_equipment_slot("main_hand"))
	assert(restored.equipment_instance_id("main_hand", restored.party[0]).is_empty())
	assert(restored.inventory_slot_ids().has("burolom_drill"))
	var picker: HeroSelection = load("res://scenes/hero_selection.tscn").instantiate() as HeroSelection
	root.add_child(picker)
	var card: Button = picker._catalog.tiles.get("burolom") as Button
	assert(card != null)
	assert(card.tooltip_text == "Буролом")
	var chosen: Array[String] = []
	picker.party_chosen.connect(func(ids: Array[String]) -> void: chosen.assign(ids))
	card.pressed.emit()
	assert(picker._preview.hero_name.text == "Буролом")
	picker._catalog.hero_add_requested.emit("burolom")
	assert(picker.selected_party() == ["burolom"])
	picker.get_node("%StartPartyButton").pressed.emit()
	assert(chosen == ["burolom"])
	picker.queue_free()
	var panel := EditorTestHeroPanel.new()
	root.add_child(panel)
	panel.select_party(["petushan", "volcha", "burolom"])
	assert(panel.selected_party() == ["petushan", "volcha", "burolom"])
	panel.queue_free()

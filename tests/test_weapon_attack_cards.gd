extends SceneTree


func _initialize() -> void:
	var hero: HeroState = HeroState.new(HeroCatalog.get_hero(HeroCatalog.DEFAULT_HERO_ID))
	var unarmed: BattleParticipant = BattleParticipant.from_hero(hero)
	assert(AbilityCatalog.can_prepare(unarmed, "weapon_fist_strike"))
	assert(not AbilityCatalog.can_prepare(unarmed, "weapon_sword_strike"))
	assert(not AbilityCatalog.can_prepare(unarmed, "weapon_spear_strike"))
	var fist: AbilityDefinition = AbilityCatalog.get_ability("weapon_fist_strike")
	var sword_attack: AbilityDefinition = AbilityCatalog.get_ability("weapon_sword_strike")
	var spear_attack: AbilityDefinition = AbilityCatalog.get_ability("weapon_spear_strike")
	assert(fist != null and sword_attack != null and spear_attack != null)
	assert(fist.ignore_weapon_damage)
	assert(AbilityExecutor.preview_damage(unarmed, fist, fist.effects[0]) == unarmed.melee_attack())

	var session := GameSession.new()
	session.hero = hero
	session._receive_item("sword", 1)
	assert(hero.equipped_weapon_id == "sword")
	var armed: BattleParticipant = BattleParticipant.from_hero(hero)
	assert(AbilityCatalog.can_prepare(armed, "weapon_sword_strike"))
	assert(not AbilityCatalog.can_prepare(armed, "weapon_spear_strike"))
	assert(AbilityExecutor.preview_damage(armed, sword_attack, sword_attack.effects[0]) == armed.melee_attack())
	assert(AbilityExecutor.preview_damage(armed, fist, fist.effects[0]) == unarmed.melee_attack())
	assert(AbilityCatalog.known_ability_ids(armed).has("weapon_sword_strike"))

	session._receive_item("spear", 1)
	assert(hero.equipped_weapon_id == "sword")
	assert(hero.equip_item(ItemCatalog.get_item("spear")))
	var spearman: BattleParticipant = BattleParticipant.from_hero(hero)
	assert(not AbilityCatalog.can_prepare(spearman, "weapon_sword_strike"))
	assert(AbilityCatalog.can_prepare(spearman, "weapon_spear_strike"))
	assert(AbilityExecutor.preview_damage(spearman, spear_attack, spear_attack.effects[0]) == spearman.melee_attack())
	assert(AbilityCatalog.can_prepare(spearman, "weapon_fist_strike"))

	var chain: Array[String] = ["weapon_fist_strike", "weapon_spear_strike"]
	var slots: Array[String] = [chain[0], chain[1], ""]
	assert(hero.save_action_slots(slots))
	var battle := BattleState.begin(MonsterCatalog.get_monster("skeleton"), hero, 12345)
	assert(battle != null)
	var prepared: Dictionary = battle.prepare_manual_combat(chain)
	assert(bool(prepared.get("success", false)))
	assert(battle.manual_available_slots().size() == 2)
	quit()

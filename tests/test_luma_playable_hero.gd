extends SceneTree

const ABILITY_IDS: Array[String] = [
	"luma_wandering_spark", "luma_star_spear", "luma_sun_shards",
	"luma_star_devourer", "luma_life_thread", "luma_light_cocoon",
	"luma_star_birth", "luma_silence", "luma_resonance_seal", "luma_last_spark"
]


func _initialize() -> void:
	_test_catalog()
	_test_abilities()
	_test_party_and_saves()
	print("Luma hero, energy and spells OK")
	quit()


func _fighter() -> BattleParticipant:
	return BattleParticipant.from_hero(HeroState.new(HeroCatalog.get_hero("luma")))


func _context(hero: BattleParticipant, enemies: Array[BattleParticipant], ally: BattleParticipant = null) -> BattleContext:
	var participants: Dictionary = {"hero": hero}
	for index in range(enemies.size()):
		participants["enemy" if index == 0 else "enemy_%d" % index] = enemies[index]
	if ally != null:
		participants["hero_2"] = ally
	var rng := RandomNumberGenerator.new()
	rng.seed = 607
	return BattleContext.new(participants, rng)


func _cast(context: BattleContext, target_id: String, ability_id: String) -> Dictionary:
	var outcome: Dictionary = AbilityExecutor.execute(context, "hero", target_id, ability_id)
	assert(bool(outcome.get("success", false)), "%s: %s" % [ability_id, str(outcome.get("reason", ""))])
	return outcome


func _test_catalog() -> void:
	var hero: HeroDefinition = HeroCatalog.get_hero("luma")
	assert(hero.hero_id == "luma" and hero.display_name == "Люма")
	assert(hero.max_health == 32 and hero.strength == 2 and hero.agility == 5)
	assert(hero.perception == 8 and hero.base_accuracy_percent == 90)
	assert(hero.max_energy == 24 and hero.energy_restoration == 4)
	assert(hero.portrait != null and hero.portrait.get_width() == 320)
	assert(hero.map_icon != null and hero.map_icon.get_width() == 80)
	assert(hero.personal_ability_ids.size() == ABILITY_IDS.size())
	for ability_id in ABILITY_IDS:
		var ability: AbilityDefinition = AbilityCatalog.get_ability(ability_id)
		assert(ability != null and ability.validation_error().is_empty())
		assert(hero.personal_ability_ids.has(ability_id))
		assert(ability.icon != null and ability.icon.get_width() == 64 and ability.icon.get_height() == 64)
		assert(DescriptionTemplate.unresolved_tokens(ability.get_description()).is_empty())
	assert(AbilityCatalog.validate_catalog().is_empty())


func _test_abilities() -> void:
	var hero: BattleParticipant = _fighter()
	var enemy: BattleParticipant = BattleParticipant.from_monster(MonsterCatalog.get_monster("lobar"))
	var second: BattleParticipant = BattleParticipant.from_monster(MonsterCatalog.get_monster("giant_crab"))
	var ally: BattleParticipant = BattleParticipant.from_hero(HeroState.new(HeroCatalog.get_hero("volcha")), "hero_2")
	hero.accuracy_bonus += 100
	var enemies: Array[BattleParticipant] = [enemy, second]
	var ctx: BattleContext = _context(hero, enemies, ally)
	assert(hero.current_energy() == 24)
	assert(_cast(ctx, "enemy", "luma_wandering_spark").get("success", false))
	assert(hero.current_energy() == 24)
	var before: int = hero.current_energy()
	var spear: Dictionary = _cast(ctx, "enemy", "luma_star_spear")
	assert(hero.current_energy() == before - 6)
	assert((spear["events"] as Array).any(func(e: Dictionary) -> bool: return str(e.get("type", "")) == "attack"))
	_cast(ctx, "enemy", "luma_sun_shards")
	assert(hero.current_energy() == 9)
	assert(enemy.statuses.has("luma_burning") and second.statuses.has("luma_burning"))
	assert(enemy.owner_phase_status_damage_events("enemy").size() > 0)
	var old_energy: int = enemy.current_energy()
	var drain: Dictionary = _cast(ctx, "enemy", "luma_star_devourer")
	assert(enemy.current_energy() == old_energy - 3)
	assert(hero.current_energy() == 12)
	assert((drain["events"] as Array).size() > 0)
	assert(not AbilityCatalog.get_ability("luma_star_devourer").unavailable_reason(hero).is_empty())
	EnergyAbilityResolver.at_turn_end(hero)
	assert(AbilityCatalog.get_ability("luma_star_devourer").unavailable_reason(hero).is_empty())
	ally.change_energy(-6)
	var ally_before: int = ally.current_energy()
	_cast(ctx, "hero_2", "luma_life_thread")
	assert(ally.current_energy() == ally_before + 4)
	assert(hero.current_energy() == 8)
	assert(ctx.target_error("hero", "hero", AbilityCatalog.get_ability("luma_light_cocoon")).is_empty())
	_cast(ctx, "hero_2", "luma_light_cocoon")
	assert(ally.energy_barrier_hp == 7)
	ally.receive_damage(6)
	assert(ally.energy_barrier_hp == 1)
	EnergyAbilityResolver.at_turn_start(ctx, ally)
	assert(ally.energy_barrier_hp == 0)
	hero.change_energy(10)
	_cast(ctx, "enemy", "luma_star_birth")
	assert(hero.energy_delayed_attacks.has("enemy"))
	assert(EnergyAbilityResolver.at_turn_start(ctx, hero).is_empty())
	assert(EnergyAbilityResolver.at_turn_start(ctx, hero).is_empty())
	var star_events: Array[Dictionary] = EnergyAbilityResolver.at_turn_start(ctx, hero)
	assert(not star_events.is_empty() and not hero.energy_delayed_attacks.has("enemy"))
	hero.change_energy(-8)
	_cast(ctx, "hero", "luma_silence")
	assert(hero.energy_meditation_pending == 8)
	EnergyAbilityResolver.at_turn_start(ctx, hero)
	assert(hero.energy_meditation_pending == 0)
	assert(hero.current_energy() > 0)
	hero.change_energy(10)
	_cast(ctx, "enemy", "luma_resonance_seal")
	assert(enemy.energy_resonance_charges == 3)
	hero.change_energy(-20)
	var regained: Dictionary = EnergyAbilityResolver.on_hit(hero, enemy)
	assert(int(regained.get("amount", 0)) == 2)
	assert(enemy.energy_resonance_charges == 2)
	hero.change_energy(-24)
	assert(AbilityCatalog.get_ability("luma_last_spark").unavailable_reason(hero).is_empty())
	var hp_before: int = hero.health
	_cast(ctx, "enemy", "luma_last_spark")
	assert(hero.health == hp_before - 7)
	var saved_energy: int = hero.current_energy()
	hero.change_energy(-4)
	assert(hero.current_energy() == saved_energy - 4)
	assert(EnergyAbilityResolver.at_turn_end(hero).size() > 0)


func _test_party_and_saves() -> void:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	var session: GameSession = GameSession.start_for_party(dungeon, ["luma", "volcha", "petushan", "burolom"])
	assert(session != null and session.party.size() == 4)
	var luma: HeroState = session.party[0]
	luma.energy = 13
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {dungeon.map_id: dungeon})
	assert(restored != null)
	assert(restored.party.size() == 4 and restored.party[0].energy == 13)
	var combat: CombatSession = CombatSession.new(MonsterCatalog.get_monster("giant_crab"),
		restored.party[0], null, 1337, restored.party)
	assert(combat.battle_state.hero_ids().size() == 4)
	var fighter: BattleParticipant = combat.battle_state.get_hero()
	assert(fighter.current_energy() == 13)
	fighter.change_energy(-3)
	combat.sync_hero_results()
	assert(restored.party[0].energy == 10)

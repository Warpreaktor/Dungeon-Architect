extends SceneTree

## DA-4.03: проверка описаний без экрана боя и исполнения новых эффектов.
func _initialize() -> void:
	assert(AbilityCatalog.validate_catalog().is_empty())
	var strike: AbilityDefinition = AbilityCatalog.get_ability("basic_strike")
	assert(strike != null and strike.effects.size() == 1)
	assert(strike.category == AbilityDefinition.Category.ATTACK)
	assert(strike.target == AbilityDefinition.Target.ENEMY)
	assert(strike.display_name == "Удар")
	assert(AbilityCatalog.get_ability("not_registered") == null)

	var duplicate: Array[AbilityDefinition] = [strike, strike]
	assert(not AbilityCatalog.validate_definitions(duplicate).is_empty())
	var broken := AbilityDefinition.new()
	broken.ability_id = "broken"
	broken.display_name = "Пустой"
	assert(not broken.validation_error().is_empty())
	broken.effects.append(null)
	assert(not broken.validation_error().is_empty())
	var invalid: Array[AbilityDefinition] = [broken]
	assert(not AbilityCatalog.validate_definitions(invalid).is_empty())

	var wolf := HeroState.new(HeroCatalog.get_hero("volcha"))
	var rooster := HeroState.new(HeroCatalog.get_hero("petushan"))
	var hunter: MonsterDefinition = MonsterCatalog.get_monster("hunter")
	var battle: BattleState = BattleState.begin(hunter, wolf)
	var wolf_actor: BattleParticipant = battle.get_hero()
	assert(wolf_actor.personal_ability_ids.has("wolf_feint"))
	assert(not wolf_actor.personal_ability_ids.has("rooster_crush"))
	assert(AbilityCatalog.can_prepare(wolf_actor, "wolf_feint"))
	assert(not AbilityCatalog.can_prepare(wolf_actor, "rooster_crush"))
	assert(not AbilityCatalog.can_prepare(wolf_actor, "unknown"))
	assert(battle.get_enemy().personal_ability_ids.has("hunter_shot"))
	assert(AbilityCatalog.can_prepare(battle.get_enemy(), "hunter_shot"))
	var rooster_actor: BattleParticipant = BattleParticipant.from_hero(rooster)
	assert(not AbilityCatalog.can_prepare(rooster_actor, "rooster_crush")) # Нужен меч.
	rooster.equip_weapon(ItemCatalog.get_item("sword"))
	rooster_actor = BattleParticipant.from_hero(rooster)
	assert(AbilityCatalog.can_prepare(rooster_actor, "rooster_crush"))

	wolf.learned_ability_ids.append("hunter_shot")
	var learned_actor: BattleParticipant = BattleParticipant.from_hero(wolf)
	assert(AbilityCatalog.can_prepare(learned_actor, "hunter_shot"))
	assert(AbilityCatalog.available_abilities(learned_actor).size() == 4)
	learned_actor.learned_ability_ids.append("unknown")
	learned_actor.learned_ability_ids.append("hunter_shot")
	assert(AbilityCatalog.available_abilities(learned_actor).size() == 4)
	assert(not AbilityCatalog.can_prepare(learned_actor, "unknown"))
	assert(not rooster.learned_ability_ids.has("hunter_shot"))
	assert(not wolf.definition.personal_ability_ids.has("hunter_shot"))
	var other: BattleParticipant = BattleParticipant.from_hero(wolf)
	learned_actor.learned_ability_ids.clear()
	assert(other.learned_ability_ids.has("hunter_shot"))
	assert(wolf.learned_ability_ids.has("hunter_shot"))
	quit()

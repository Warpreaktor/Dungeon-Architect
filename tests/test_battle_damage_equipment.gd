extends SceneTree

## Урон зависит от актуального оружия, характеристик и эффекта блока.
func _initialize() -> void:
	var wolf := HeroState.new(HeroCatalog.get_hero("petushan"))
	var strike: AbilityDefinition = AbilityCatalog.get_ability("basic_strike")
	var hero: BattleParticipant = BattleParticipant.from_hero(wolf)
	var unarmed: int = AbilityExecutor.preview_damage(hero, strike, strike.effects[0])
	assert(unarmed == floori(float(wolf.strength) * 0.5 + 1))
	assert(hero.weapon_damage(ItemDefinition.WeaponKind.MELEE) == 0)

	# Weapon damage is a value, not a bonus added to a hidden character attack.
	var sword: ItemDefinition = ItemCatalog.get_item("sword")
	assert(sword.weapon_damage > 0 and sword.weapon_kind == ItemDefinition.WeaponKind.MELEE)
	assert(wolf.equip_item(sword))
	var equipped: BattleParticipant = BattleParticipant.from_hero(wolf)
	assert(AbilityExecutor.preview_damage(equipped, strike, strike.effects[0]) == unarmed + sword.weapon_damage)
	assert(hero.melee_attack() == floori(float(wolf.strength) * 0.5)) # Earlier battle snapshot unchanged.
	assert(equipped.ranged_attack_value() == float(wolf.agility) * 0.5) # Sword does not boost shot.
	assert(wolf.unequip_item("sword"))
	assert(BattleParticipant.from_hero(wolf).melee_attack() == hero.melee_attack())

	# A ranged ability uses Agility, even for someone holding a melee sword.
	assert(wolf.equip_item(sword))
	var ranged := AbilityDefinition.new()
	ranged.ability_id = "test_ranged"
	ranged.display_name = "Пробный выстрел"
	ranged.damage_delivery = AbilityDefinition.DamageDelivery.RANGED
	ranged.target = AbilityDefinition.Target.ENEMY
	var ranged_hit := AbilityEffectDefinition.new()
	ranged_hit.kind = AbilityEffectDefinition.Kind.DAMAGE
	ranged_hit.recipient = AbilityEffectDefinition.Recipient.TARGET
	ranged_hit.amount = 2
	ranged.effects = [ranged_hit]
	var battle: BattleState = BattleState.begin(MonsterCatalog.get_monster("hunter"), wolf)
	var attacker: BattleParticipant = battle.get_hero()
	attacker.personal_ability_ids.append("test_ranged")
	var expected_range: int = floori(float(wolf.agility) * 0.5 + 2)
	assert(AbilityExecutor.preview_damage(attacker, ranged, ranged_hit) == expected_range)
	var shot: Dictionary = battle.execute_definition("hero", "enemy", ranged)
	assert(shot.success and shot.events[0].damage == maxi(expected_range - battle.get_enemy().defense, 0))
	attacker.agility += 2
	assert(AbilityExecutor.preview_damage(attacker, ranged, ranged_hit) == expected_range + 1)
	assert(AbilityExecutor.preview_damage(attacker, strike, strike.effects[0]) == floori(float(wolf.strength) * 0.5 + sword.weapon_damage + 1))

	# Rounding only once, after adding weapon power and strength and block bonus.
	attacker.strength = 1
	attacker.learned_ability_ids.append("guard")
	assert(battle.execute_ability("hero", "hero", "guard").success)
	assert(AbilityExecutor.preview_damage(attacker, strike, strike.effects[0]) == floori((0.5 + sword.weapon_damage + 1) * 1.25))
	assert(wolf.strength == wolf.definition.strength) # Shared resource / original untouched.

	# A two-handed weapon forbids an equipped shield. A shield never adds weapon damage.
	var shield: ItemDefinition = ItemCatalog.get_item("spiked_shield")
	var twohand: ItemDefinition = ItemCatalog.get_item("warhammer")
	var equip_test := HeroState.new(HeroCatalog.get_hero("petushan"))
	equip_test.register_shield(shield)
	assert(equip_test.equip_item(shield))
	assert(equip_test.equip_item(twohand))
	assert(equip_test.equipped_shield_id.is_empty())
	assert(not equip_test.equip_item(shield))
	assert(equip_test.weapon_damage(ItemDefinition.WeaponKind.MELEE) == twohand.weapon_damage)

	# Shield takes full damage only on an active block, never passive armor.
	var guarded := HeroState.new(HeroCatalog.get_hero("petushan"))
	guarded.register_shield(shield)
	assert(guarded.equip_item(shield))
	var protected: BattleParticipant = BattleParticipant.from_hero(guarded)
	protected._hero_snapshot.base_defense = 3
	protected.refresh_from_hero()
	protected.prepare_block(2)
	var hit: int = protected.receive_damage(10)
	assert(hit == 10 - shield.defense_bonus)
	assert(protected.last_shield_blocked == shield.defense_bonus)
	assert(protected._hero_snapshot.current_shield_durability(shield.item_id) == shield.max_durability - 10)
	protected._hero_snapshot.shield_durabilities[shield.item_id] = [1]
	protected.refresh_from_hero()
	protected.prepare_block(2)
	assert(protected.receive_damage(10) == 10 - shield.defense_bonus)
	assert(protected.equipped_shield_id.is_empty())
	protected.prepare_block(2)
	assert(protected.block_armor == 2)
	assert(protected.block_attack_bonus_percent == 75)
	quit()

extends SceneTree


func _initialize() -> void:
	_check_catalogs()
	_check_item()
	_check_ability()
	_check_bond()
	_check_trap()
	assert(DescriptionTemplate.phases(1) == "1 фазу")
	assert(DescriptionTemplate.phases(2) == "2 фазы")
	assert(DescriptionTemplate.phases(5) == "5 фаз")
	assert(DescriptionTemplate.phases(11) == "11 фаз")
	assert(DescriptionTemplate.phases(21) == "21 фазу")
	assert(DescriptionTemplate.number(0.5) == "0,5")
	assert(DescriptionTemplate.unresolved_tokens(DescriptionTemplate.render("{missing}", {})).size() == 1)
	quit()


func _check_catalogs() -> void:
	for id in ItemCatalog.list_ids():
		var item: ItemDefinition = ItemCatalog.get_item(id)
		assert(item != null)
		assert(DescriptionTemplate.unresolved_tokens(item.get_description()).is_empty(), id)
	for id in AbilityCatalog.list_ids():
		var ability: AbilityDefinition = AbilityCatalog.get_ability(id)
		assert(ability != null)
		assert(DescriptionTemplate.unresolved_tokens(ability.get_description()).is_empty(), id)
		assert(DescriptionTemplate.unresolved_tokens(BattleAbilityTooltip.describe(ability)).is_empty(), id)
	for id in TrapCatalog.list_ids():
		var trap: TrapDefinition = TrapCatalog.get_trap(id)
		assert(trap != null)
		assert(DescriptionTemplate.unresolved_tokens(trap.get_description()).is_empty(), id)


func _check_item() -> void:
	var item: ItemDefinition = ItemCatalog.get_item("potion_strength_small").duplicate() as ItemDefinition
	var template: String = item.description
	item.effect_value = 37
	item.effect_duration_phases = 11
	assert(item.get_description().contains("+37"))
	assert(item.get_description().contains("11 фаз"))
	item.effect_duration_phases = 1
	assert(item.get_description().contains("1 фазу"))
	assert(item.description == template)
	var healing: ItemDefinition = ItemCatalog.get_item("potion_health_small").duplicate() as ItemDefinition
	healing.healing_amount = 43
	assert(healing.get_description().contains("43 HP"))


func _check_ability() -> void:
	var original: AbilityDefinition = AbilityCatalog.get_ability("volcha_broken_rhythm")
	var ability: AbilityDefinition = original.duplicate() as AbilityDefinition
	ability.effects = []
	var damage: AbilityEffectDefinition = original.effects[0].duplicate() as AbilityEffectDefinition
	ability.effects.append(damage)
	damage.hit_count = 7
	assert(ability.get_description().contains("7 ударов"))
	assert(BattleAbilityTooltip.describe(ability).contains("Ударов: 7"))
	var instinct: AbilityDefinition = AbilityCatalog.get_ability("volcha_wolf_instinct")
	ability = instinct.duplicate() as AbilityDefinition
	ability.effects = []
	var status: AbilityEffectDefinition = instinct.effects[0].duplicate() as AbilityEffectDefinition
	ability.effects.append(status)
	status.amount = 31
	status.duration_ticks = 3
	assert(ability.get_description().contains("31 п.п."))
	assert(ability.get_description().contains("3 входящие атаки"))
	status.status_modifier = 47
	assert(ability.get_description().contains("47 п.п."))
	assert(not ability.get_description().contains("31 п.п."))


func _check_bond() -> void:
	var command: AbilityDefinition = AbilityCatalog.get_ability("rabbit_command_strike")
	var bond: BattleBondDefinition = MonsterCatalog.get_monster("rabbit_symbiont").battle_bond
	assert(command.description_data == bond)
	var change: AbilityDefinition = command.duplicate() as AbilityDefinition
	var changed_bond: BattleBondDefinition = bond.duplicate() as BattleBondDefinition
	change.description_data = changed_bond
	changed_bond.marked_accuracy_bonus = 42
	assert(change.get_description().contains("42 п.п."))


func _check_trap() -> void:
	var trap: TrapDefinition = TrapCatalog.get_trap("spikes").duplicate() as TrapDefinition
	trap.direct_damage = 17
	trap.overworld_status_damage = 19
	trap.overworld_status_ticks = 5
	trap.disarm_on_trigger = false
	var result: String = trap.get_description()
	assert(result.contains("17 HP"))
	assert(result.contains("19 HP"))
	assert(result.contains("5 фаз"))
	assert(not result.contains("разряжается"))

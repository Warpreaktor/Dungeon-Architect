class_name BattleParticipant
extends RefCounted

## Снимок одного участника боя. Ресурсы героя и монстра не изменяются.
## ID участника не зависит от того, каким портретом он отображается.
var participant_id: String = ""
var definition_id: String = ""
var team_id: String = ""
var is_targetable: bool = true
var is_passive: bool = false
var max_health: int = 0
var _base_max_health: int = 0
var health: int = 0
var strength: int = 0
var agility: int = 0
var defense: int = 0
var base_dodge_percent: int = 0
## Редактируемый дополнительный бонус меткости; Ловкость даёт основной.
var accuracy_bonus: int = 0
var equipped_weapon_id: String = ""
var equipped_shield_id: String = ""
var effects: Dictionary = {}
var personal_ability_ids: Array[String] = []
var learned_ability_ids: Array[String] = []
var action_chain: Array[String] = []
## Следующий слот; значение action_chain.size() означает такт перезарядки.
var action_cursor: int = 0
## Ограничение участника, независимое от глобального защитного MAX_ACTIONS.
var action_slot_capacity: int = 3
var tactic_changes_remaining: int = 0
# Броня блока действует только на следующее попадание.
var block_armor: int = 0
var block_attack_bonus_percent: int = 0
var last_shield_blocked: int = 0
## Фактическая часть удара, остановленная активным блоком (в т.ч. у монстров).
var last_block_absorbed: int = 0
var last_shield_broken: String = ""
var statuses: Dictionary = {}
## Number of completed own cycles (including the non-editable rest).
var completed_phases: int = 0
var is_resting: bool = false
var last_round_action_was_rest: bool = false
var fury_rules: MonsterFuryRules
var fury_gained_this_round: int = 0
var fury_guard_armed: bool = false
## Для совпадения наложения статуса и отдыха в одном такте.
var last_rest_tick: int = -1
## Неиспользуемые пока в контенте запасы будущих ресурсов (ярость, мана и т.д.).
## Это изменяемые данные конкретного участника боя, не .tres.
var resource_amounts: Dictionary = {}
var max_energy: int = 0
var energy_restoration: int = 0
var energy_barrier_hp: int = 0
var energy_meditation_pending: int = 0
var energy_delayed_attacks: Dictionary = {}
var energy_resonance_charges: int = 0
var energy_resonance_turns: int = 0
var energy_resonance_restore: int = 0
var energy_cooldowns: Dictionary = {}
const PERCENT_SCALE: int = BattleMath.PERCENT_SCALE

# Снимок героя остаётся изолирован от прогресса прохождения.
# Работу с предметами делегируем адаптеру экипировки.
var _hero_snapshot: HeroState
var _equipment: BattleEquipment = BattleEquipment.new()


static func from_hero(source: HeroState, id: String = "hero") -> BattleParticipant:
	if source == null:
		return null
	var participant := BattleParticipant.new()
	participant.participant_id = id
	participant.team_id = "heroes"
	participant.definition_id = source.definition.hero_id if source.definition != null else ""
	participant._hero_snapshot = source.copy_for_battle()
	participant.max_energy = source.definition.max_energy
	participant.energy_restoration = source.definition.energy_restoration
	participant.resource_amounts["energy"] = source.energy
	participant.statuses = participant._hero_snapshot.overworld_statuses.duplicate(true)
	participant._equipment.set_snapshot(participant._hero_snapshot)
	participant.personal_ability_ids = source.definition.personal_ability_ids.duplicate() if source.definition != null else []
	participant.base_dodge_percent = source.definition.base_dodge_percent if source.definition != null else 0
	participant.accuracy_bonus = source.definition.accuracy_bonus if source.definition != null else 0
	participant.learned_ability_ids = source.learned_ability_ids.duplicate()
	participant.action_slot_capacity = source.action_slot_capacity()
	participant.refresh_from_hero()
	participant._sync_status_health_limit(false)
	return participant


static func from_monster(source: MonsterDefinition, id: String = "enemy") -> BattleParticipant:
	if source == null:
		return null
	var participant := BattleParticipant.new()
	participant.participant_id = id
	participant.team_id = "enemies"
	participant.definition_id = source.monster_id
	participant.max_health = source.max_health
	participant._base_max_health = participant.max_health
	participant.health = participant.max_health
	participant.fury_rules = source.fury_rules
	participant.strength = source.strength
	participant.agility = source.agility
	participant.defense = source.defense
	participant.base_dodge_percent = source.base_dodge_percent
	participant.accuracy_bonus = source.accuracy_bonus
	participant.personal_ability_ids = source.personal_ability_ids.duplicate()
	for action in source.intermission_actions:
		if action != null and not participant.learned_ability_ids.has(action.ability_id):
			participant.learned_ability_ids.append(action.ability_id)
	participant.resource_amounts = source.starting_resources.duplicate(true)
	if participant.fury_rules != null:
		participant.resource_amounts["fury"] = 0
	participant.max_energy = source.max_energy
	participant.energy_restoration = source.energy_restoration
	participant.resource_amounts["energy"] = source.max_energy
	participant.action_slot_capacity = clampi(source.base_action_slots, 1, BattleChainPlanner.MAX_ACTIONS)
	return participant


func refresh_from_hero() -> void:
	if _hero_snapshot == null:
		return
	_equipment.set_snapshot(_hero_snapshot)
	var stats: Dictionary = CharacterStats.hero_values(_hero_snapshot, false)
	_base_max_health = int(stats["max_health"])
	max_health = BattleStatusRules.health_limit(_base_max_health, statuses)
	health = _hero_snapshot.health
	strength = int(stats["strength"])
	agility = int(stats["agility"])
	base_dodge_percent = int(stats["base_dodge_percent"])
	accuracy_bonus = int(stats["accuracy_bonus"])
	defense = int(stats["defense"])
	equipped_weapon_id = _hero_snapshot.equipped_weapon_id
	equipped_shield_id = _hero_snapshot.equipped_shield_id
	effects = {
		"strength_bonus": _hero_snapshot.strength_bonus,
		"strength_phases": _hero_snapshot.strength_phases,
		"vitality_percent": _hero_snapshot.vitality_percent,
		"vitality_phases": _hero_snapshot.vitality_phases,
		"vision_bonus": _hero_snapshot.vision_bonus,
		"vision_phases": _hero_snapshot.vision_phases
	}


## Мощность оружия учитывается лишь для подходящего вида атаки.
## Монстры атакуют природными приёмами: их база — характеристики + эффект.
func weapon_damage(kind: int) -> int:
	if _hero_snapshot != null:
		return _equipment.weapon_damage(kind)
	var weapon: ItemDefinition = ItemCatalog.get_item(equipped_weapon_id) if not equipped_weapon_id.is_empty() else null
	return weapon.weapon_damage if weapon != null and weapon.equipment_slot == ItemDefinition.EquipmentSlot.WEAPON and weapon.weapon_kind == kind else 0


func melee_attack_value(include_equipment: bool = true) -> float:
	var item_damage: int = weapon_damage(ItemDefinition.WeaponKind.MELEE) if include_equipment else 0
	return BattleMath.melee_power(item_damage, int(effects.get("strength_bonus", 0)) if int(effects.get("strength_phases", 0)) > 0 else 0, effective_strength())


func ranged_attack_value(include_equipment: bool = true) -> float:
	var item_damage: int = weapon_damage(ItemDefinition.WeaponKind.RANGED) if include_equipment else 0
	return BattleMath.ranged_power(item_damage, int(effects.get("strength_bonus", 0)) if int(effects.get("strength_phases", 0)) > 0 else 0, effective_agility())


func melee_attack() -> int:
	return int(CharacterStats.participant_values(self)["melee_attack"])


func ranged_attack() -> int:
	return int(CharacterStats.participant_values(self)["ranged_attack"])


func sync_consumable_from_hero(source: HeroState) -> void:
	## В любой разрешённой паузе источник правды для зелья — GameSession.hero.
	## Заменяем только копию HeroState, сохраняя курсор, статусы и бонус блока.
	if source == null or _hero_snapshot == null:
		return
	_hero_snapshot = source.copy_for_battle()
	_equipment.set_snapshot(_hero_snapshot)
	refresh_from_hero()
	_sync_status_health_limit(false)


func prepare_block(base_armor: int) -> void:
	# Блок доступен без щита. С щитом используем ЕГО броню, а не сумму
	# с базовой; остаток прочности влияет только на последующие удары.
	block_armor = preview_block_armor(base_armor)
	for status_id in statuses.keys():
		if int((statuses[status_id] as Dictionary).get("next_block_penalty", 0)) > 0:
			remove_status(str(status_id))
	block_attack_bonus_percent += BattleMath.RULES.block_attack_bonus_percent


func preview_block_armor(base_armor: int = BattleMath.USE_DEFAULT_BLOCK_ARMOR) -> int:
	var requested: int = BattleMath.RULES.unarmed_block_armor if base_armor == BattleMath.USE_DEFAULT_BLOCK_ARMOR else base_armor
	var armor: int = _equipment.block_armor(equipped_shield_id, maxi(BattleMath.RULES.unarmed_block_armor, requested))
	for status in statuses.values():
		armor -= int(status.get("next_block_penalty", 0))
	if is_fury_unleashed():
		armor -= fury_rules.block_penalty
	return maxi(armor, 0)


func has_serviceable_shield() -> bool:
	return _equipment.has_shield(equipped_shield_id)


func shield_durability(shield_id: String) -> int:
	return _equipment.shield_durability(shield_id)


func restore_health(amount: int) -> int:
	if _hero_snapshot != null:
		var healed: int = _hero_snapshot.restore_health(amount)
		refresh_from_hero()
		return healed
	var healed: int = mini(maxi(amount, 0), maxi(max_health - health, 0))
	health += healed
	return healed


func receive_damage(incoming: int, armor_pierce_fraction: float = 0.0) -> int:
	last_shield_blocked = 0
	last_block_absorbed = 0
	last_shield_broken = ""
	if _hero_snapshot != null:
		_hero_snapshot.last_shield_broken = ""
	var raw: int = maxi(incoming, 0)
	var absorbed_barrier: int = mini(raw, energy_barrier_hp)
	energy_barrier_hp -= absorbed_barrier
	raw -= absorbed_barrier
	# Пробитие обходит пассивную броню и активный блок.
	var pierced: int = ceili(float(raw) * clampf(armor_pierce_fraction, 0.0, 1.0))
	var armor_after_base: int = raw - pierced
	armor_after_base -= BattleMath.passive_armor_absorption(armor_after_base, effective_defense())
	var requested_block: int = mini(armor_after_base, block_armor)
	var absorption: Dictionary = _equipment.absorb(equipped_shield_id, armor_after_base, requested_block)
	var blocked: int = int(absorption["blocked"])
	last_shield_blocked = int(absorption["shield_blocked"])
	last_shield_broken = str(absorption["broken"])
	# Показываем поглощение и монстру без физического щита.
	last_block_absorbed = blocked
	# Блок защищает от одного попадания, даже если оно было нулевым.
	block_armor = 0
	if _hero_snapshot != null:
		var taken: int = _hero_snapshot.take_damage(pierced + armor_after_base - blocked, false)
		refresh_from_hero()
		if taken > 0:
			energy_meditation_pending = 0
		return taken
	var taken: int = pierced + maxi(armor_after_base - blocked, 0)
	if is_fury_unleashed():
		taken = floori(float(taken) * (1.0 + fury_rules.incoming_health_bonus))
	health = maxi(health - taken, 0)
	if taken > 0:
		energy_meditation_pending = 0
	return taken


func fury() -> int:
	return int(resource_amounts.get("fury", 0))


func is_fury_unleashed() -> bool:
	return fury_rules != null and fury() >= fury_rules.maximum


func gain_fury(amount: int) -> void:
	if fury_rules == null or amount <= 0 or not is_alive():
		return
	var gained: int = mini(amount, mini(fury_rules.maximum - fury(), maxi(fury_rules.round_gain_cap - fury_gained_this_round, 0)))
	resource_amounts["fury"] = fury() + gained
	fury_gained_this_round += gained


func spend_fury(amount: int) -> void:
	if fury_rules != null:
		resource_amounts["fury"] = maxi(fury() - amount, 0)


func energy_display_text() -> String:
	var text: String = "Энергия %d/%d" % [current_energy(), max_energy]
	if fury_rules != null:
		text += "\nБезумие %d/%d" % [fury(), fury_rules.maximum]
		if is_fury_unleashed():
			text += " · Срыв"
	return text


func current_energy() -> int:
	return int(resource_amounts.get("energy", 0))


func change_energy(delta: int) -> int:
	var previous: int = current_energy()
	var next: int = mini(previous + delta, max_energy)
	resource_amounts["energy"] = next
	return next - previous


func energy_factor() -> float:
	return CharacterStats.energy_factor(current_energy(), max_energy)


func effective_strength() -> int:
	return int(CharacterStats.participant_values(self)["strength"])


func effective_defense() -> int:
	return int(CharacterStats.participant_values(self)["defense"])


func energy_debt_damage() -> int:
	if current_energy() >= 0:
		return 0
	var damage: int = ceili(float(-current_energy()) * BattleMath.RULES.energy_debt_hp_factor)
	if _hero_snapshot != null:
		_hero_snapshot.health = maxi(_hero_snapshot.health - damage, 0)
		refresh_from_hero()
	else:
		health = maxi(health - damage, 0)
	return damage


## Все значения в процентных пунктах. Фактическое уклонение зависит от противника.
func effective_agility() -> int:
	return int(CharacterStats.participant_values(self)["agility"])


func dodge_percent() -> int:
	return int(CharacterStats.participant_values(self)["dodge_percent"])


func accuracy_percent() -> int:
	return int(CharacterStats.participant_values(self)["accuracy_percent"]) - PERCENT_SCALE


func dodge_chance_against(attacker: BattleParticipant) -> int:
	return clampi(dodge_percent() - (attacker.accuracy_percent() if attacker != null else 0), 0, PERCENT_SCALE)


func status_modifier(stat: int) -> int:
	return BattleStatusRules.modifier(statuses, stat)


func apply_status(effect: AbilityEffectDefinition, tick: int) -> void:
	var partial_phase: bool = not effect.full_owner_turns and not is_resting and action_cursor > 0
	BattleStatusRules.apply(statuses, effect, tick, partial_phase)
	_sync_status_health_limit(false)


func remove_status(status_id: String) -> bool:
	if not statuses.has(status_id):
		return false
	statuses.erase(status_id)
	_sync_status_health_limit(true)
	return true


func has_damaged_armor() -> bool:
	return _equipment.has_damaged_shield(equipped_shield_id)


## Кровотечение обходит блок: в этот момент это не атака противника.
## Возвращаем фактические снимки HP для последовательного воспроизведения.
func owner_phase_status_damage_events(actor_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for entry in BattleStatusRules.ticking_entries(statuses, AbilityEffectDefinition.Clock.OWNER_PHASE):
		var before: int = health
		var amount: int = int(entry["damage"])
		if _hero_snapshot != null:
			_hero_snapshot.health = maxi(_hero_snapshot.health - amount, 0)
			refresh_from_hero()
		else:
			health = maxi(health - amount, 0)
		events.append({"type": "status_tick", "actor_id": actor_id,
			"target_id": actor_id, "status_id": str(entry["status_id"]), "damage": before - health,
			"hp_after": health, "hp_max": max_health})
		if not is_alive():
			break
	return events


func advance_status_clock(clock: int, current_tick: int = -1) -> Array[String]:
	var expired: Array[String] = BattleStatusRules.advance(statuses, clock, current_tick)
	_sync_status_health_limit(true)
	return expired


func _sync_status_health_limit(restore_on_expiration: bool) -> void:
	if _base_max_health <= 0:
		return
	var old_maximum: int = max_health
	var adjusted: int = BattleStatusRules.health_limit(_base_max_health, statuses)
	if adjusted == old_maximum:
		health = mini(health, adjusted)
		if _hero_snapshot != null:
			_hero_snapshot.health = health
			_hero_snapshot.overworld_statuses = statuses.duplicate(true)
		return
	var next_health: int = health
	if restore_on_expiration and adjusted > old_maximum and health > 0:
		next_health += adjusted - old_maximum
	max_health = adjusted
	health = mini(next_health, max_health)
	if _hero_snapshot != null:
		_hero_snapshot.health = health
		_hero_snapshot.overworld_statuses = statuses.duplicate(true)


func advance_consumable_phase() -> void:
	if _hero_snapshot != null:
		_hero_snapshot.advance_phase_effects()
		refresh_from_hero()


func end_phase() -> void:
	# Бонус блока и активный блок живут до следующего соответствующего удара,
	# даже если между действиями была перезарядка или граница фазы.
	advance_status_clock(AbilityEffectDefinition.Clock.LEGACY_HERO_PHASE)


func is_alive() -> bool:
	return health > 0


func commit_hero_result(destination: HeroState) -> void:
	if destination != null and _hero_snapshot != null:
		var persistent: Dictionary = statuses.duplicate(true)
		for status_id in persistent.keys():
			if bool(persistent[status_id].get("battle_only", false)):
				persistent.erase(status_id)
		_hero_snapshot.overworld_statuses = persistent
		_hero_snapshot.energy = current_energy()
		destination.apply_battle_result(_hero_snapshot)

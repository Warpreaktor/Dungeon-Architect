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
## Для совпадения наложения статуса и отдыха в одном такте.
var last_rest_tick: int = -1
## Неиспользуемые пока в контенте запасы будущих ресурсов (ярость, мана и т.д.).
## Это изменяемые данные конкретного участника боя, не .tres.
var resource_amounts: Dictionary = {}
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
	participant.statuses = participant._hero_snapshot.overworld_statuses.duplicate(true)
	participant._equipment.set_snapshot(participant._hero_snapshot)
	participant.personal_ability_ids = source.definition.personal_ability_ids.duplicate() if source.definition != null else []
	participant.base_dodge_percent = source.definition.base_dodge_percent if source.definition != null else 0
	participant.accuracy_bonus = source.definition.accuracy_bonus if source.definition != null else 0
	participant.learned_ability_ids = source.learned_ability_ids.duplicate()
	participant.action_slot_capacity = source.action_slot_capacity()
	participant.refresh_from_hero()
	return participant


static func from_monster(source: MonsterDefinition, id: String = "enemy") -> BattleParticipant:
	if source == null:
		return null
	var participant := BattleParticipant.new()
	participant.participant_id = id
	participant.team_id = "enemies"
	participant.definition_id = source.monster_id
	participant.max_health = source.max_health
	participant.health = source.max_health
	participant.strength = source.strength
	participant.agility = source.agility
	participant.defense = 0 # Passive armor is not implemented yet.
	participant.base_dodge_percent = source.base_dodge_percent
	participant.accuracy_bonus = source.accuracy_bonus
	participant.personal_ability_ids = source.personal_ability_ids.duplicate()
	for action in source.intermission_actions:
		if action != null and not participant.learned_ability_ids.has(action.ability_id):
			participant.learned_ability_ids.append(action.ability_id)
	participant.resource_amounts = source.starting_resources.duplicate(true)
	participant.action_slot_capacity = clampi(source.base_action_slots, 1, BattleChainPlanner.MAX_ACTIONS)
	return participant


func refresh_from_hero() -> void:
	if _hero_snapshot == null:
		return
	_equipment.set_snapshot(_hero_snapshot)
	max_health = _hero_snapshot.max_health
	health = _hero_snapshot.health
	strength = _hero_snapshot.strength
	agility = _hero_snapshot.agility
	defense = 0 # Shield/weapon equipment is not passive blocking.
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
	return _equipment.weapon_damage(kind)


func melee_attack_value() -> float:
	return BattleMath.melee_power(weapon_damage(ItemDefinition.WeaponKind.MELEE), int(effects.get("strength_bonus", 0)), strength)


func ranged_attack_value() -> float:
	return BattleMath.ranged_power(weapon_damage(ItemDefinition.WeaponKind.RANGED), int(effects.get("strength_bonus", 0)), effective_agility())


func melee_attack() -> int:
	return floori(melee_attack_value())


func ranged_attack() -> int:
	return floori(ranged_attack_value())


func sync_consumable_from_hero(source: HeroState) -> void:
	## В любой разрешённой паузе источник правды для зелья — GameSession.hero.
	## Заменяем только копию HeroState, сохраняя курсор, статусы и бонус блока.
	if source == null or _hero_snapshot == null:
		return
	_hero_snapshot = source.copy_for_battle()
	_equipment.set_snapshot(_hero_snapshot)
	refresh_from_hero()


func prepare_block(base_armor: int) -> void:
	# Блок доступен без щита. С щитом используем ЕГО броню, а не сумму
	# с базовой; остаток прочности влияет только на последующие удары.
	block_armor = preview_block_armor(base_armor)
	block_attack_bonus_percent += BattleMath.RULES.block_attack_bonus_percent


func preview_block_armor(base_armor: int = BattleMath.USE_DEFAULT_BLOCK_ARMOR) -> int:
	var requested: int = BattleMath.RULES.unarmed_block_armor if base_armor == BattleMath.USE_DEFAULT_BLOCK_ARMOR else base_armor
	return _equipment.block_armor(equipped_shield_id, maxi(BattleMath.RULES.unarmed_block_armor, requested))


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
	# Расщепляем повреждение ДО активного блока. Пока отдельной брони нет.
	# ceili обеспечивает минимум 1 пробивающего урона при ненулевом пробитии.
	var pierced: int = ceili(float(raw) * clampf(armor_pierce_fraction, 0.0, 1.0))
	var armor_after_base: int = maxi(raw - pierced, 0)
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
		var taken: int = _hero_snapshot.take_damage(pierced + armor_after_base - blocked)
		refresh_from_hero()
		return taken
	var taken: int = pierced + maxi(armor_after_base - blocked, 0)
	health = maxi(health - taken, 0)
	return taken


## Все значения в процентных пунктах. Фактическое уклонение зависит от противника.
func effective_agility() -> int:
	return maxi(agility + status_modifier(AbilityEffectDefinition.Stat.AGILITY), 0)


func dodge_percent() -> int:
	# Не обрезаем до 100 до вычитания меткости: её бонусы могут
	# противодействовать даже суммарному уклонению свыше 100%.
	return maxi(base_dodge_percent + effective_agility()
		+ status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT), 0)


func accuracy_percent() -> int:
	return BattleMath.accuracy_total(
		effective_agility(), accuracy_bonus, status_modifier(AbilityEffectDefinition.Stat.ACCURACY)
	) - PERCENT_SCALE


func dodge_chance_against(attacker: BattleParticipant) -> int:
	return clampi(dodge_percent() - (attacker.accuracy_percent() if attacker != null else 0), 0, PERCENT_SCALE)


func status_modifier(stat: int) -> int:
	return BattleStatusRules.modifier(statuses, stat)


func apply_status(effect: AbilityEffectDefinition, tick: int) -> void:
	var partial_phase: bool = not is_resting and action_cursor > 0
	BattleStatusRules.apply(statuses, effect, tick, partial_phase)


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
	return BattleStatusRules.advance(statuses, clock, current_tick)


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
		_hero_snapshot.overworld_statuses = statuses.duplicate(true)
		destination.apply_battle_result(_hero_snapshot)

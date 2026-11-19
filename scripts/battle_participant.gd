class_name BattleParticipant
extends RefCounted

## Снимок одного участника боя. Ресурсы героя и монстра не изменяются.
## ID участника не зависит от того, каким портретом он отображается.
var participant_id: String = ""
var definition_id: String = ""
var team_id: String = ""
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
const BASE_BLOCK_ARMOR: int = 2
## Одна сотня процентов является определением процентной шкалы, не балансом.
const PERCENT_SCALE: int = 100

# Для совместимости существующих щитов их логика пока выполняется на
# изолированной копии HeroState, а не на реальном герое прохождения.
var _hero_snapshot: HeroState


static func from_hero(source: HeroState, id: String = "hero") -> BattleParticipant:
	if source == null:
		return null
	var participant := BattleParticipant.new()
	participant.participant_id = id
	participant.team_id = "heroes"
	participant.definition_id = source.definition.hero_id if source.definition != null else ""
	participant._hero_snapshot = source.copy_for_battle()
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
	participant.action_slot_capacity = clampi(source.base_action_slots, 1, BattleChainPlanner.MAX_ACTIONS)
	return participant


func refresh_from_hero() -> void:
	if _hero_snapshot == null:
		return
	max_health = _hero_snapshot.max_health
	health = _hero_snapshot.health
	strength = _hero_snapshot.strength
	agility = _hero_snapshot.agility
	defense = 0 # Shield/weapon equipment is not passive blocking.
	equipped_weapon_id = _hero_snapshot.equipped_weapon_id
	equipped_shield_id = _hero_snapshot.equipped_shield_id
	effects = {
		"strength_bonus": _hero_snapshot.strength_bonus,
		"strength_steps": _hero_snapshot.strength_steps,
		"vitality_percent": _hero_snapshot.vitality_percent,
		"vitality_steps": _hero_snapshot.vitality_steps,
		"vision_bonus": _hero_snapshot.vision_bonus,
		"vision_steps": _hero_snapshot.vision_steps
	}


## Мощность оружия учитывается лишь для подходящего вида атаки.
## Монстры атакуют природными приёмами: их база — характеристики + эффект.
func weapon_damage(kind: int) -> int:
	return _hero_snapshot.weapon_damage(kind) if _hero_snapshot != null else 0


func melee_attack_value() -> float:
	return float(weapon_damage(ItemDefinition.WeaponKind.MELEE) + int(effects.get("strength_bonus", 0))) + float(maxi(strength, 0)) * 0.5


func ranged_attack_value() -> float:
	return float(weapon_damage(ItemDefinition.WeaponKind.RANGED) + int(effects.get("strength_bonus", 0))) + float(maxi(agility + status_modifier(AbilityEffectDefinition.Stat.AGILITY), 0)) * 0.5


func melee_attack() -> int:
	return floori(melee_attack_value())


func ranged_attack() -> int:
	return floori(ranged_attack_value())


func sync_consumable_from_hero(source: HeroState) -> void:
	## В межфазной паузе источник правды для зелья — GameSession.hero.
	## Заменяем только копию HeroState, сохраняя курсор, статусы и бонус блока.
	if source == null or _hero_snapshot == null:
		return
	_hero_snapshot = source.copy_for_battle()
	refresh_from_hero()


func prepare_block(base_armor: int) -> void:
	# Блок доступен без щита. С щитом используем ЕГО броню, а не сумму
	# с базовой; остаток прочности влияет только на последующие удары.
	block_armor = preview_block_armor(base_armor)
	block_attack_bonus_percent += 25


func preview_block_armor(base_armor: int = BASE_BLOCK_ARMOR) -> int:
	var shield: ItemDefinition = ItemCatalog.get_item(equipped_shield_id)
	if shield != null and _hero_snapshot != null and _hero_snapshot.current_shield_durability(equipped_shield_id) > 0:
		return maxi(shield.defense_bonus, 0)
	return maxi(BASE_BLOCK_ARMOR, base_armor)


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
	var active_shield: bool = (_hero_snapshot != null
		and not equipped_shield_id.is_empty()
		and _hero_snapshot.current_shield_durability(equipped_shield_id) > 0)
	# Пассивного блока нет. Щит лишь задаёт силу выполненного блока.
	var extra_armor: int = block_armor
	var blocked: int = mini(armor_after_base, extra_armor)
	if blocked > 0 and active_shield:
		# Износ от всей силы удара по щиту, не только от поглощённых HP.
		blocked = _hero_snapshot.consume_shield_block(armor_after_base, blocked)
		last_shield_blocked = blocked
		last_shield_broken = _hero_snapshot.last_shield_broken
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
	# Основные 100% попадания не входят в бонус меткости.
	return maxi(PERCENT_SCALE + effective_agility() + accuracy_bonus + status_modifier(AbilityEffectDefinition.Stat.ACCURACY), 0) - PERCENT_SCALE


func dodge_chance_against(attacker: BattleParticipant) -> int:
	return clampi(dodge_percent() - (attacker.accuracy_percent() if attacker != null else 0), 0, PERCENT_SCALE)


func status_modifier(stat: int) -> int:
	var total: int = 0
	for active in statuses.values():
		if int(active.get("stat", AbilityEffectDefinition.Stat.NONE)) == stat:
			total += int(active.get("modifier", 0)) * int(active.get("stacks", 1))
	return total


func apply_status(effect: AbilityEffectDefinition, tick: int) -> void:
	var previous: Dictionary = statuses.get(effect.status_id, {})
	var stacks: int = 1
	if effect.effective_stack_policy() == AbilityEffectDefinition.Stack.ADD:
		stacks = int(previous.get("stacks", 0)) + 1
	elif effect.effective_stack_policy() == AbilityEffectDefinition.Stack.ONCE and not previous.is_empty():
		# Multiple uses of the same non-stacking dodge grant no extra chance.
		return
	statuses[effect.status_id] = {
		"amount": effect.amount, "modifier": effect.effective_status_modifier(),
		"stat": effect.effective_status_stat(), "clock": effect.effective_status_clock(),
		"ticks": effect.duration_ticks, "stacks": stacks, "applied_tick": tick,
		"tick_damage": effect.tick_damage,
		# A partly completed current cycle is not a full phase of this effect.
		"skip_partial_phase": effect.tick_damage <= 0
			and effect.effective_status_clock() == AbilityEffectDefinition.Clock.OWNER_PHASE
			and not is_resting and action_cursor > 0
	}


func has_damaged_armor() -> bool:
	if _hero_snapshot == null or equipped_shield_id.is_empty():
		return false
	var shield: ItemDefinition = ItemCatalog.get_item(equipped_shield_id)
	if shield == null:
		return false
	var full: int = maxi(shield.max_durability, shield.defense_bonus)
	var remaining: int = _hero_snapshot.current_shield_durability(equipped_shield_id)
	return remaining > 0 and remaining < full


## Кровотечение обходит блок: в этот момент это не атака противника.
## Возвращаем фактические снимки HP для последовательного воспроизведения.
func owner_phase_status_damage_events(actor_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for status_id in statuses.keys():
		var status: Dictionary = statuses[status_id]
		if int(status.get("clock", -1)) != AbilityEffectDefinition.Clock.OWNER_PHASE:
			continue
		if bool(status.get("skip_partial_phase", false)):
			continue
		var amount: int = int(status.get("tick_damage", 0)) * maxi(int(status.get("stacks", 1)), 1)
		if amount <= 0:
			continue
		var before: int = health
		if _hero_snapshot != null:
			_hero_snapshot.health = maxi(_hero_snapshot.health - amount, 0)
			refresh_from_hero()
		else:
			health = maxi(health - amount, 0)
		events.append({"type": "status_tick", "actor_id": actor_id,
			"target_id": actor_id, "status_id": str(status_id), "damage": before - health,
			"hp_after": health, "hp_max": max_health})
		if not is_alive():
			break
	return events


func advance_status_clock(clock: int, current_tick: int = -1) -> Array[String]:
	var expired: Array[String] = []
	for status_id in statuses.keys():
		var status: Dictionary = statuses[status_id]
		if int(status.get("clock", AbilityEffectDefinition.Clock.LEGACY_HERO_PHASE)) != clock:
			continue
		# Периодический урон начинается с первого отдыха, даже если
		# кровь была наложена в том же самом такте.
		if current_tick >= 0 and int(status.get("applied_tick", -1)) == current_tick and int(status.get("tick_damage", 0)) <= 0:
			continue
		if clock == AbilityEffectDefinition.Clock.OWNER_PHASE and bool(status.get("skip_partial_phase", false)):
			status["skip_partial_phase"] = false
			statuses[status_id] = status
			continue
		status["ticks"] = int(status.get("ticks", 0)) - 1
		if int(status["ticks"]) <= 0:
			statuses.erase(status_id)
			expired.append(str(status_id))
		else:
			statuses[status_id] = status
	return expired


func end_phase() -> void:
	# Бонус +25% и активный блок живут до следующего соответствующего удара,
	# даже если между действиями была перезарядка или граница фазы.
	advance_status_clock(AbilityEffectDefinition.Clock.LEGACY_HERO_PHASE)


func is_alive() -> bool:
	return health > 0


func commit_hero_result(destination: HeroState) -> void:
	if destination != null and _hero_snapshot != null:
		destination.apply_battle_result(_hero_snapshot)

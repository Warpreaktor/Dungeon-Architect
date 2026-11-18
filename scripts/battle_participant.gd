class_name BattleParticipant
extends RefCounted

## Снимок одного участника боя. Ресурсы героя и монстра не изменяются.
## ID участника не зависит от того, каким портретом он отображается.
var participant_id: String = ""
var definition_id: String = ""
var team_id: String = ""
var max_health: int = 0
var health: int = 0
var attack: int = 0
var defense: int = 0
var equipped_weapon_id: String = ""
var equipped_shield_id: String = ""
var effects: Dictionary = {}
var personal_ability_ids: Array[String] = []
var learned_ability_ids: Array[String] = []
var action_chain: Array[String] = []
## Ограничение участника, независимое от глобального защитного MAX_ACTIONS.
var action_slot_capacity: int = 3
var tactic_changes_remaining: int = 0
# Броня блока действует только на следующее попадание.
var block_armor: int = 0
var block_attack_bonus_percent: int = 0
var last_shield_blocked: int = 0
var last_shield_broken: String = ""
var statuses: Dictionary = {}

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
	participant.attack = source.attack_damage
	participant.defense = source.defense
	participant.personal_ability_ids = source.personal_ability_ids.duplicate()
	participant.action_slot_capacity = clampi(source.base_action_slots, 1, BattleChainPlanner.MAX_ACTIONS)
	return participant


func refresh_from_hero() -> void:
	if _hero_snapshot == null:
		return
	max_health = _hero_snapshot.max_health
	health = _hero_snapshot.health
	attack = _hero_snapshot.attack
	defense = _hero_snapshot.defense
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


func prepare_block(base_armor: int) -> void:
	# Надетый щит даёт броню лишь при выполнении приёма «Блок».
	var shield: ItemDefinition = ItemCatalog.get_item(equipped_shield_id)
	if shield != null and _hero_snapshot != null and _hero_snapshot.current_shield_durability(equipped_shield_id) > 0:
		block_armor = maxi(shield.defense_bonus, 0)
	else:
		block_armor = maxi(base_armor, 0)
	block_attack_bonus_percent += 25


func restore_health(amount: int) -> int:
	if _hero_snapshot != null:
		var healed: int = _hero_snapshot.restore_health(amount)
		refresh_from_hero()
		return healed
	var healed: int = mini(maxi(amount, 0), maxi(max_health - health, 0))
	health += healed
	return healed


func receive_damage(incoming: int) -> int:
	last_shield_blocked = 0
	last_shield_broken = ""
	if _hero_snapshot != null:
		_hero_snapshot.last_shield_broken = ""
	var raw: int = maxi(incoming, 0)
	var armor_after_base: int = maxi(raw - (_hero_snapshot.base_defense if _hero_snapshot != null else defense), 0)
	var blocked: int = mini(armor_after_base, block_armor)
	if blocked > 0 and _hero_snapshot != null and not equipped_shield_id.is_empty():
		blocked = _hero_snapshot.consume_shield_block(blocked)
		last_shield_blocked = blocked
		last_shield_broken = _hero_snapshot.last_shield_broken
	# Блок защищает от одного попадания, даже если оно было нулевым.
	block_armor = 0
	if _hero_snapshot != null:
		var taken: int = _hero_snapshot.take_damage(raw - blocked)
		refresh_from_hero()
		return taken
	var taken: int = maxi(armor_after_base - blocked, 0)
	health = maxi(health - taken, 0)
	return taken


func end_phase() -> void:
	block_attack_bonus_percent = 0
	block_armor = 0
	for status_id in statuses.keys():
		var status: Dictionary = statuses[status_id]
		status["ticks"] = int(status.get("ticks", 0)) - 1
		if int(status["ticks"]) <= 0:
			statuses.erase(status_id)
		else:
			statuses[status_id] = status


func is_alive() -> bool:
	return health > 0


func commit_hero_result(destination: HeroState) -> void:
	if destination != null and _hero_snapshot != null:
		destination.apply_battle_result(_hero_snapshot)

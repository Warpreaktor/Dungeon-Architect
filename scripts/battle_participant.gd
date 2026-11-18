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
var tactic_changes_remaining: int = 0

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


func receive_damage(incoming: int) -> int:
	if _hero_snapshot != null:
		var taken: int = _hero_snapshot.take_damage(incoming)
		refresh_from_hero()
		return taken
	var taken := maxi(incoming - defense, 0)
	health = maxi(health - taken, 0)
	return taken


func is_alive() -> bool:
	return health > 0


func commit_hero_result(destination: HeroState) -> void:
	if destination != null and _hero_snapshot != null:
		destination.apply_battle_result(_hero_snapshot)

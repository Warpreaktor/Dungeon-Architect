class_name AbilityIconCatalog
extends RefCounted

const STYLE_DIRECTORY: String = "res://assets/abilities/frames"
const ATTACK_ART: Texture2D = preload("res://assets/icons/stats/24x24/attack.png")
const DEFENSE_ART: Texture2D = preload("res://assets/icons/stats/24x24/defense.png")
const SUPPORT_ART: Texture2D = preload("res://assets/icons/stats/24x24/health.png")

const ICON_PATHS := {
	"volcha_wolf_lunge": "res://assets/abilities/volcha/wolf_lunge.png",
	"volcha_strike_and_rebound": "res://assets/abilities/volcha/strike_and_rebound.png",
	"volcha_wolf_instinct": "res://assets/abilities/volcha/wolf_instinct.png",
	"volcha_broken_rhythm": "res://assets/abilities/volcha/broken_rhythm.png",
	"volcha_cut_tendons": "res://assets/abilities/volcha/cut_tendons.png",

	"petushan_peck_while_hot": "res://assets/abilities/petushan/peck_while_hot.png",
	"petushan_not_in_brow_but_eye": "res://assets/abilities/petushan/not_in_brow_but_eye.png",
	"petushan_spur_under_rib": "res://assets/abilities/petushan/spur_under_rib.png",
	"petushan_feathers_up": "res://assets/abilities/petushan/feathers_up.png",
	"petushan_rooster_whirlwind": "res://assets/abilities/petushan/rooster_whirlwind.png",
	"petushan_battle_cry": "res://assets/abilities/petushan/battle_cry.png",
	"petushan_chest_charge": "res://assets/abilities/petushan/chest_charge.png",
	"petushan_red_comb": "res://assets/abilities/petushan/red_comb.png",
	"petushan_wrong_opponent": "res://assets/abilities/petushan/wrong_opponent.png",
	"petushan_last_crow": "res://assets/abilities/petushan/last_crow.png",

	"volcha_predator_response": "res://assets/abilities/volcha/predator_response.png",
	"volcha_find_weakness": "res://assets/abilities/volcha/find_weakness.png",
	"volcha_blade_dance": "res://assets/abilities/volcha/blade_dance.png",
	"volcha_hunting_instinct": "res://assets/abilities/volcha/hunting_instinct.png",
	"volcha_last_fang": "res://assets/abilities/volcha/last_fang.png"
}


static func has_icon(ability_id: String) -> bool:
	return ICON_PATHS.has(ability_id)


static func get_icon_path(ability_id: String) -> String:
	return str(ICON_PATHS.get(ability_id, ""))


static func get_icon(ability_id: String) -> Texture2D:
	var icon_path: String = get_icon_path(ability_id)
	if icon_path.is_empty():
		return null
	return load(icon_path) as Texture2D


static func art_for(ability: AbilityDefinition) -> Texture2D:
	if ability == null:
		return null
	if ability.icon_art != null:
		return ability.icon_art
	if ability.icon != null:
		return ability.icon
	match ability.category:
		AbilityDefinition.Category.DEFENSE:
			return DEFENSE_ART
		AbilityDefinition.Category.SUPPORT:
			return SUPPORT_ART
		_:
			return ATTACK_ART


static func style_for_actor(actor: BattleParticipant) -> AbilityIconStyle:
	if actor == null or actor.team_id != "enemies" or not MonsterCatalog.has(actor.definition_id):
		return null
	for style_id in ResourceCatalog.list_ids(STYLE_DIRECTORY):
		var style: AbilityIconStyle = ResourceCatalog.load_by_id(STYLE_DIRECTORY, style_id) as AbilityIconStyle
		if style != null and style.monster_ids.has(actor.definition_id):
			return style
	return null

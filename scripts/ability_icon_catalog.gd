class_name AbilityIconCatalog
extends RefCounted

# Каталог иконок боевых приёмов.
# Не хранит игровой баланс и не привязывает движок к конкретному герою —
# только отдаёт текстуру по ID способности.

const ICON_PATHS := {
	# Волча — утверждённые приёмы.
	"volcha_wolf_lunge": "res://assets/abilities/volcha/wolf_lunge.png",
	"volcha_strike_and_rebound": "res://assets/abilities/volcha/strike_and_rebound.png",
	"volcha_wolf_instinct": "res://assets/abilities/volcha/wolf_instinct.png",
	"volcha_broken_rhythm": "res://assets/abilities/volcha/broken_rhythm.png",
	"volcha_cut_tendons": "res://assets/abilities/volcha/cut_tendons.png",

	# Петушан: стартовый набор.
	"petushan_peck_while_hot": "res://assets/abilities/petushan/peck_while_hot.png",
	"petushan_not_in_brow_but_eye": "res://assets/abilities/petushan/not_in_brow_but_eye.png",
	"petushan_spur_under_rib": "res://assets/abilities/petushan/spur_under_rib.png",

	# Нарезанные запасные иконки Волчи на будущее.
	"volcha_extra_01": "res://assets/abilities/volcha/extra_01.png",
	"volcha_extra_02": "res://assets/abilities/volcha/extra_02.png",
	"volcha_extra_03": "res://assets/abilities/volcha/extra_03.png",
	"volcha_extra_04": "res://assets/abilities/volcha/extra_04.png",
	"volcha_extra_05": "res://assets/abilities/volcha/extra_05.png"
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

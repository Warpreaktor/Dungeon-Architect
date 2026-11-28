class_name HeroDefinition
extends Resource

## Параметры конкретного героя. Базовые значения можно менять в Inspector.
@export var hero_id: String = ""
@export var display_name: String = ""
@export var portrait: Texture2D
@export var map_icon: Texture2D
@export var map_sprite_frames: SpriteFrames
@export var map_rig_scene: PackedScene
@export var personal_ability_ids: Array[String] = []
@export_range(0, 128, 1, "or_greater") var unlocked_personal_ability_count: int = 1
@export var starting_weapon_id: String = ""
@export_range(0, 999, 1) var max_energy: int = 0
## Сколько действий в алгоритме доступно без артефактов и усилений.
@export_range(1, 8, 1) var base_action_slots: int = 3
@export_range(1, 999, 1) var max_health: int = 1
## Вклад Силы в ближнюю атаку задают общие боевые правила.
@export_range(0, 999, 1) var strength: int = 0
## Вклад Ловкости в дальнюю атаку задают общие боевые правила.
@export_range(0, 999, 1) var agility: int = 0
@export_range(0, 999, 1) var perception: int = 0
## Base probability of avoiding an incoming attack. Status bonuses add percentage points.
@export_range(0, 100, 1) var base_dodge_percent: int = 0
## Дополнительные очки меткости сверх вклада Ловкости.
@export_range(0, 999, 1) var accuracy_bonus: int = 0
@export_range(-1, 100, 1) var base_accuracy_percent: int = -1
## Base passive armor, independent of active blocking.
@export_range(0, 999, 1) var base_defense: int = 0


func is_personal_ability_locked(ability_id: String) -> bool:
	var index: int = personal_ability_ids.find(ability_id)
	return index >= 0 and index >= unlocked_personal_ability_count

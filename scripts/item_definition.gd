class_name ItemDefinition
extends Resource

## Статическое описание предмета; изменяемое количество хранится в игровой сессии.

enum Category { QUEST, CONSUMABLE, CURRENCY, EQUIPMENT }
enum EquipmentSlot { NONE, WEAPON, SHIELD }
enum WeaponKind { MELEE, RANGED }
enum ConsumableEffect { NONE, HEAL, ATTACK, RESIST, VISION }

@export var item_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category: Category = Category.QUEST
@export_range(1, 9999, 1) var default_quantity: int = 1
@export var stackable: bool = true
@export var equipment_slot: EquipmentSlot = EquipmentSlot.NONE
@export var two_handed: bool = false
## Собственный урон оружия, без скрытой атаки персонажа.
@export_range(0, 999, 1) var weapon_damage: int = 0
@export var weapon_kind: WeaponKind = WeaponKind.MELEE
@export var defense_bonus: int = 0
@export_range(0, 999, 1) var max_durability: int = 0
@export_range(0, 9999, 1) var healing_amount: int = 0
@export var consumable_effect: ConsumableEffect = ConsumableEffect.NONE
@export_range(0, 9999, 1) var effect_value: int = 0
@export_range(0, 9999, 1) var effect_duration_phases: int = 0


func get_description() -> String:
	var values: Dictionary = DescriptionTemplate.numeric_values(self)
	values["duration_phases"] = DescriptionTemplate.phases(effect_duration_phases)
	values["vision_cells"] = DescriptionTemplate.quantity(effect_value, "клетку", "клетки", "клеток")
	if item_id in LockCatalog.LOCK_IDS:
		values["lock_color"] = LockCatalog.label(item_id)
	return DescriptionTemplate.render(description, values)

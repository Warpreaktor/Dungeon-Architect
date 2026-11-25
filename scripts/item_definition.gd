class_name ItemDefinition
extends Resource

## Статическое описание предмета; изменяемое количество хранится в игровой сессии.

enum Category { QUEST, CONSUMABLE, CURRENCY, EQUIPMENT }
enum EquipmentSlot { NONE, WEAPON, SHIELD, HEAD, BODY, NECK, RING, BELT, GLOVES, BOOTS }
enum WeaponKind { MELEE, RANGED }
enum ConsumableEffect { NONE, HEAL, ATTACK, RESIST, VISION }

@export var item_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category: Category = Category.QUEST
@export_range(1, 9999, 1) var default_quantity: int = 1
@export var stackable: bool = true
@export_range(1, 9999, 1) var max_stack_size: int = 10
@export var equipment_slot: int = EquipmentSlot.NONE
@export var two_handed: bool = false
## Собственный урон оружия, без скрытой атаки персонажа.
@export_range(0, 999, 1) var weapon_damage: int = 0
@export var weapon_kind: WeaponKind = WeaponKind.MELEE
@export var monster_attack_icon: Texture2D
@export var defense_bonus: int = 0
@export var armor_bonus: int = 0
@export var health_bonus: int = 0
@export var strength_bonus: int = 0
@export var agility_bonus: int = 0
@export var perception_bonus: int = 0
@export var dodge_bonus_percent: int = 0
@export var accuracy_bonus_percent: int = 0
@export var poison_resistance_percent: int = 0
@export_range(0, 999, 1) var max_durability: int = 0
@export_range(0, 9999, 1) var healing_amount: int = 0
@export var consumable_effect: ConsumableEffect = ConsumableEffect.NONE
@export_range(0, 9999, 1) var effect_value: int = 0
@export_range(0, 9999, 1) var effect_duration_phases: int = 0


func stack_limit() -> int:
	return max_stack_size if stackable and category != Category.EQUIPMENT else 1


func get_description(instance: ItemInstance = null) -> String:
	var values: Dictionary = DescriptionTemplate.numeric_values(self)
	if instance != null:
		for field in ItemMagicCatalog.MODIFIER_FIELDS + ["max_durability"]:
			values[field] = ItemMagicCatalog.effective_value(self, instance, field)
	values["duration_phases"] = DescriptionTemplate.phases(effect_duration_phases)
	values["vision_cells"] = DescriptionTemplate.quantity(effect_value, "клетку", "клетки", "клеток")
	if item_id in LockCatalog.LOCK_IDS:
		values["lock_color"] = LockCatalog.label(item_id)
	var result: String = DescriptionTemplate.render(description, values)
	var equipment_stats: PackedStringArray = DescriptionTemplate.equipment_properties(self, instance)
	if not equipment_stats.is_empty():
		result += "\n" + "\n".join(equipment_stats)
	if instance != null:
		var affixes: PackedStringArray = ItemMagicCatalog.affix_lines(instance)
		if not affixes.is_empty():
			result += "\n" + ", ".join(affixes)
	return result

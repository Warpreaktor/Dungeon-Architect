class_name ItemDefinition
extends Resource

## Статическое описание предмета; изменяемое количество хранится в игровой сессии.

enum Category { QUEST, CONSUMABLE, CURRENCY, EQUIPMENT }
enum EquipmentSlot { NONE, WEAPON, SHIELD }
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
@export var attack_bonus: int = 0
@export var defense_bonus: int = 0
@export_range(0, 999, 1) var max_durability: int = 0
@export_range(0, 9999, 1) var healing_amount: int = 0
@export var consumable_effect: ConsumableEffect = ConsumableEffect.NONE
@export_range(0, 9999, 1) var effect_value: int = 0
@export_range(0, 9999, 1) var effect_duration_steps: int = 0

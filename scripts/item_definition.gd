class_name ItemDefinition
extends Resource

## Статическое описание предмета; изменяемое количество хранится в игровой сессии.

enum Category { QUEST, CONSUMABLE, CURRENCY, EQUIPMENT }

@export var item_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category: Category = Category.QUEST
@export_range(1, 9999, 1) var default_quantity: int = 1
@export var stackable: bool = true
@export var attack_bonus: int = 0
@export var defense_bonus: int = 0

class_name ItemCatalog
extends RefCounted

## Небольшой каталог ресурсов. Карта хранит только ID предмета и свойства размещения.

const DEFINITIONS := {
	"key": preload("res://items/key.tres"),
	"key_red": preload("res://items/key_red.tres"),
	"key_orange": preload("res://items/key_orange.tres"),
	"key_green": preload("res://items/key_green.tres"),
	"key_blue": preload("res://items/key_blue.tres"),
	"key_indigo": preload("res://items/key_indigo.tres"),
	"key_violet": preload("res://items/key_violet.tres"),

	"potion": preload("res://items/potion.tres"),
	"potion_health_small": preload("res://items/potion_health_small.tres"),
	"potion_health_medium": preload("res://items/potion_health_medium.tres"),
	"potion_health_large": preload("res://items/potion_health_large.tres"),
	"potion_strength_small": preload("res://items/potion_strength_small.tres"),
	"potion_strength_medium": preload("res://items/potion_strength_medium.tres"),
	"potion_strength_large": preload("res://items/potion_strength_large.tres"),
	"potion_vitality_small": preload("res://items/potion_vitality_small.tres"),
	"potion_vitality_medium": preload("res://items/potion_vitality_medium.tres"),
	"potion_vitality_large": preload("res://items/potion_vitality_large.tres"),
	"potion_vision_small": preload("res://items/potion_vision_small.tres"),
	"potion_vision_medium": preload("res://items/potion_vision_medium.tres"),
	"potion_vision_large": preload("res://items/potion_vision_large.tres"),
	"gold": preload("res://items/gold.tres"),
	"sword": preload("res://items/sword.tres"),
	"shield": preload("res://items/shield.tres"),
	"battle_axe": preload("res://items/battle_axe.tres"),
	"mace": preload("res://items/mace.tres"),
	"dagger": preload("res://items/dagger.tres"),
	"pickaxe": preload("res://items/pickaxe.tres"),
	"flail": preload("res://items/flail.tres"),
	"spear": preload("res://items/spear.tres"),
	"hatchet": preload("res://items/hatchet.tres"),
	"wooden_shield": preload("res://items/wooden_shield.tres"),
	"heraldic_shield": preload("res://items/heraldic_shield.tres"),
	"tower_shield": preload("res://items/tower_shield.tres"),
	"spiked_shield": preload("res://items/spiked_shield.tres"),
	"greatsword": preload("res://items/greatsword.tres"),
	"warhammer": preload("res://items/warhammer.tres"),
	"halberd": preload("res://items/halberd.tres")
}


static func get_item(item_id: String) -> ItemDefinition:
	return DEFINITIONS.get("key" if item_id == "key_yellow" else item_id) as ItemDefinition


static func quantity_for_entity(entity: Dictionary) -> int:
	var definition := get_item(str(entity.get("type", "")))
	if definition == null:
		return 0
	var properties: Dictionary = entity.get("properties", {})
	return maxi(1, int(properties.get("quantity", definition.default_quantity)))


## Одна награда на открытие; выпадение рассчитывается только в GameSession.
const RANDOM_LOOT_POOL := [
	"gold", "gold", "gold", "gold", "gold", "gold",
	"gold", "gold", "gold", "gold", "gold", "gold",
	"gold", "gold", "gold", "gold", "gold", "gold",
	"gold", "gold", "potion_health_small", "potion_health_small", "potion_health_small", "potion_health_small",
	"potion_health_small", "potion_health_small", "potion_health_medium", "potion_health_medium", "potion_health_medium", "potion_health_large",
	"potion_strength_small", "potion_strength_small", "potion_strength_small", "potion_strength_small", "potion_strength_small", "potion_strength_small",
	"potion_strength_medium", "potion_strength_medium", "potion_strength_medium", "potion_strength_large", "potion_vitality_small", "potion_vitality_small",
	"potion_vitality_small", "potion_vitality_small", "potion_vitality_small", "potion_vitality_small", "potion_vitality_medium", "potion_vitality_medium",
	"potion_vitality_medium", "potion_vitality_large", "potion_vision_small", "potion_vision_small", "potion_vision_small", "potion_vision_small",
	"potion_vision_small", "potion_vision_small", "potion_vision_medium", "potion_vision_medium", "potion_vision_medium", "potion_vision_large",
	"sword", "dagger", "hatchet", "spear", "mace", "pickaxe",
	"battle_axe", "flail", "greatsword", "warhammer", "halberd", "shield",
	"wooden_shield", "heraldic_shield", "tower_shield", "spiked_shield"
]
static func roll_loot() -> Dictionary:
	# Квестовые предметы не входят в случайную выдачу.
	var eligible: Array[String] = []
	for candidate in RANDOM_LOOT_POOL:
		var item: ItemDefinition = get_item(candidate)
		if item != null and item.category != ItemDefinition.Category.QUEST:
			eligible.append(candidate)
	if eligible.is_empty():
		return {}
	var item_id: String = eligible.pick_random()
	var definition: ItemDefinition = get_item(item_id)
	var quantity: int = randi_range(3, 12) if item_id == "gold" else definition.default_quantity
	return {"item_id": item_id, "quantity": quantity}

static func consumable_ids() -> Array[String]:
	var result: Array[String] = []
	for item_id in DEFINITIONS:
		var item: ItemDefinition = get_item(item_id)
		if item != null and item.category == ItemDefinition.Category.CONSUMABLE:
			result.append(item_id)
	result.sort()
	return result


static func equipment_ids() -> Array[String]:
	var result: Array[String] = []
	for item_id in DEFINITIONS:
		var item: ItemDefinition = get_item(item_id)
		if item != null and item.category == ItemDefinition.Category.EQUIPMENT:
			result.append(item_id)
	result.sort()
	return result

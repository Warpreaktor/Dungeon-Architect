class_name ItemCatalog
extends RefCounted

## Небольшой каталог ресурсов. Карта хранит только ID предмета и свойства размещения.

const DEFINITIONS := {
	"key": preload("res://items/key.tres"),
	"potion": preload("res://items/potion.tres"),
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
	return DEFINITIONS.get(item_id) as ItemDefinition


static func quantity_for_entity(entity: Dictionary) -> int:
	var definition := get_item(str(entity.get("type", "")))
	if definition == null:
		return 0
	var properties: Dictionary = entity.get("properties", {})
	return maxi(1, int(properties.get("quantity", definition.default_quantity)))


## Одна награда на открытие; выпадение рассчитывается только в GameSession.
const RANDOM_LOOT_POOL := [
	"gold", "gold", "gold", "potion",
	"sword", "dagger", "hatchet", "spear", "mace", "pickaxe",
	"battle_axe", "flail", "greatsword", "warhammer", "halberd", "shield", "wooden_shield", "heraldic_shield", "tower_shield", "spiked_shield"
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

static func equipment_ids() -> Array[String]:
	var result: Array[String] = []
	for item_id in DEFINITIONS:
		var item: ItemDefinition = get_item(item_id)
		if item != null and item.category == ItemDefinition.Category.EQUIPMENT:
			result.append(item_id)
	result.sort()
	return result

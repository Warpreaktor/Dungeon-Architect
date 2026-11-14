class_name ItemCatalog
extends RefCounted

## Небольшой каталог ресурсов. Карта хранит только ID предмета и свойства размещения.

const DEFINITIONS := {
	"key": preload("res://items/key.tres"),
	"potion": preload("res://items/potion.tres"),
	"gold": preload("res://items/gold.tres"),
	"sword": preload("res://items/sword.tres")
}


static func get_item(item_id: String) -> ItemDefinition:
	return DEFINITIONS.get(item_id) as ItemDefinition


static func quantity_for_entity(entity: Dictionary) -> int:
	var definition := get_item(str(entity.get("type", "")))
	if definition == null:
		return 0
	var properties: Dictionary = entity.get("properties", {})
	return maxi(1, int(properties.get("quantity", definition.default_quantity)))

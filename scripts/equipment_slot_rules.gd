class_name EquipmentSlotRules
extends RefCounted

const SLOT_IDS: Array[String] = [
	"head", "neck", "body", "main_hand", "off_hand", "ring_left", "ring_right", "belt", "gloves", "boots"
]
const LABELS: Dictionary = {
	"head": "Голова", "neck": "Шея", "body": "Броня", "main_hand": "Правая рука",
	"off_hand": "Левая рука", "ring_left": "Кольцо", "ring_right": "Кольцо",
	"belt": "Пояс", "gloves": "Перчатки", "boots": "Обувь"
}
const SYMBOLS: Dictionary = {
	"head": "♜", "neck": "◇", "body": "▣", "main_hand": "⚔", "off_hand": "⬡",
	"ring_left": "◯", "ring_right": "◯", "belt": "▰", "gloves": "✥", "boots": "⌑"
}

static func accepts(slot_id: String, item: ItemDefinition) -> bool:
	if item == null or item.category != ItemDefinition.Category.EQUIPMENT:
		return false
	match slot_id:
		"main_hand":
			return item.equipment_slot == ItemDefinition.EquipmentSlot.WEAPON
		"off_hand":
			return item.equipment_slot == ItemDefinition.EquipmentSlot.SHIELD
		"head":
			return item.equipment_slot == ItemDefinition.EquipmentSlot.HEAD
		"body":
			return item.equipment_slot == ItemDefinition.EquipmentSlot.BODY
		"neck":
			return item.equipment_slot == ItemDefinition.EquipmentSlot.NECK
		"ring_left", "ring_right":
			return item.equipment_slot == ItemDefinition.EquipmentSlot.RING
		"belt":
			return item.equipment_slot == ItemDefinition.EquipmentSlot.BELT
		"gloves":
			return item.equipment_slot == ItemDefinition.EquipmentSlot.GLOVES
		"boots":
			return item.equipment_slot == ItemDefinition.EquipmentSlot.BOOTS
	return false

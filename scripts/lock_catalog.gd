class_name LockCatalog
extends RefCounted

## Семь цветов. Старые ID key и key_yellow обозначают один жёлтый замок.
const LOCK_IDS: Array[String] = ["key_red", "key_orange", "key", "key_green", "key_blue", "key_indigo", "key_violet"]
const LABELS := {
    "key": "Жёлтый", "key_red": "Красный", "key_orange": "Оранжевый",
    "key_green": "Зелёный", "key_blue": "Голубой",
    "key_indigo": "Синий", "key_violet": "Фиолетовый"
}
const COLORS := {
    "key": Color("#f5d54b"), "key_red": Color("#e75151"),
    "key_orange": Color("#f59b37"), "key_green": Color("#56c875"), "key_blue": Color("#48a6f5"),
    "key_indigo": Color("#5266cb"), "key_violet": Color("#b879eb")
}

static func normalize(lock_id: String) -> String:
    return "key" if lock_id == "key_yellow" else (lock_id if lock_id in LOCK_IDS else "key")

static func required_key(door: Dictionary) -> String:
    var properties: Dictionary = door.get("properties", {})
    return normalize(str(properties.get("lock_id", "key")))

static func label(lock_id: String) -> String:
    return str(LABELS.get(normalize(lock_id), "Жёлтый"))

static func color(lock_id: String) -> Color:
    return COLORS.get(normalize(lock_id), Color("#f5d54b"))

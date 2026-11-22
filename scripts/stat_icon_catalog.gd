class_name StatIconCatalog
extends RefCounted

const ICONS: Dictionary = {
	"accuracy": preload("res://assets/icons/stats/24x24/accuracy.png"),
	"agility": preload("res://assets/icons/stats/24x24/agility.png"),
	"attack": preload("res://assets/icons/stats/24x24/attack.png"),
	"combat_slots": preload("res://assets/icons/stats/24x24/combat_slots.png"),
	"cooldown": preload("res://assets/icons/stats/24x24/cooldown.png"),
	"defense": preload("res://assets/icons/stats/24x24/defense.png"),
	"evasion": preload("res://assets/icons/stats/24x24/evasion.png"),
	"gold": preload("res://assets/icons/stats/24x24/gold.png"),
	"health": preload("res://assets/icons/stats/24x24/health.png"),
	"magic": preload("res://assets/icons/stats/24x24/magic.png"),
	"potion": preload("res://assets/icons/stats/24x24/potion.png"),
	"strength": preload("res://assets/icons/stats/24x24/strength.png")
}


static func icon(stat: String) -> Texture2D:
	return ICONS.get(stat) as Texture2D


static func add_icon(parent: Container, stat: String, side: float = 20.0) -> TextureRect:
	var image := TextureRect.new()
	image.texture = icon(stat)
	image.custom_minimum_size = Vector2(side, side)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

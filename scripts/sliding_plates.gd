class_name SlidingPlates
extends RefCounted

const TOOL := "sliding_plates"
const TRIGGER := "sliding_plates_trigger"
const WALLS_TOOL := "sliding_plates_walls"
const DUPLICATE_ERROR := "В подземелье уже установлен триггер сдвигающихся плит."
const CELL_ERROR := "Установочный триггер можно разместить только на пустой клетке пола."
const ICON_ART: Texture2D = preload("res://assets/icons/sliding_plates/sliding_plates.png")
const WALLS_TOOL_ART: Texture2D = preload("res://assets/icons/sliding_plates/walls_tool.png")
const TRIGGER_PLATE_ART: Texture2D = preload("res://assets/icons/sliding_plates/trigger_plate.png")
const DIRECTION_ARROW_ART: Texture2D = preload("res://assets/icons/sliding_plates/direction_arrow.png")
const FOUR_ARROWS_ART: Texture2D = preload("res://assets/icons/sliding_plates/four_arrows.png")

const DIRECTIONS := {"right": Vector2i.RIGHT, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "up": Vector2i.UP}
const TOGGLE := "toggle"
const MARK_CYCLE := ["right", "down", "left", "up", TOGGLE]
const MARK_CELL_ERROR := "Размечать можно только свободный пол или обычную стену."
const MARK_CONFLICT_ERROR := "Клетка уже участвует в другом изменении сдвигающихся плит."
const MARK_TARGET_ERROR := "Стена должна сдвигаться в соседнюю свободную клетку пола."
const MARK_TRIGGER_ERROR := "Сначала установите триггер сдвигающихся плит на этом этаже."
const MARK_RESERVED_ERROR := "Сначала удалите разметку сдвигающихся плит."


static func mark_cell(mark: Dictionary) -> Vector2i:
	return Vector2i(int(mark["x"]), int(mark["y"]))

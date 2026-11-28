class_name SlidingPlates
extends RefCounted

const TOOL := "sliding_plates"
const TRIGGER := "sliding_plates_trigger"
const WALLS_TOOL := "sliding_plates_walls"
const DUPLICATE_ERROR := "В подземелье уже установлен триггер сдвигающихся плит."
const CELL_ERROR := "Установочный триггер можно разместить только на пустой клетке пола."
const ICON_ART: Texture2D = preload("res://assets/icons/sliding_plates/sliding_plates.png")
const TRIGGER_TOOL_ART: Texture2D = preload("res://assets/icons/sliding_plates/trigger_tool.png")
const WALLS_TOOL_ART: Texture2D = preload("res://assets/icons/sliding_plates/walls_tool.png")
const TRIGGER_PLATE_ART: Texture2D = preload("res://assets/icons/sliding_plates/trigger_plate.png")
const DIRECTION_ARROW_ART: Texture2D = preload("res://assets/icons/sliding_plates/direction_arrow.png")
const FOUR_ARROWS_ART: Texture2D = preload("res://assets/icons/sliding_plates/four_arrows.png")

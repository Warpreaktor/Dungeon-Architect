class_name ChestContentsPopup
extends PopupPanel

## Небольшой редактор содержимого сундука. Ничего не знает о DungeonMap.
signal contents_changed(chest_id: String, contents: Array[String])

var _chest_id: String = ""

@onready var _key_check: CheckBox = %KeyCheck
@onready var _potion_check: CheckBox = %PotionCheck
@onready var _gold_check: CheckBox = %GoldCheck


func _ready() -> void:
	%SaveButton.pressed.connect(_save)
	%CancelButton.pressed.connect(hide)


func configure(chest_id: String, contents: Array[String]) -> void:
	_chest_id = chest_id
	_key_check.set_pressed_no_signal("key" in contents)
	_potion_check.set_pressed_no_signal("potion" in contents)
	_gold_check.set_pressed_no_signal("gold" in contents)


func _save() -> void:
	var contents: Array[String] = []
	if _key_check.button_pressed:
		contents.append("key")
	if _potion_check.button_pressed:
		contents.append("potion")
	if _gold_check.button_pressed:
		contents.append("gold")
	contents_changed.emit(_chest_id, contents)
	hide()

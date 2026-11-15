class_name ChestContentsPopup
extends PopupPanel

## Небольшой редактор содержимого сундука. Ничего не знает о DungeonMap.
signal contents_changed(chest_id: String, contents: Array[String], gold_amount: int)

var _chest_id: String = ""

@onready var _key_check: CheckBox = %KeyCheck
@onready var _potion_check: CheckBox = %PotionCheck
@onready var _gold_check: CheckBox = %GoldCheck
@onready var _gold_amount: SpinBox = %GoldAmount
@onready var _sword_check: CheckBox = %SwordCheck
@onready var _shield_check: CheckBox = %ShieldCheck
@onready var _title: Label = $ContentMargin/Content/Title
@onready var _description: Label = $ContentMargin/Content/Description


func _ready() -> void:
	%SaveButton.pressed.connect(_save)
	%CancelButton.pressed.connect(hide)
	_gold_check.toggled.connect(_on_gold_toggled)


func configure(chest_id: String, contents: Array[String], gold_amount: int = 5, is_monster: bool = false) -> void:
	_chest_id = chest_id
	_title.text = "Награда за победу" if is_monster else "Содержимое сундука"
	_description.visible = not is_monster
	_key_check.set_pressed_no_signal("key" in contents)
	_potion_check.set_pressed_no_signal("potion" in contents)
	_gold_check.set_pressed_no_signal("gold" in contents)
	_sword_check.set_pressed_no_signal("sword" in contents)
	_shield_check.set_pressed_no_signal("shield" in contents)
	_gold_amount.value = gold_amount
	_on_gold_toggled("gold" in contents)


func _on_gold_toggled(enabled: bool) -> void:
	_gold_amount.visible = enabled


func _save() -> void:
	_gold_amount.apply() # Сохранить число, даже если пользователь ещё редактирует поле.
	var contents: Array[String] = []
	if _key_check.button_pressed:
		contents.append("key")
	if _potion_check.button_pressed:
		contents.append("potion")
	if _gold_check.button_pressed:
		contents.append("gold")
	if _sword_check.button_pressed:
		contents.append("sword")
	if _shield_check.button_pressed:
		contents.append("shield")
	contents_changed.emit(_chest_id, contents, int(_gold_amount.value))
	hide()

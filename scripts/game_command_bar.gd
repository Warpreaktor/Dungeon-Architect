class_name GameCommandBar
extends Control

## Экранные команды режима прохождения. Статистика героя находится в HeroHUD.
signal inventory_requested
signal menu_requested

@onready var _inventory_button: Button = %InventoryButton
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	_inventory_button.pressed.connect(_on_inventory_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_inventory_button.focus_mode = Control.FOCUS_NONE
	_menu_button.focus_mode = Control.FOCUS_NONE


func _on_inventory_pressed() -> void:
	inventory_requested.emit()


func _on_menu_pressed() -> void:
	menu_requested.emit()

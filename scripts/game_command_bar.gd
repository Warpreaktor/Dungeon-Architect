class_name GameCommandBar
extends Control

## Экранные команды режима прохождения. Статистика героя находится в HeroHUD.
signal arsenal_requested
signal inventory_requested
signal map_requested
signal menu_requested

@onready var _arsenal_button: Button = %ArsenalButton
@onready var _inventory_button: Button = %InventoryButton
@onready var _menu_button: Button = %MenuButton
@onready var _map_button: Button = %MapButton


func _ready() -> void:
	_arsenal_button.pressed.connect(func() -> void: arsenal_requested.emit())
	_arsenal_button.focus_mode = Control.FOCUS_NONE
	_inventory_button.pressed.connect(_on_inventory_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_map_button.pressed.connect(_on_map_pressed)
	_inventory_button.focus_mode = Control.FOCUS_NONE
	_menu_button.focus_mode = Control.FOCUS_NONE
	_map_button.focus_mode = Control.FOCUS_NONE


func _on_inventory_pressed() -> void:
	inventory_requested.emit()


func _on_menu_pressed() -> void:
	menu_requested.emit()


func _on_map_pressed() -> void:
	map_requested.emit()

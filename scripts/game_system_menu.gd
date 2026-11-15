class_name GameSystemMenu
extends CanvasLayer

## Системный экран поверх пошагового прохождения.
## Не ставим SceneTree на паузу: игровое управление блокируется владельцем.
signal continue_requested
signal leave_requested

@onready var _card: PanelContainer = %Card
@onready var _continue_button: Button = %ContinueButton
@onready var _leave_button: Button = %LeaveButton


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)
	get_viewport().size_changed.connect(_resize_card)
	_resize_card()
	hide()


func open_for(standalone: bool) -> void:
	_leave_button.text = "Главное меню" if standalone else "Редактор"
	show()
	_continue_button.grab_focus()


func dismiss() -> void:
	hide()


func _resize_card() -> void:
	_card.custom_minimum_size.x = minf(390.0, maxf(220.0, get_viewport().get_visible_rect().size.x - 32.0))


func _on_continue_pressed() -> void:
	continue_requested.emit()


func _on_leave_pressed() -> void:
	leave_requested.emit()

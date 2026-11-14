class_name MessageEditorPopup
extends PopupPanel

## Содержимое сообщения задаёт автор лабиринта, а не логика предметов.
signal saved(cell: Vector2i, text: String)
signal removed(cell: Vector2i)

var _cell := Vector2i(-1, -1)

@onready var _input: TextEdit = %MessageInput
@onready var _hint: Label = %ActivationHint
@onready var _delete_button: Button = %DeleteButton


func _ready() -> void:
	%SaveButton.pressed.connect(_save)
	%CancelButton.pressed.connect(hide)
	_delete_button.pressed.connect(_remove)


func configure(cell: Vector2i, text: String, on_door: bool) -> void:
	_cell = cell
	_input.text = text
	_hint.text = "Покажется после открытия двери." if on_door else "Покажется, когда герой войдёт в клетку."
	_delete_button.disabled = text.strip_edges().is_empty()


func _save() -> void:
	saved.emit(_cell, _input.text)
	hide()


func _remove() -> void:
	removed.emit(_cell)
	hide()

class_name GameDialogueView
extends CanvasLayer

## Простое игровое повествование. Сцена ничего не знает о картах и триггерах.
signal closed

@onready var _card: PanelContainer = %Card
@onready var _text: RichTextLabel = %MessageText
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	_continue_button.pressed.connect(dismiss_by_player)
	get_viewport().size_changed.connect(_resize_card)
	_resize_card()
	hide()


func show_dialog(message: String) -> void:
	_text.text = message
	_text.scroll_to_line(0)
	_resize_card()
	show()
	_continue_button.grab_focus()


func _resize_card() -> void:
	_card.custom_minimum_size.x = minf(620.0, maxf(260.0, get_viewport().get_visible_rect().size.x - 32.0))


func dismiss_by_player() -> void:
	hide()
	closed.emit()


func dismiss() -> void:
	hide()

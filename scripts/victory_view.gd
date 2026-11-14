class_name VictoryView
extends CanvasLayer

## Экран завершения прохождения. Не знает ничего о редакторе и JSON карты.
## Хозяин экрана решает, что означают повторная попытка и выход.
signal retry_requested
signal editor_requested

@onready var _veil: ColorRect = %Veil
@onready var _card: PanelContainer = %Card
@onready var _steps_label: Label = %StepsLabel
@onready var _eyebrow: Label = %Eyebrow
@onready var _title: Label = %Title
@onready var _description: Label = %Description
@onready var _emblem: TextureRect = %Emblem
@onready var _retry_button: Button = %RetryButton
@onready var _editor_button: Button = %EditorButton


func _ready() -> void:
	_retry_button.pressed.connect(_on_retry_pressed)
	_editor_button.pressed.connect(_on_editor_pressed)
	_resize_card()
	get_viewport().size_changed.connect(_resize_card)

	# Мягкое появление экрана, которое не затрагивает камеру подземелья.
	_veil.color.a = 0.0
	_card.modulate.a = 0.0
	var entrance := create_tween().set_parallel(true)
	entrance.tween_property(_veil, "color:a", 0.87, 0.32)
	entrance.tween_property(_card, "modulate:a", 1.0, 0.42).set_delay(0.10)
	_retry_button.grab_focus()


func show_result(step_count: int) -> void:
	_steps_label.text = "Ходов сделано: %d" % step_count


## Та же сцена используется при поражении: не дублируем модальные экраны.
func show_defeat(step_count: int, victor: MonsterDefinition) -> void:
	_eyebrow.text = "ПУТЬ ОБОРВАЛСЯ"
	_title.text = "ГЕРОЙ ПАЛ"
	_description.text = "Тебя одолели обитатели катакомб. Попробуй ещё раз."
	_emblem.texture = victor.icon
	var frame := _card.get_theme_stylebox("panel").duplicate(true) as StyleBoxFlat
	frame.border_color = Color("#ba6b66")
	_card.add_theme_stylebox_override("panel", frame)
	_steps_label.text = "Ходов сделано: %d" % step_count
	_title.add_theme_color_override("font_color", Color("#e5a09d"))
	_eyebrow.add_theme_color_override("font_color", Color("#d48e86"))


func _resize_card() -> void:
	_card.custom_minimum_size.x = minf(510.0, maxf(260.0, get_viewport().get_visible_rect().size.x - 40.0))


func _on_retry_pressed() -> void:
	retry_requested.emit()


func _on_editor_pressed() -> void:
	editor_requested.emit()

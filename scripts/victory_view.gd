class_name VictoryView
extends CanvasLayer

## Экран завершения прохождения. Не знает ничего о редакторе и JSON карты.
## Хозяин экрана решает, что означают повторная попытка и выход.
signal retry_requested
signal editor_requested

var is_party_defeat: bool = false

@onready var _veil: ColorRect = %Veil
@onready var _card: PanelContainer = %Card
@onready var _steps_label: Label = %StepsLabel
@onready var _eyebrow: Label = %Eyebrow
@onready var _title: Label = %Title
@onready var _description: Label = %Description
@onready var _emblem: TextureRect = %Emblem
@onready var _top_line: ColorRect = %TopLine
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


## Завершение этажа: оставляем единый экран, но меняем действие кнопки.
func show_floor_transition(step_count: int, next_name: String) -> void:
	_eyebrow.text = "ПУТЬ ПРОДОЛЖАЕТСЯ"
	_title.text = "СЛЕДУЮЩИЙ УРОВЕНЬ"
	_description.text = "Ты спускаешься в «%s»." % next_name
	_steps_label.text = "Ходов сделано: %d" % step_count
	_retry_button.text = "Продолжить"


func show_party_defeat(step_count: int, fallen: Array[HeroState], survivor: HeroState) -> void:
	is_party_defeat = true
	_apply_defeat_style(fallen)
	_eyebrow.text = "ОТРЯД ПОНЁС ПОТЕРИ"
	_title.text = "ГЕРОЙ ПОГИБ" if fallen.size() == 1 else "ГЕРОИ ПОГИБЛИ"
	_description.text = "Погибли: %s\nПродолжает путь: %s" % [
		_fallen_names(fallen), survivor.definition.display_name]
	_steps_label.text = "Ходов сделано: %d" % step_count
	_retry_button.text = "Продолжить"
	_retry_button.grab_focus()


func show_game_over(step_count: int, fallen: Array[HeroState]) -> void:
	is_party_defeat = false
	_apply_defeat_style(fallen)
	_eyebrow.text = "ПОХОД ЗАВЕРШЁН"
	_title.text = "GAME OVER"
	_description.text = "Погибли: %s\nВ отряде не осталось живых героев." % _fallen_names(fallen)
	_steps_label.text = "Ходов сделано: %d" % step_count
	_retry_button.hide()
	_editor_button.grab_focus()


func _fallen_names(fallen: Array[HeroState]) -> String:
	var names: Array[String] = []
	for member in fallen:
		if member != null and member.definition != null:
			names.append(member.definition.display_name)
	return ", ".join(names)


func _apply_defeat_style(fallen: Array[HeroState]) -> void:
	_emblem.texture = fallen[0].definition.portrait if not fallen.is_empty() else null
	_top_line.color = Color("#ba6b66")
	var frame := _card.get_theme_stylebox("panel").duplicate(true) as StyleBoxFlat
	frame.border_color = Color("#ba6b66")
	_card.add_theme_stylebox_override("panel", frame)
	_title.add_theme_color_override("font_color", Color("#e5a09d"))
	_eyebrow.add_theme_color_override("font_color", Color("#d48e86"))


func _resize_card() -> void:
	_card.custom_minimum_size.x = minf(510.0, maxf(260.0, get_viewport().get_visible_rect().size.x - 40.0))


func set_exit_text(value: String) -> void:
	_editor_button.text = value


func _on_retry_pressed() -> void:
	retry_requested.emit()


func _on_editor_pressed() -> void:
	editor_requested.emit()

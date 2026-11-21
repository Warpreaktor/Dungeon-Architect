class_name BattleLabPlaybackPanel
extends PanelContainer

signal advance_requested(mode: String)
signal speed_requested(multiplier: float)

var _status: Label
var _history: RichTextLabel
var _speed: OptionButton
var _details: RichTextLabel
var _count: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	custom_minimum_size = Vector2(355, 0)
	position = Vector2(-370, 12)
	var column := VBoxContainer.new()
	add_child(column)
	var heading := Label.new()
	heading.text = "Лаборатория · просмотр событий"
	column.add_child(heading)
	_status = Label.new()
	_status.text = "Запусти фазу в боевом интерфейсе"
	column.add_child(_status)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	for entry in [{"caption": "Действие", "mode": "action"}, {"caption": "Такт", "mode": "tick"}, {"caption": "Фаза", "mode": "phase"}]:
		var button := Button.new()
		button.text = str(entry["caption"])
		button.pressed.connect(_on_advance.bind(str(entry["mode"])))
		buttons.add_child(button)
	_speed = OptionButton.new()
	for rate in [0.5, 1.0, 2.0, 4.0]:
		_speed.add_item("×%s" % str(rate))
		_speed.set_item_metadata(_speed.item_count - 1, rate)
	_speed.select(1)
	_speed.item_selected.connect(_on_speed_selected)
	buttons.add_child(_speed)
	var toggle := Button.new()
	toggle.text = "Журнал ▾"
	column.add_child(toggle)
	_history = RichTextLabel.new()
	_history.custom_minimum_size = Vector2(340, 195)
	_history.scroll_following = true
	column.add_child(_history)
	toggle.pressed.connect(func() -> void: _history.visible = not _history.visible)
	var detail_toggle := Button.new()
	detail_toggle.text = "Данные событий ▾"
	column.add_child(detail_toggle)
	_details = RichTextLabel.new()
	_details.custom_minimum_size = Vector2(340, 110)
	_details.visible = false
	column.add_child(_details)
	detail_toggle.pressed.connect(func() -> void: _details.visible = not _details.visible)


func start_phase(number: int) -> void:
	_status.text = "Фаза %d · воспроизведение" % number


func show_step(events: Array, number: int, tick: int, hero_name: String, enemy_name: String, support_name: String) -> void:
	_count += 1
	_status.text = "Шаг %d · такт %d" % [number, tick]
	_history.append_text("Шаг %d
" % _count)
	_details.clear()
	for line in BattlePlaybackTimeline.describe_events(events, hero_name, enemy_name, support_name):
		_history.append_text(line + "\n")
	for value in events:
		_details.append_text(JSON.stringify(value, "  ") + "\n")


func finish_phase() -> void:
	_status.text = "Фаза завершена"


func _on_advance(mode: String) -> void:
	advance_requested.emit(mode)


func _on_speed_selected(index: int) -> void:
	speed_requested.emit(float(_speed.get_item_metadata(index)))

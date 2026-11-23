class_name GameSystemMenu
extends CanvasLayer

signal continue_requested
signal save_requested
signal leave_requested
signal test_open_map_changed(enabled: bool)
signal console_changed(enabled: bool)

@onready var _card: PanelContainer = %Card
@onready var _continue_button: Button = %ContinueButton
@onready var _save_button: Button = %SaveButton
@onready var _save_error: Label = %SaveError
@onready var _leave_button: Button = %LeaveButton
@onready var _test_settings_button: Button = %TestSettingsButton

var _settings_popup: PopupPanel
var _open_map_button: CheckButton
var _console_button: CheckButton


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	_save_button.pressed.connect(func() -> void: save_requested.emit())
	_leave_button.pressed.connect(_on_leave_pressed)
	_test_settings_button.pressed.connect(_open_settings)
	_build_settings_popup()
	get_viewport().size_changed.connect(_resize_card)
	_resize_card()
	hide()


func _build_settings_popup() -> void:
	_settings_popup = PopupPanel.new()
	_settings_popup.name = "SettingsPopup"
	add_child(_settings_popup)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 20)
	margins.add_theme_constant_override("margin_right", 20)
	margins.add_theme_constant_override("margin_top", 18)
	margins.add_theme_constant_override("margin_bottom", 18)
	_settings_popup.add_child(margins)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margins.add_child(column)
	var title := Label.new()
	title.text = "Настройки"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_console_button = CheckButton.new()
	_console_button.text = "Консоль"
	_console_button.toggled.connect(func(enabled: bool) -> void: console_changed.emit(enabled))
	column.add_child(_console_button)
	_open_map_button = CheckButton.new()
	_open_map_button.text = "Открытая карта"
	_open_map_button.toggled.connect(func(enabled: bool) -> void: test_open_map_changed.emit(enabled))
	column.add_child(_open_map_button)


func open_for(standalone: bool, open_map: bool = false, console_open: bool = false, can_save: bool = false) -> void:
	_leave_button.text = "Главное меню" if standalone else "Выйти в редактор"
	_save_button.visible = standalone
	_save_button.disabled = not can_save
	_save_error.hide()
	_open_map_button.visible = not standalone
	_open_map_button.set_pressed_no_signal(open_map)
	_console_button.set_pressed_no_signal(console_open)
	_settings_popup.hide()
	show()
	_continue_button.grab_focus()


func show_save_error(message: String) -> void:
	_save_error.text = message
	_save_error.show()


func dismiss() -> void:
	_settings_popup.hide()
	hide()


func sync_console(opened: bool) -> void:
	if _console_button != null:
		_console_button.set_pressed_no_signal(opened)


func settings_open() -> bool:
	return _settings_popup.visible


func close_settings() -> void:
	_settings_popup.hide()


func _open_settings() -> void:
	_settings_popup.popup_centered(Vector2i(330, 180))


func _resize_card() -> void:
	_card.custom_minimum_size.x = minf(390.0, maxf(220.0, get_viewport().get_visible_rect().size.x - 32.0))


func _on_continue_pressed() -> void:
	continue_requested.emit()


func _on_leave_pressed() -> void:
	leave_requested.emit()

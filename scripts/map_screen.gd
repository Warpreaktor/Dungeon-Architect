class_name MapScreen
extends CanvasLayer

signal closed
signal minimap_changed(enabled: bool)

@onready var _overview: MapOverview = %MapOverview
@onready var _close_button: Button = %CloseButton
@onready var _mini_toggle: CheckButton = %MinimapToggle


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(dismiss_by_player)
	_mini_toggle.toggled.connect(_on_mini_toggled)


func open_for(session: GameSession, show_minimap: bool) -> void:
	_overview.show_session(session)
	_mini_toggle.set_pressed_no_signal(show_minimap)
	visible = true
	_close_button.grab_focus()


func dismiss_by_player() -> void:
	visible = false
	closed.emit()


func dismiss() -> void:
	visible = false


func _on_mini_toggled(enabled: bool) -> void:
	minimap_changed.emit(enabled)

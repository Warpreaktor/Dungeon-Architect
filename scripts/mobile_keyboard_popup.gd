class_name MobileKeyboardPopup
extends PopupPanel

## Keeps a focused field and popup actions above the Android soft keyboard.
## Window geometry is local to the current Godot viewport; this is UI only.
const MARGIN := 12

var _was_visible := false
var _saved_size := Vector2i.ZERO
var _saved_position := Vector2i.ZERO
var _keyboard_open := false


func _process(_delta: float) -> void:
	if not OS.has_feature("mobile"):
		return
	if not visible:
		if _was_visible:
			_reset_keyboard_layout()
			DisplayServer.virtual_keyboard_hide()
		_was_visible = false
		return
	if not _was_visible:
		_was_visible = true
		_saved_size = size
		_saved_position = position
	var keyboard_pixels := DisplayServer.virtual_keyboard_get_height()
	if keyboard_pixels <= 0:
		if _keyboard_open:
			_reset_keyboard_layout()
		return

	var view_size := get_tree().root.get_visible_rect().size
	var window_size := DisplayServer.window_get_size()
	if window_size.y <= 0:
		return
	var keyboard_height := float(keyboard_pixels) * view_size.y / float(window_size.y)
	var available_height := maxi(150, int(view_size.y - keyboard_height - MARGIN * 2))
	var available_width := maxi(160, int(view_size.x - MARGIN * 2))
	if not _keyboard_open:
		_keyboard_open = true
		_keyboard_layout_changed(true)
	var target_size := Vector2i(mini(_saved_size.x, available_width), mini(_saved_size.y, available_height))
	if size != target_size:
		size = target_size
	var centered_x := maxi(MARGIN, int((view_size.x - float(target_size.x)) / 2.0))
	var target_y := MARGIN
	var next_position := Vector2i(centered_x, target_y)
	if position != next_position:
		position = next_position


func _reset_keyboard_layout() -> void:
	if _keyboard_open:
		_keyboard_open = false
		_keyboard_layout_changed(false)
	if _saved_size != Vector2i.ZERO:
		size = _saved_size
		position = _saved_position


func _keyboard_layout_changed(_open: bool) -> void:
	pass


func close_soft_keyboard(field: Control) -> void:
	field.release_focus()
	DisplayServer.virtual_keyboard_hide()

class_name AudioVolumeControls
extends VBoxContainer

const LABELS := {
	&"Master": "Общая громкость",
	&"Music": "Музыка",
	&"Ambience": "Окружение",
	&"SFX": "Звуковые эффекты",
	&"UI": "Интерфейс"
}

var _manager: GameAudioManager
var _sliders: Dictionary = {}
var _values: Dictionary = {}


func _ready() -> void:
	_manager = GameAudioManager.instance(get_tree())
	if _manager == null:
		hide()
		return
	add_theme_constant_override("separation", 6)
	for channel in GameAudioManager.CHANNELS:
		var row := HBoxContainer.new()
		add_child(row)
		var label := Label.new()
		label.text = LABELS[channel]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var value_label := Label.new()
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.custom_minimum_size.y = 30.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(slider)
		_sliders[channel] = slider
		_values[channel] = value_label
		_update_volume(channel, _manager.channel_volume(channel))
		slider.value_changed.connect(_on_slider_changed.bind(channel))
	_manager.volume_changed.connect(_update_volume)


func _on_slider_changed(value: float, channel: StringName) -> void:
	_manager.set_channel_volume(channel, value / 100.0)


func _update_volume(channel: StringName, value: float) -> void:
	var slider: HSlider = _sliders[channel]
	var label: Label = _values[channel]
	var percent: int = roundi(value * 100.0)
	slider.set_value_no_signal(percent)
	label.text = "%d%%" % percent

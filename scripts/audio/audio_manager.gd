class_name GameAudioManager
extends Node

signal volume_changed(channel: StringName, value: float)

const CHANNELS: Array[StringName] = [&"Master", &"Music", &"Ambience", &"SFX", &"UI"]
const MENU_MUSIC := "res://assets/audio/music/main_menu.mp3"
const EXPLORATION_MUSIC := "res://assets/audio/music/exploration.ogg"
const SETTINGS_PATH := "user://audio_settings.cfg"
const FADE_SECONDS := 0.8
const SILENT_DB := -80.0

var _players: Array[AudioStreamPlayer] = []
var _paths: Array[String] = ["", ""]
var _target_path := ""
var _fade: Tween
var _settings := ConfigFile.new()


static func instance(tree: SceneTree) -> GameAudioManager:
	return tree.root.get_node_or_null("AudioManager") as GameAudioManager


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_settings.load(SETTINGS_PATH)
	for channel in CHANNELS:
		var value: Variant = _settings.get_value("volume", String(channel), channel_volume(channel))
		if value is float or value is int:
			set_channel_volume(channel, float(value), false)
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % (index + 1)
		player.bus = &"Music"
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)


func channel_volume(channel: StringName) -> float:
	var index: int = AudioServer.get_bus_index(channel)
	if index < 0 or AudioServer.is_bus_mute(index):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(index)), 0.0, 1.0)


func set_channel_volume(channel: StringName, value: float, persist: bool = true) -> void:
	var index: int = AudioServer.get_bus_index(channel)
	if not CHANNELS.has(channel) or index < 0 or not is_finite(value):
		return
	value = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(index, is_zero_approx(value))
	if persist:
		_settings.set_value("volume", String(channel), value)
		_settings.save(SETTINGS_PATH)
	volume_changed.emit(channel, value)


func play_music(path: String, fade_seconds: float = FADE_SECONDS) -> bool:
	if path.is_empty():
		stop_music(fade_seconds)
		return true
	var target: int = _playing_index(path)
	if target >= 0 and _target_path == path:
		return true
	if target < 0:
		var stream: AudioStream = _load_music(path)
		if stream == null:
			stop_music(fade_seconds)
			return false
		target = _available_player()
		_cancel_fade()
		var player: AudioStreamPlayer = _players[target]
		player.stop()
		player.stream = stream
		player.volume_db = SILENT_DB
		_paths[target] = path
		player.play()
	_target_path = path
	_transition(target, fade_seconds)
	return true


func stop_music(fade_seconds: float = FADE_SECONDS) -> void:
	if _target_path.is_empty() and _fade != null and fade_seconds > 0.0:
		return
	_target_path = ""
	_transition(-1, fade_seconds if _has_music() else 0.0)


func _load_music(path: String) -> AudioStream:
	if not ResourceLoader.exists(path, "AudioStream"):
		return null
	var stream := ResourceLoader.load(path, "AudioStream") as AudioStream
	if stream is AudioStreamMP3:
		var mp3 := stream.duplicate() as AudioStreamMP3
		mp3.loop = true
		mp3.loop_offset = 0.0
		return mp3
	if stream is AudioStreamOggVorbis:
		var ogg := stream.duplicate() as AudioStreamOggVorbis
		ogg.loop = true
		ogg.loop_offset = 0.0
		return ogg
	return null


func _playing_index(path: String) -> int:
	for index in range(_players.size()):
		if _paths[index] == path and _players[index].playing:
			return index
	return -1


func _available_player() -> int:
	for index in range(_players.size()):
		if not _players[index].playing:
			return index
	return 0 if _players[0].volume_db <= _players[1].volume_db else 1


func _has_music() -> bool:
	for player in _players:
		if player.playing:
			return true
	return false


func _cancel_fade() -> void:
	if _fade != null:
		_fade.kill()
		_fade = null


func _transition(target: int, duration: float) -> void:
	_cancel_fade()
	if duration <= 0.0:
		_finish_transition(target)
		return
	_fade = create_tween().set_parallel(true)
	for index in range(_players.size()):
		var player: AudioStreamPlayer = _players[index]
		if player.playing:
			_fade.tween_method(_set_player_gain.bind(player), db_to_linear(player.volume_db), 1.0 if index == target else 0.0, duration)
	_fade.chain().tween_callback(_finish_transition.bind(target))


func _set_player_gain(gain: float, player: AudioStreamPlayer) -> void:
	player.volume_db = linear_to_db(maxf(gain, 0.0001))


func _finish_transition(target: int) -> void:
	for index in range(_players.size()):
		var player: AudioStreamPlayer = _players[index]
		if index == target:
			player.volume_db = 0.0
		else:
			player.stop()
			player.stream = null
			player.volume_db = SILENT_DB
			_paths[index] = ""
	_fade = null

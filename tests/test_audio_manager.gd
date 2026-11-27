extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: GameAudioManager = GameAudioManager.instance(self)
	assert(manager != null)
	assert(manager._players.size() == 2)
	for channel in GameAudioManager.CHANNELS:
		var index: int = AudioServer.get_bus_index(channel)
		assert(index >= 0)
		if channel != &"Master":
			assert(AudioServer.get_bus_send(index) == &"Master")
	for player in manager._players:
		assert(player.bus == &"Music")
	assert(not manager.play_music("res://assets/audio/music/missing_test_track.mp3", 0.0))
	assert(manager._target_path.is_empty())
	assert(not manager._has_music())
	if ResourceLoader.exists(GameAudioManager.MENU_MUSIC):
		var stream := manager._load_music(GameAudioManager.MENU_MUSIC) as AudioStreamMP3
		assert(stream != null and stream.loop and is_zero_approx(stream.loop_offset))
		assert(manager.play_music(GameAudioManager.MENU_MUSIC, 0.0))
		assert(manager._target_path == GameAudioManager.MENU_MUSIC)
		manager.stop_music(0.0)
		assert(manager._target_path.is_empty() and not manager._has_music())
	_test_smooth_fade(manager)
	_test_ambience(manager)
	_test_optional_dungeon_audio(manager)
	var controls := AudioVolumeControls.new()
	root.add_child(controls)
	assert(controls._sliders.size() == GameAudioManager.CHANNELS.size())
	var original: float = manager.channel_volume(&"Music")
	var music_bus: int = AudioServer.get_bus_index(&"Music")
	var slider: HSlider = controls._sliders[&"Music"]
	manager.set_channel_volume(&"Music", 0.0, false)
	assert(AudioServer.is_bus_mute(music_bus) and is_zero_approx(slider.value))
	manager.set_channel_volume(&"Music", 0.5, false)
	assert(not AudioServer.is_bus_mute(music_bus))
	assert(is_equal_approx(manager.channel_volume(&"Music"), 0.5))
	assert(is_equal_approx(slider.value, 50.0))
	manager.set_channel_volume(&"Music", 2.0, false)
	assert(is_equal_approx(manager.channel_volume(&"Music"), 1.0))
	manager.set_channel_volume(&"Music", original, false)
	controls.queue_free()
	await process_frame
	print("Audio: optional music and ambience, fades, bus routing and volume controls OK")
	quit()


func _test_smooth_fade(manager: GameAudioManager) -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	var samples := PackedByteArray()
	samples.resize(stream.mix_rate)
	stream.data = samples
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = samples.size()
	var player: AudioStreamPlayer = manager._players[0]
	player.stream = stream
	player.volume_db = GameAudioManager.SILENT_DB
	player.play()
	assert(player.playing)
	var duration: float = MainMenu.INTRO_MUSIC_FADE_SECONDS
	manager._transition(0, duration, Tween.TRANS_SINE)
	var fade: Tween = manager._fade
	fade.pause()
	fade.custom_step(duration * 0.25)
	var gain: float = db_to_linear(player.volume_db)
	assert(gain > 0.0 and gain < 0.2)
	fade.custom_step(duration * 0.25)
	assert(absf(db_to_linear(player.volume_db) - 0.5) < 0.01)
	fade.custom_step(duration * 0.51)
	assert(is_zero_approx(player.volume_db))
	manager.stop_music(0.0)


func _test_ambience(manager: GameAudioManager) -> void:
	var player: AudioStreamPlayer = manager._ambience_player
	assert(player.bus == &"Ambience")
	var original_volume: float = manager.channel_volume(&"Ambience")
	var target_gain: float = GameAudioManager.DUNGEON_AMBIENCE_GAIN
	assert(not player.playing)
	assert(not manager.play_ambience("res://assets/audio/ambience/missing_test_track.ogg", 0.0))
	assert(player.stream == null and manager._ambience_path.is_empty())
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	var samples := PackedByteArray()
	samples.resize(stream.mix_rate)
	stream.data = samples
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = samples.size()
	player.stream = stream
	player.volume_db = GameAudioManager.SILENT_DB
	manager._ambience_path = "test_ambience"
	player.play()
	manager._fade_ambience(false, 1.0)
	var fade: Tween = manager._ambience_fade
	fade.pause()
	fade.custom_step(0.5)
	assert(absf(db_to_linear(player.volume_db) - target_gain * 0.5) < 0.01)
	assert(manager.play_ambience("test_ambience"))
	assert(manager._ambience_fade == fade and player.stream == stream)
	fade.custom_step(0.51)
	assert(player.playing and is_equal_approx(db_to_linear(player.volume_db), target_gain))
	manager.stop_ambience(1.0)
	fade = manager._ambience_fade
	fade.pause()
	fade.custom_step(0.5)
	assert(player.playing and absf(db_to_linear(player.volume_db) - target_gain * 0.5) < 0.01)
	assert(manager.play_ambience("test_ambience", 0.0))
	assert(player.playing and is_equal_approx(db_to_linear(player.volume_db), target_gain))
	assert(is_equal_approx(manager.channel_volume(&"Ambience"), original_volume))
	manager.stop_ambience(0.0)
	assert(not player.playing and player.stream == null and manager._ambience_path.is_empty())


func _test_optional_dungeon_audio(manager: GameAudioManager) -> void:
	assert(GameAudioManager._optional_audio_path("res://assets/audio/missing_test_track.ogg").is_empty())
	var music_path: String = GameAudioManager._optional_audio_path(GameAudioManager.EXPLORATION_MUSIC)
	var ambience_path: String = GameAudioManager._optional_audio_path(GameAudioManager.DUNGEON_AMBIENCE)
	manager.play_dungeon_audio()
	assert(manager._target_path == music_path)
	assert(manager._ambience_path == ambience_path)
	if not ambience_path.is_empty():
		var stream: AudioStream = manager._ambience_player.stream
		if stream is AudioStreamMP3:
			assert(stream.loop and is_zero_approx(stream.loop_offset))
		elif stream is AudioStreamOggVorbis:
			assert(stream.loop and is_zero_approx(stream.loop_offset))
		else:
			assert(false, "Unsupported ambience stream")
		manager.play_dungeon_audio()
		assert(manager._ambience_player.stream == stream)
	manager.stop_ambience(0.0)
	assert(manager._target_path == music_path)
	assert(not manager._ambience_player.playing)
	manager.stop_music(0.0)

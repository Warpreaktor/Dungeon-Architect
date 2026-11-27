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
	print("Audio: optional music, bus routing and volume controls OK")
	quit()

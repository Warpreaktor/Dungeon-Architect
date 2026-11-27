extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate() as MainMenu
	var empty_dir: String = "user://da_menu_transitions_%d" % Time.get_ticks_usec()
	menu._maps_directory = empty_dir.path_join("maps")
	menu._campaign_library = CampaignLibrary.new(empty_dir.path_join("campaigns"))
	menu._save_store = ProgressSaveStore.new(empty_dir.path_join("saves"))
	var audio: GameAudioManager = GameAudioManager.instance(self)
	assert(audio != null)
	audio.stop_music(0.0)
	root.add_child(menu)
	assert(audio._target_path.is_empty() and not audio._has_music())
	var play: StoneMenuButton = menu.get_node("%PlayButton")
	var campaign: StoneMenuButton = menu.get_node("%CampaignButton")
	var personal: StoneMenuButton = menu.get_node("%PersonalMapsButton")
	var back: StoneMenuButton = menu.get_node("%BackButton")
	var play_back: StoneMenuButton = menu.get_node("%PlayBackButton")
	var editor: StoneMenuButton = menu.get_node("%EditorButton")
	var requests: Array[bool] = []
	menu.editor_requested.connect(func() -> void: requests.append(true))
	assert(menu._transitioning and menu._curtain.visible and menu._curtain.color.a == 1.0)
	play.pressed.emit()
	assert(menu._home.visible and not menu._play_actions.visible)
	await menu.transition_finished
	var menu_track: String = GameAudioManager.MENU_MUSIC if ResourceLoader.exists(GameAudioManager.MENU_MUSIC) else ""
	assert(audio._target_path == menu_track)
	assert(not menu._curtain.visible and is_zero_approx(menu._curtain.color.a))
	play.pressed.emit()
	assert(menu._transitioning and menu._home.visible and menu._curtain.visible)
	assert(is_zero_approx(menu._curtain.color.a))
	play.pressed.emit()
	editor.pressed.emit()
	campaign.pressed.emit()
	assert(requests.is_empty() and not menu._library.visible)
	await create_timer(MainMenu.ASH_SECONDS * 0.35).timeout
	assert(menu._home.visible and menu._transitioning)
	assert(play._ash_burn > 0.0 and play._ash_burn < 1.0)
	assert(play._ash_dust != null and not play._sparks.emitting)
	assert(play._ash_dust._seeds.size() > 0)
	while not menu._play_actions.visible:
		await process_frame
	assert(menu._transitioning and not menu._home.visible and menu._logo.visible)
	assert(campaign._ash_burn == 1.0 and campaign._ash_scatter == 1.0)
	campaign.pressed.emit()
	assert(not menu._library.visible)
	await menu.transition_finished
	assert(campaign._ash_burn == 0.0 and campaign._ash_scatter == 0.0)
	assert(personal.self_modulate.a == 1.0 and not menu._curtain.visible)
	campaign.pressed.emit()
	assert(menu._transitioning and menu._play_actions.visible)
	personal.pressed.emit()
	await create_timer(MainMenu.SCREEN_FADE_SECONDS * 0.45).timeout
	assert(menu._play_actions.visible and menu._curtain.color.a > 0.0 and menu._curtain.color.a < 1.0)
	while not menu._library.visible:
		await process_frame
	assert(menu._transitioning and menu._curtain.color.a > 0.95)
	assert(menu._library_mode == MainMenu.LIBRARY_CAMPAIGNS)
	await menu.transition_finished
	assert(not menu._curtain.visible and not menu._logo.visible)
	back.pressed.emit()
	await menu.transition_finished
	assert(menu._play_actions.visible and menu._logo.visible)
	personal.pressed.emit()
	await menu.transition_finished
	assert(menu._library.visible and menu._library_mode == MainMenu.LIBRARY_PERSONAL)
	back.pressed.emit()
	await menu.transition_finished
	play_back.pressed.emit()
	await menu.transition_finished
	assert(menu._home.visible and not menu._play_actions.visible)
	assert(play._ash_burn == 0.0 and editor._ash_burn == 0.0)
	editor.pressed.emit()
	assert(requests.size() == 1)
	assert(audio._target_path == menu_track)
	audio.stop_music(0.0)
	menu.queue_free()
	await process_frame
	print("Main menu: intro fade, ash transitions, full-screen fades and input guard OK")
	quit()

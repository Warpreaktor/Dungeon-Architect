extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate() as MainMenu
	root.add_child(menu)
	assert(menu._transitioning and menu._curtain.visible)
	assert(is_equal_approx(menu._curtain.color.a, 1.0))
	await menu.transition_finished
	await process_frame
	assert(not menu._curtain.visible and not menu._transitioning)
	var artwork: Node2D = menu.get_node("Artwork")
	var background: Sprite2D = artwork.get_node("Background")
	var ambience: Node2D = artwork.get_node("Ambience")
	var campfire: FireEffect = ambience.get_node("Campfire")
	var torch_left: FireEffect = ambience.get_node("TorchLeft")
	var torch_right: FireEffect = ambience.get_node("TorchRight")
	var lantern: FireEffect = ambience.get_node("Lantern")
	var tunnel_near: FireEffect = ambience.get_node("TunnelTorchNear")
	var tunnel_far: FireEffect = ambience.get_node("TunnelTorchFar")
	var fires: Array[FireEffect] = [campfire, torch_left, torch_right, lantern, tunnel_near, tunnel_far]
	var anchors: Array[Vector2] = [Vector2(0.44258, 0.72051), Vector2(0.56400, 0.36663), Vector2(0.80622, 0.34431), Vector2(0.11722, 0.47184), Vector2(0.68062, 0.44633), Vector2(0.71651, 0.47715)]
	var fog: ColorRect = ambience.get_node("TunnelFog")
	assert(ambience.get_child_count() == fires.size() + 1)
	assert(fog.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(fog.get_index() < campfire.get_index())
	assert(artwork.z_index + fog.z_index < 0)
	var fog_material: ShaderMaterial = fog.material as ShaderMaterial
	assert(fog_material != null and fog_material.shader != null)
	var noise_texture: NoiseTexture2D = fog_material.get_shader_parameter("noise_map") as NoiseTexture2D
	assert(noise_texture != null and noise_texture.seamless)
	assert(lantern._embers == null and lantern._smoke == null)
	assert(campfire._embers == null and campfire._smoke == null)
	var campfire_particles: Node2D = campfire.get_node("CampfireParticles")
	var smoke: CPUParticles2D = campfire_particles.get_node("Smoke")
	var sparks: CPUParticles2D = campfire_particles.get_node("Sparks")
	var embers: CPUParticles2D = campfire_particles.get_node("Embers")
	var emitters: Array[CPUParticles2D] = [smoke, sparks, embers]
	assert(smoke.amount > torch_left.smoke_amount and sparks.amount > torch_left.ember_amount)
	assert(smoke.lifetime > sparks.lifetime and embers.lifetime > sparks.lifetime)
	assert(smoke.gravity.y < 0.0 and sparks.gravity.y < 0.0 and embers.gravity.y > 0.0)
	assert(smoke.scale_amount_curve.sample(0.0) < smoke.scale_amount_curve.sample(1.0))
	for emitter in emitters:
		assert(emitter.local_coords and emitter.emitting and not emitter.one_shot)
		assert(emitter.texture != null and emitter.color_ramp != null)
		assert(is_zero_approx(emitter.color_ramp.sample(1.0).a))
		assert(emitter.preprocess >= emitter.lifetime)
		assert(artwork.z_index + emitter.z_index < 0)
	assert(torch_left._embers != null and torch_left._smoke != null)
	assert(torch_left.get_node_or_null("CampfireParticles") == null)
	assert(torch_left._flame_material != torch_right._flame_material)
	assert(torch_left._flame_material.get_shader_parameter("speed") != torch_right._flame_material.get_shader_parameter("speed"))
	var buttons: Array[StoneMenuButton] = []
	for button_name in ["PlayButton", "EditorButton", "AudioSettingsButton", "ContinueGameButton", "CampaignButton", "PersonalMapsButton", "PlayBackButton", "BackButton", "StartButton"]:
		var button := menu.get_node("%" + button_name) as StoneMenuButton
		assert(button != null and button.icon == null)
		assert(button._stone.texture == StoneMenuButton.STONE)
		assert(button._stone.mouse_filter == Control.MOUSE_FILTER_IGNORE)
		assert(button._stone.show_behind_parent)
		assert(button._stone.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		assert(button._sparks.local_coords)
		assert(button._glow.shader == StoneMenuButton.GLOW_SHADER)
		buttons.append(button)
	assert(buttons[0]._glow != buttons[1]._glow)
	assert(buttons[0]._sparks != buttons[1]._sparks)
	var texture_size: Vector2 = background.texture.get_size()
	for dimensions in [Vector2i(640, 360), Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(1024, 768), Vector2i(600, 900), Vector2i(2560, 1080)]:
		root.size = dimensions
		await process_frame
		await process_frame
		var expected_scale: float = maxf(menu.size.x / texture_size.x, menu.size.y / texture_size.y)
		assert(artwork.scale.is_equal_approx(Vector2.ONE * expected_scale))
		assert(is_equal_approx(artwork.position.y, (menu.size.y - texture_size.y * expected_scale) * 0.5))
		assert(artwork.position.x <= 0.01 and artwork.position.y <= 0.01)
		var end: Vector2 = artwork.position + texture_size * expected_scale
		assert(end.x >= menu.size.x - 0.01 and end.y >= menu.size.y - 0.01)
		if menu.size.aspect() >= 4.0 / 3.0 and menu.size.aspect() <= 2.4:
			for fire in fires:
				assert(Rect2(Vector2.ZERO, menu.size).has_point(fire.global_position))
		var fog_bounds: Rect2 = MainMenu.TUNNEL_FOG_BOUNDS
		assert(fog.global_position.is_equal_approx(background.to_global(texture_size * fog_bounds.position)))
		assert(fog.size.is_equal_approx(texture_size * fog_bounds.size))
		assert(fog.get_global_rect().size.is_equal_approx(texture_size * fog_bounds.size * expected_scale))
		for emitter in emitters:
			assert(emitter.global_position.is_equal_approx(campfire.to_global(emitter.position)))
			assert(emitter.global_scale.is_equal_approx(campfire.global_scale))
		for index in range(fires.size()):
			var fire: FireEffect = fires[index]
			var anchor: Vector2 = background.to_global(texture_size * anchors[index])
			assert(fire.global_position.is_equal_approx(anchor))
			assert(fire.global_scale.is_equal_approx(background.global_scale * fire.scale))
			assert(fire.get_parent() == ambience)
			assert(artwork.z_index + fire._flame.z_index < 0)
			if fire._embers != null:
				assert(fire._embers.local_coords and artwork.z_index + fire._embers.z_index < 0)
			if fire._smoke != null:
				assert(fire._smoke.local_coords and artwork.z_index + fire._smoke.z_index < 0)
		for button in buttons:
			if not button.is_visible_in_tree():
				continue
			assert(button.size.y >= StoneMenuButton.MIN_TOUCH_HEIGHT)
			assert(button._stone.size.is_equal_approx(button.size))
			assert(button._sparks.emission_points.size() == StoneMenuButton.FRAME_POINTS.size())
			for point in button._sparks.emission_points:
				assert(Rect2(Vector2.ZERO, button.size).has_point(point))
		if menu.size.x >= 900.0 and menu.size.aspect() >= 1.3:
			var card: PanelContainer = menu.get_node("%Card")
			assert(card.get_global_rect().get_center().x < menu.size.x * 0.5)
			assert(not card.get_global_rect().has_point(torch_left.global_position))
			assert(not card.get_global_rect().has_point(lantern.global_position))
	var play: StoneMenuButton = buttons[0]
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	play._input(touch)
	play.button_down.emit()
	play._process(0.2)
	assert(play._sparks.emitting and is_equal_approx(play._highlight, 1.0))
	assert(play._glow.get_shader_parameter("pressed") == 1.0)
	play.button_up.emit()
	play._process(0.3)
	assert(not play._sparks.emitting and is_zero_approx(play._highlight))
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_TAB
	play._input(key)
	play.grab_focus()
	play._process(0.2)
	assert(is_equal_approx(play._highlight, 1.0))
	play.disabled = true
	play._process(0.3)
	assert(not play._sparks.emitting and is_zero_approx(play._highlight))
	assert(play._glow.get_shader_parameter("disabled") == 1.0)
	play.disabled = false
	play._input(touch)
	play.button_down.emit()
	play._process(0.2)
	play.hide()
	assert(not play._sparks.emitting and is_zero_approx(play._highlight) and not play.is_processing())
	play.show()
	assert(play.is_processing())
	menu.queue_free()
	await process_frame
	print("Main menu artwork: full viewport coverage, independent fire sources, campfire particles, ground fog, stone buttons and adaptive layout OK")
	quit()

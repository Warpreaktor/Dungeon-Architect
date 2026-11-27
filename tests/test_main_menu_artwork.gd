extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	var artwork: Node2D = menu.get_node("Artwork")
	var background: Sprite2D = artwork.get_node("Background")
	var ambience: Node2D = artwork.get_node("Ambience")
	var campfire: FireEffect = ambience.get_node("Campfire")
	var torch_left: FireEffect = ambience.get_node("TorchLeft")
	var torch_right: FireEffect = ambience.get_node("TorchRight")
	var lantern: FireEffect = ambience.get_node("Lantern")
	var fires: Array[FireEffect] = [campfire, torch_left, torch_right, lantern]
	var anchors: Array[Vector2] = [Vector2(0.427, 0.823), Vector2(0.562, 0.400), Vector2(0.867, 0.362), Vector2(0.038, 0.546)]
	assert(ambience.get_child_count() == fires.size())
	assert(lantern._embers == null and lantern._smoke == null)
	assert(torch_left.ember_amount < campfire.ember_amount and torch_left.smoke_amount < campfire.smoke_amount)
	assert(torch_left._flame_material != torch_right._flame_material)
	assert(torch_left._flame_material.get_shader_parameter("speed") != torch_right._flame_material.get_shader_parameter("speed"))
	var texture_size: Vector2 = background.texture.get_size()
	for dimensions in [Vector2i(640, 360), Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(1024, 768), Vector2i(600, 900), Vector2i(2560, 1080)]:
		root.size = dimensions
		await process_frame
		await process_frame
		var expected_scale: float = minf(menu.size.x / texture_size.x, menu.size.y / texture_size.y)
		assert(artwork.scale.is_equal_approx(Vector2.ONE * expected_scale))
		assert(artwork.position.is_equal_approx((menu.size - texture_size * expected_scale) * 0.5))
		assert(artwork.position.x >= -0.01 and artwork.position.y >= -0.01)
		var end: Vector2 = artwork.position + texture_size * expected_scale
		assert(end.x <= menu.size.x + 0.01 and end.y <= menu.size.y + 0.01)
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
		if menu.size.x >= 900.0 and menu.size.aspect() >= 1.3:
			var card: PanelContainer = menu.get_node("%Card")
			assert(card.get_global_rect().get_center().x < menu.size.x * 0.5)
			assert(not card.get_global_rect().has_point(torch_left.global_position))
			assert(not card.get_global_rect().has_point(lantern.global_position))
	menu.queue_free()
	await process_frame
	print("Main menu artwork: full image, independent fire sources and adaptive layout OK")
	quit()

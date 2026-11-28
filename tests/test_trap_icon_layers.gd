extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var frame: Image = FramedIcon.FRAME.get_image()
	assert(FramedIcon.compose(null) == null)
	for trap_id in TrapCatalog.list_ids():
		var definition: TrapDefinition = TrapCatalog.get_trap(trap_id)
		assert(definition.icon_art != null)
		var art: Image = definition.icon_art.get_image()
		assert(art.get_pixel(0, 0).a == 0.0)
		assert(art.get_pixel(art.get_width() - 1, art.get_height() - 1).a == 0.0)
		assert(definition.icon != definition.icon_art)
		assert(definition.icon == definition.icon)
		var composite: Image = definition.icon.get_image()
		assert(composite.get_size() == frame.get_size())
		assert(composite.get_pixel(0, 0).is_equal_approx(frame.get_pixel(0, 0)))
		var difference_found := false
		for y in range(0, composite.get_height(), 4):
			for x in range(0, composite.get_width(), 4):
				if not composite.get_pixel(x, y).is_equal_approx(frame.get_pixel(x, y)):
					difference_found = true
		assert(difference_found)
	print("Trap icon layers: shared frame and independent artwork")
	quit()

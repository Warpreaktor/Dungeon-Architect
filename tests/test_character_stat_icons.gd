extends SceneTree


func _initialize() -> void:
	for stat in ["accuracy", "agility", "attack", "combat_slots", "cooldown", "defense", "evasion", "gold", "health", "magic", "potion", "strength"]:
		var texture: Texture2D = StatIconCatalog.icon(stat)
		assert(texture != null, "Missing stat icon: %s" % stat)
		assert(texture.get_size() == Vector2(24, 24), "Invalid stat icon size: %s" % stat)
	quit()

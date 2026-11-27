extends SceneTree


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var skeleton: BattleParticipant = BattleParticipant.from_monster(MonsterCatalog.get_monster("skeleton"))
	var hero: BattleParticipant = BattleParticipant.from_hero(HeroState.new(HeroCatalog.get_hero("volcha")))
	var attack: AbilityDefinition = AbilityCatalog.get_ability("skeleton_rusty_slash")
	var curse: AbilityDefinition = AbilityCatalog.get_ability("skeleton_grave_howl")
	assert(BattleActionEmblem.effect_for(attack) == BattleActionEmblem.Effect.ATTACK)
	assert(BattleActionEmblem.effect_for(curse) == BattleActionEmblem.Effect.CURSE)
	assert(BattleActionEmblem.effect_for(AbilityCatalog.get_ability("guard")) == BattleActionEmblem.Effect.DEFENSE)
	assert(BattleActionEmblem.effect_for(null) == BattleActionEmblem.Effect.ATTACK)
	var healing := AbilityDefinition.new()
	healing.category = AbilityDefinition.Category.SUPPORT
	var effect := AbilityEffectDefinition.new()
	effect.kind = AbilityEffectDefinition.Kind.HEAL
	healing.effects.append(effect)
	assert(BattleActionEmblem.effect_for(healing) == BattleActionEmblem.Effect.HEAL)
	assert(BattleActionEmblem.effect_for(AbilityDefinition.new()) == BattleActionEmblem.Effect.ATTACK)
	var source := TextureRect.new()
	source.size = Vector2(78, 78)
	root.add_child(source)
	var frame: Texture2D = AbilityIconCatalog.style_for_actor(skeleton).frame_for_rank(MonsterDefinition.Rank.COMMON)
	assert(frame != null)
	for bounds in [Vector2(720, 480), Vector2(1280, 800)]:
		for point in [Vector2(0, 0), bounds - source.size]:
			source.position = point
			var emblem := BattleActionEmblem.new()
			root.add_child(emblem)
			emblem.configure(attack, skeleton, source, bounds)
			assert(Rect2(Vector2.ZERO, bounds).encloses(Rect2(emblem.position, emblem.size)))
			assert(emblem._caption.text == attack.display_name)
			assert(emblem._icon.texture == AbilityIconCatalog.art_for(attack))
			assert(emblem._icon._frame.texture == frame)
			assert(emblem._ink == AbilityIconCatalog.style_for_actor(skeleton).attack_glow)
			assert(emblem.mouse_filter == Control.MOUSE_FILTER_IGNORE)
			assert(emblem.modulate.a == 0.0)
			emblem.advance(0.45)
			assert(is_equal_approx(emblem.modulate.a, 1.0))
			emblem.advance(1.0)
			assert(is_zero_approx(emblem.modulate.a))
			assert(source.position == point)
			emblem.queue_free()
	var fallback := BattleActionEmblem.new()
	root.add_child(fallback)
	fallback.configure(null, hero, source, Vector2(720, 480))
	assert(fallback._caption.text == "Атака")
	assert(fallback._icon.texture == BattleAbilitySlot.ATTACK_ICON and not fallback._icon._frame.visible)
	assert(fallback._effect == BattleActionEmblem.Effect.ATTACK)
	fallback.queue_free()
	source.queue_free()
	await process_frame
	print("Battle action emblem: effects, frame, adaptive bounds and progress OK")
	quit()

extends SceneTree

const ICON_SCENE: PackedScene = preload("res://scenes/ability_icon.tscn")
const SLOT_SCENE: PackedScene = preload("res://scenes/battle_ability_slot.tscn")


func _initialize() -> void:
	call_deferred("_check")


func _texture(color: Color) -> Texture2D:
	var image: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _check() -> void:
	var skeleton: BattleParticipant = BattleParticipant.from_monster(MonsterCatalog.get_monster("skeleton"))
	var second: BattleParticipant = BattleParticipant.from_monster(MonsterCatalog.get_monster("fallen_hero"), "enemy_2")
	var boss: BattleParticipant = BattleParticipant.from_monster(MonsterCatalog.get_monster("kadavr"))
	var hunter: BattleParticipant = BattleParticipant.from_monster(MonsterCatalog.get_monster("hunter"))
	var hero: BattleParticipant = BattleParticipant.from_hero(HeroState.new(HeroCatalog.get_hero("volcha")))
	var style: AbilityIconStyle = AbilityIconCatalog.style_for_actor(skeleton)
	assert(style != null)
	assert(AbilityIconCatalog.style_for_actor(second) == style)
	assert(AbilityIconCatalog.style_for_actor(boss) == null)
	assert(style.frame_for_rank(MonsterDefinition.Rank.COMMON) != null)
	assert(AbilityIconCatalog.style_for_actor(hunter) == null)
	assert(AbilityIconCatalog.style_for_actor(hero) == null)
	var normal_frame: Texture2D = _texture(Color.WHITE)
	var boss_frame: Texture2D = _texture(Color.GOLD)
	var background: Texture2D = _texture(Color.BLACK)
	var art: Texture2D = _texture(Color.RED)
	var original_frame: Texture2D = style.frame
	var original_boss_frame: Texture2D = style.boss_frame
	var original_background: Texture2D = style.background
	style.frame = normal_frame
	style.boss_frame = boss_frame
	style.background = background
	assert(style.frame_for_rank(MonsterDefinition.Rank.BOSS) == boss_frame)
	assert(style.frame_for_rank(MonsterDefinition.Rank.COMMON) == normal_frame)
	var ability: AbilityDefinition = AbilityCatalog.get_ability("basic_strike").duplicate() as AbilityDefinition
	ability.icon_art = art
	var icon: AbilityIcon = ICON_SCENE.instantiate() as AbilityIcon
	root.add_child(icon)
	icon.configure_ability(ability, skeleton)
	assert(icon.texture == art and icon._frame.texture == normal_frame)
	assert(icon._background.texture == background and icon._background.show_behind_parent)
	assert(icon._frame.visible and icon._background.visible)
	assert(icon._frame.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(icon._background.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	icon.configure_ability(ability, boss)
	assert(icon._frame.texture == null and not icon._frame.visible)
	icon.configure_ability(ability, hero)
	assert(icon.texture == art and icon._frame.texture == null and not icon._frame.visible)
	assert(icon._background.texture == null and not icon._background.visible)
	icon.set_locked(true)
	assert(icon._lock_overlay.visible and icon._lock_overlay.modulate == Color.WHITE)
	assert(icon._lock_overlay.anchor_right == 1.0 and icon._lock_overlay.anchor_bottom == 1.0)
	assert(icon.self_modulate != Color.WHITE and icon.modulate == Color.WHITE)
	icon.configure(art)
	assert(not icon._lock_overlay.visible and icon.self_modulate == Color.WHITE)
	icon.set_state(AbilityIcon.State.SPENT)
	assert(icon.modulate != Color.WHITE)
	icon.configure(art)
	assert(icon.modulate == Color.WHITE)
	var slot: BattleAbilitySlot = SLOT_SCENE.instantiate() as BattleAbilitySlot
	root.add_child(slot)
	var actual: AbilityDefinition = AbilityCatalog.get_ability("skeleton_rusty_slash")
	slot.configure(0, actual, false, skeleton)
	assert(slot._slot_icon.texture == AbilityIconCatalog.art_for(actual))
	assert(slot._slot_icon._frame.texture == normal_frame)
	var replacement: Texture2D = _texture(Color.BLUE)
	style.frame = replacement
	slot.configure(0, actual, false, skeleton)
	icon.configure_ability(actual, second)
	assert(slot._slot_icon._frame.texture == replacement and icon._frame.texture == replacement)
	slot.configure_hidden(0)
	assert(not slot._slot_icon.visible and slot._slot_icon._frame.texture == null)
	var card := BattleSupportEnemyView.new()
	root.add_child(card)
	second.action_chain = [actual.ability_id]
	card.configure(second, null, "Проверка")
	card.reveal(0, actual.ability_id)
	var compact_icon: AbilityIcon = card._slots.get_child(0).get_node("AbilityIcon") as AbilityIcon
	assert(compact_icon.texture == AbilityIconCatalog.art_for(actual))
	assert(compact_icon._frame.texture == replacement)
	card.set_chain(second)
	compact_icon = card._slots.get_child(0).get_node("AbilityIcon") as AbilityIcon
	assert(not compact_icon.visible and compact_icon._frame.texture == null)
	style.frame = original_frame
	style.boss_frame = original_boss_frame
	style.background = original_background
	card.queue_free()
	slot.queue_free()
	icon.queue_free()
	print("Ability icon layers: OK")
	quit()

extends SceneTree


func _initialize() -> void:
	var size := Vector2(128.0, 148.0)
	var actors: Dictionary = {
		"hero": size,
		"hero_2": size,
		"enemy": size,
		"enemy_support": size
	}
	var positions: Dictionary = BattleClashGeometry.formation_positions(Vector2(640, 300), actors, 1.5, 0.35, 0.12)
	assert(positions.size() == 4)
	assert((positions["hero"] as Vector2).x < (positions["enemy"] as Vector2).x)
	assert((positions["hero_2"] as Vector2).x < (positions["enemy_support"] as Vector2).x)
	assert((positions["hero"] as Vector2).y < (positions["hero_2"] as Vector2).y)
	assert((positions["enemy"] as Vector2).y < (positions["enemy_support"] as Vector2).y)
	var contacts: Dictionary = BattleClashGeometry.contact_positions(positions, actors,
		{"hero_2": "enemy_support", "enemy": "hero"}, 0.14, 1.5)
	assert(contacts.size() == 2)
	var scene: PackedScene = load("res://scenes/battle_view.tscn")
	assert(scene != null)
	var screen: BattleView = scene.instantiate() as BattleView
	assert(screen != null)
	root.add_child(screen)
	await process_frame
	assert(screen.get_node_or_null("OuterMargin/Main/Battlefield/HeroSide/HeroParty/SecondHero") != null)
	assert(screen.get_node_or_null("OuterMargin/Main/Battlefield/HeroSide/HeroParty/HeroCard") != null)
	assert(screen.get_node_or_null("OuterMargin/Main/Battlefield/EnemySide/EnemyParty/SupportEnemy") != null)
	var wolf := HeroState.new(HeroCatalog.get_hero("volcha"))
	var rooster := HeroState.new(HeroCatalog.get_hero("petushan"))
	var monster: MonsterDefinition = MonsterCatalog.get_monster("skeleton")
	var party: Array[HeroState] = [wolf, rooster]
	var combat := CombatSession.new(monster, wolf, monster, 4277, party)
	screen.begin(combat, wolf)
	assert(screen._support_hero_view.visible)
	assert(screen._round_mode)
	assert(combat.battle_state.round_combat_active)
	assert(screen._target_outlines.has("hero_2"))
	assert(screen._selected_hero_id == "hero")
	screen._select_hero_view("hero_2")
	assert(screen._selected_hero_id == "hero_2")
	assert(screen._hero_chain == combat.battle_state.get_participant("hero_2").action_chain)
	assert(screen._round_next_actor() == "")
	screen._continue_round()
	assert(not screen._round_next_actor().is_empty() or screen._is_playing_back)
	screen.queue_free()
	await process_frame
	quit()

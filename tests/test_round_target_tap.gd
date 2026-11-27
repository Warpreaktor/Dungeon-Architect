extends SceneTree

const UnlockedHeroFixture = preload("res://tests/support/unlocked_hero_fixture.gd")


func _tap_event() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _touch_event() -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	return event


func _view(hero: HeroState, party: Array[HeroState] = []) -> BattleView:
	var encounter := MonsterCatalog.get_monster("skeleton")
	var combat := CombatSession.new(encounter, hero, encounter, 42776, party)
	var view := load("res://scenes/battle_view.tscn").instantiate() as BattleView
	root.add_child(view)
	view.begin(combat, hero)
	view._continue_round()
	return view


func _initialize() -> void:
	var hero := HeroState.new(UnlockedHeroFixture.definition("volcha"))
	hero.agility = 100
	var view := _view(hero)
	assert(view._round_next_actor() == "hero")
	assert(not view._hero_health_meter.get_node("HeartIcon").visible)
	assert(not view._enemy_health_meter.get_node("HeartIcon").visible)
	assert(not view._support_enemy_view._health.get_node("HeartIcon").visible)
	assert(view._hero_portrait.material == view._turn_glow_material)
	assert(view._enemy_portrait.material == null)
	assert(view._support_enemy_view.portrait_node().material == null)
	var standalone_meter: HealthMeter = load("res://scenes/health_meter.tscn").instantiate() as HealthMeter
	root.add_child(standalone_meter)
	assert(standalone_meter.get_node("HeartIcon").visible)
	standalone_meter.queue_free()
	var actions: HBoxContainer = view.get_node("OuterMargin/Main/BottomPanel/ActionsMargin/ActionsColumn/Actions")
	for child in actions.get_children():
		if child is Button:
			assert((child as Button).text != "Применить")
	var strike_index: int = view._hero_chain.find("volcha_wolf_lunge")
	assert(strike_index >= 0)
	view._on_slot_selected(strike_index)
	assert(view._selected_round_ability_id == "volcha_wolf_lunge")
	assert(view._combat.battle_state.round_turn_count == 0)
	view._on_target_portrait_input(_tap_event(), "hero")
	assert(view._combat.battle_state.round_turn_count == 0)
	assert(view._selected_round_ability_id == "volcha_wolf_lunge")
	view._on_target_portrait_input(_tap_event(), "enemy")
	assert(view._combat.battle_state.round_turn_count == 1)
	assert(view._combat.battle_state.events.any(func(e: Dictionary) -> bool:
		return e.get("type") == "action_start" and e.get("actor_id") == "hero" and e.get("ability_id") == "volcha_wolf_lunge"))
	assert(view._is_playing_back)
	assert((view._impact_portraits["hero"] as TextureRect).material == view._turn_glow_material)
	assert((view._impact_portraits["enemy"] as TextureRect).material == null)
	view._refresh_round_controls()
	assert(view._hero_portrait.material == view._turn_glow_material)
	view._on_target_portrait_input(_tap_event(), "enemy")
	assert(view._combat.battle_state.round_turn_count == 1)
	view.queue_free()

	var self_hero := HeroState.new(UnlockedHeroFixture.definition("volcha"))
	self_hero.agility = 100
	var self_view := _view(self_hero)
	var instinct_index: int = self_view._hero_chain.find("volcha_wolf_instinct")
	assert(instinct_index >= 0)
	self_view._on_slot_selected(instinct_index)
	self_view._on_target_portrait_input(_tap_event(), "enemy")
	assert(self_view._combat.battle_state.round_turn_count == 0)
	self_view._on_target_portrait_input(_tap_event(), "hero")
	assert(self_view._combat.battle_state.round_turn_count == 1)
	assert(self_view._combat.battle_state.events.any(func(e: Dictionary) -> bool:
		return e.get("type") == "action_start" and e.get("ability_id") == "volcha_wolf_instinct" and e.get("actor_id") == "hero"))
	self_view.queue_free()

	var rest_hero := HeroState.new(UnlockedHeroFixture.definition("volcha"))
	rest_hero.agility = 100
	var rest_view := _view(rest_hero)
	var rest_index: int = rest_view._hero_chain.size()
	rest_view._on_slot_selected(rest_index)
	assert(rest_view._combat.battle_state.round_turn_count == 1)
	assert(rest_view._combat.battle_state.events.any(func(e: Dictionary) -> bool:
		return e.get("type") == "rest" and e.get("actor_id") == "hero"))
	rest_view.queue_free()

	var rooster := HeroState.new(UnlockedHeroFixture.definition("petushan"))
	var wolf := HeroState.new(UnlockedHeroFixture.definition("volcha"))
	rooster.agility = 10
	wolf.agility = 100
	var party: Array[HeroState] = [rooster, wolf]
	var duo_view := _view(rooster, party)
	assert(duo_view._round_next_actor() == "hero_2")
	assert(duo_view._selected_hero_id == "hero_2")
	assert(not duo_view._support_hero_view._health.get_node("HeartIcon").visible)
	assert(duo_view._support_hero_view.portrait_node().material == duo_view._turn_glow_material)
	assert(duo_view._hero_portrait.material == null)
	duo_view._select_hero_view("hero")
	assert(duo_view._support_hero_view.portrait_node().material == duo_view._turn_glow_material)
	duo_view._select_hero_view("hero_2")
	var duo_instinct_index: int = duo_view._hero_chain.find("volcha_wolf_instinct")
	assert(duo_instinct_index >= 0)
	duo_view._on_slot_selected(duo_instinct_index)
	duo_view._on_target_portrait_input(_tap_event(), "hero")
	assert(duo_view._combat.battle_state.round_turn_count == 0)
	duo_view._on_target_portrait_input(_touch_event(), "hero_2")
	assert(duo_view._combat.battle_state.round_turn_count == 1)
	assert(duo_view._combat.battle_state.events.any(func(e: Dictionary) -> bool:
		return e.get("type") == "action_start" and e.get("actor_id") == "hero_2" and e.get("ability_id") == "volcha_wolf_instinct"))
	assert((duo_view._impact_portraits["hero_2"] as TextureRect).material == duo_view._turn_glow_material)
	duo_view._playback.kill()
	duo_view._clear_impact_layer()
	duo_view._after_phase_playback()
	assert(duo_view._support_hero_view.portrait_node().material == null)
	duo_view.queue_free()

	var slow_hero := HeroState.new(UnlockedHeroFixture.definition("volcha"))
	slow_hero.agility = 0
	var enemy_view := _view(slow_hero)
	assert(enemy_view._is_playing_back)
	var glowing_enemies: int = 0
	for enemy_id in enemy_view._combat.battle_state.enemy_ids():
		var portrait: TextureRect = enemy_view._impact_portraits[enemy_id]
		if portrait.material == enemy_view._turn_glow_material:
			glowing_enemies += 1
	assert(glowing_enemies == 1)
	assert(enemy_view._hero_portrait.material == null)
	enemy_view.queue_free()
	quit()

extends SceneTree

## Run in a Godot 4.7+ checkout:
## godot --headless --path . --script res://tests/da410/test_timing.gd
## No battle scenes, maps, UI or save files are touched.

const CLOCK = preload("res://scripts/da410/phase_clock.gd")
const EFFECTS = preload("res://scripts/da410/temporary_effects.gd")
const MATH = preload("res://scripts/da410/multiplier_rules.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var file: FileAccess = FileAccess.open("res://data/da410/volcha_abilities.json", FileAccess.READ)
	if file == null:
		push_error("Missing Volcha fixture")
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Invalid Volcha fixture")
		quit(1)
		return
	var fixture: Dictionary = parsed
	var abilities: Dictionary = {}
	for item in fixture["abilities"]:
		abilities[StringName(str(item["id"]))] = item

	_test_multipliers(abilities)
	_test_phase_clocks()
	_test_effects(abilities)
	if _failures.is_empty():
		print("DA-4.10 preparation: all pure-model checks passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_multipliers(abilities: Dictionary) -> void:
	var lunge: Dictionary = abilities[&"volcha_wolf_lunge"]
	var first: float = MATH.get_multiplier(lunge, 0, false, false)
	var subsequent: float = MATH.get_multiplier(lunge, 1, false, false)
	_check(is_equal_approx(first, 1.25), "Lunge in first slot")
	_check(is_equal_approx(subsequent, 1.0), "Lunge in subsequent slot")

	var rhythm: Dictionary = abilities[&"volcha_broken_rhythm"]
	var vs_rest: Array[float] = MATH.get_subhit_powers(rhythm, 10.0, 0, false, true)
	var vs_block: Array[float] = MATH.get_subhit_powers(rhythm, 10.0, 0, true, true)
	_check(vs_rest.size() == 3 and is_equal_approx(vs_rest.front(), 4.0), "Three subhits against rest")
	_check(vs_block.size() == 3 and is_equal_approx(vs_block.front(), 1.5), "Block precedence over rest")


func _test_phase_clocks() -> void:
	var clock = CLOCK.new()
	clock.register_actor(&"volcha", 3)
	clock.register_actor(&"hunter", 2)
	for tick in range(4):
		clock.advance_actor(&"volcha")
		clock.advance_actor(&"hunter")
	_check(clock.get_completed_phases(&"volcha") == 1, "Hero phase completed")
	_check(clock.get_completed_phases(&"hunter") == 1, "Enemy phase independent")
	_check(clock.round_index == 1, "Round reached after longest actor cycle")
	_check(clock.get_next_slot(&"hunter") == 1, "Enemy cursor retained across hero phase")


func _test_effects(abilities: Dictionary) -> void:
	var store = EFFECTS.new()
	var rebound: Dictionary = abilities[&"volcha_strike_and_rebound"]["after_success"][0]
	var instinct: Dictionary = abilities[&"volcha_wolf_instinct"]["after_success"][0]
	store.add(rebound, &"volcha", &"volcha")
	store.add(rebound, &"volcha", &"volcha")
	_check(is_equal_approx(store.sum_modifier(&"volcha", &"dodge_chance"), 0.1), "Rebound does not self-stack")
	for iteration in range(3):
		store.add(instinct, &"volcha", &"volcha")
	_check(is_equal_approx(store.sum_modifier(&"volcha", &"dodge_chance"), 0.7), "Instinct stacks with itself and rebound")
	store.on_incoming_attack_resolved(&"volcha")
	_check(is_zero_approx(store.sum_modifier(&"volcha", &"dodge_chance")), "Incoming attack consumes next-attack dodge")

	var tendons: Dictionary = abilities[&"volcha_cut_tendons"]["after_successful_unblocked_hit"][0]
	store.add(tendons, &"volcha", &"hunter", true)
	store.on_actor_phase_completed(&"volcha")
	_check(is_equal_approx(store.sum_modifier(&"hunter", &"agility"), -2.0), "Hero phase does not expire target debuff")
	store.on_actor_phase_completed(&"hunter") # Partially completed phase does not count.
	store.on_actor_phase_completed(&"hunter") # First full phase.
	_check(is_equal_approx(store.sum_modifier(&"hunter", &"agility"), -2.0), "Debuff survives first full target phase")
	store.on_actor_phase_completed(&"hunter") # Second full phase.
	_check(is_zero_approx(store.sum_modifier(&"hunter", &"agility")), "Debuff ends after second full target phase")

	var world_effect: Dictionary = {
		"id": "exploration_sample", "stat": "vision", "magnitude": 1.0,
		"clock": "world_action", "duration": 2, "stack_policy": "once"
	}
	store.add(world_effect, &"volcha", &"volcha")
	store.on_battle_end()
	_check(is_equal_approx(store.sum_modifier(&"volcha", &"vision"), 1.0), "World effect survives battle end")
	store.on_world_action_resolved(&"volcha")
	store.on_world_action_resolved(&"volcha")
	_check(is_zero_approx(store.sum_modifier(&"volcha", &"vision")), "World effect expires on world actions")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

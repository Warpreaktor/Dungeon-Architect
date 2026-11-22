class_name GameSession
extends RefCounted

## Состояние конкретного прохождения карты. Не изменяет саму карту.

const VISION_RADIUS := 1
## Число одновременных портретов в походном интерфейсе.
const MAX_PARTY_SIZE: int = 4
const INVENTORY_SLOT_COUNT: int = 40

var map_data: DungeonMap
var hero: HeroState
var party: Array[HeroState] = []
var fallen_heroes: Array[HeroState] = []
var fallen_hero_locations: Array[Dictionary] = []
var _casualty_events: Array[HeroState] = []
var trap_random: RandomNumberGenerator = RandomNumberGenerator.new()
var _party_damage_events: Array[Dictionary] = []
var player_pos := Vector2i(-1, -1)
var steps: int = 0
var keys: int = 0
var potions: int = 0
var carried_items: Dictionary = {} # Количество найденных предметов по ID, без интерфейса инвентаря.
var _inventory_order: Array[String] = []
var is_completed: bool = false # Выход достигнут в текущем прохождении.
var removed_entities: Dictionary = {} # ID объектов, исчезнувших только в этом прохождении.
var opened_chests: Dictionary = {} # ID открытых сундуков только в этом прохождении.
var disarmed_traps: Dictionary = {} # ID разряженных ловушек только в этом прохождении.
var revealed_traps: Dictionary = {}
var pending_chest_id: String = "" # Ожидает завершения анимации шага до открытия сундука.
var activated_triggers: Dictionary = {} # ID сработавших триггеров; обнуляется с новой сессией.
var shown_messages: Dictionary = {} # Авторские сообщения показываются один раз за прохождение.
var _message_events: Array[Dictionary] = []
var _trigger_events: Array[Dictionary] = [] # События последнего хода для игрового контроллера.
var last_event_message: String = ""
var encounter_monster_id: String = ""
var encounter_target := Vector2i(-1, -1)
var debug_open_map: bool = false # Только для теста редактора, никогда не сериализуется.
var _revealed_before_debug_open_map: Array = []
var revealed: Array = [] # revealed[y][x] = bool
var visible: Array = []  # visible[y][x] = bool
var ground_loot_containers: Array[Dictionary] = []
var _ground_loot_counter: int = 0
var claimed_exit_rewards: Dictionary = {}
var _floor_states: Dictionary = {} # Состояние посещённых карт только в памяти этого прохождения.



static func start_for(map_ref: DungeonMap, hero_id: String = HeroCatalog.DEFAULT_HERO_ID, open_map: bool = false) -> GameSession:
	if map_ref == null:
		return null
	var spawn := map_ref.find_entity_position("player_spawn")
	if spawn.x < 0 or spawn.y < 0:
		return null
	var session := GameSession.new()
	session.map_data = map_ref
	session.hero = HeroState.new(HeroCatalog.get_hero(hero_id))
	session.party.append(session.hero)
	session.trap_random.randomize()
	session.player_pos = spawn
	session.debug_open_map = open_map
	session._init_masks()
	session._refresh_visibility()
	session._collect_pickups_at(spawn)
	session._activate_triggers_at(spawn)
	session._activate_message_at(spawn, "enter")
	return session


func equipment_item_id(slot_id: String) -> String:
	if hero == null:
		return ""
	match slot_id:
		"main_hand":
			return hero.equipped_weapon_id
		"off_hand":
			return hero.equipped_shield_id
		_:
			return str(hero.equipped_accessories.get(slot_id, ""))


func inventory_slot_ids() -> Array[String]:
	_inventory_order = _inventory_slots_snapshot()
	return _inventory_order.duplicate()


func _inventory_slots_snapshot() -> Array[String]:
	var bag: Array[String] = []
	bag.assign(_inventory_order)
	if bag.size() != INVENTORY_SLOT_COUNT:
		bag.resize(INVENTORY_SLOT_COUNT)
		bag.fill("")
	var remaining: Dictionary = {}
	for key in carried_items:
		var item_id: String = str(key)
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		if item == null:
			continue
		var count: int = int(carried_items[key])
		if count > 0:
			remaining[item_id] = 1 if item.stackable else count
	for member in party:
		if member == null:
			continue
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			var item_id: String = _member_equipment_id(member, slot_id)
			if not item_id.is_empty():
				remaining[item_id] = maxi(0, int(remaining.get(item_id, 0)) - 1)
	for index in range(bag.size()):
		var item_id: String = bag[index]
		if item_id.is_empty():
			continue
		var count: int = int(remaining.get(item_id, 0))
		if count > 0:
			remaining[item_id] = count - 1
		else:
			bag[index] = ""
	var ids: Array[String] = []
	for key in remaining:
		ids.append(str(key))
	ids.sort()
	for item_id in ids:
		for entry in range(int(remaining[item_id])):
			var empty_index: int = bag.find("")
			if empty_index < 0:
				break
			bag[empty_index] = item_id
	return bag


func swap_inventory_slots(source: int, destination: int) -> bool:
	return transfer_inventory_item("bag", source, "bag", destination)


func _equipment_snapshot() -> Dictionary:
	var current: Dictionary = {}
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		current[slot_id] = equipment_item_id(slot_id)
	return current


func _can_equip_layout(equipped: Dictionary) -> bool:
	var weapon_id: String = str(equipped.get("main_hand", ""))
	var weapon: ItemDefinition = ItemCatalog.get_item(weapon_id)
	if weapon != null and weapon.two_handed and not str(equipped.get("off_hand", "")).is_empty():
		return false
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		var item_id: String = str(equipped.get(slot_id, ""))
		if not item_id.is_empty() and not EquipmentSlotRules.accepts(slot_id, ItemCatalog.get_item(item_id)):
			return false
	return true


func _is_shield(item_id: String) -> bool:
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	return item != null and item.equipment_slot == ItemDefinition.EquipmentSlot.SHIELD


func _shield_layout(bag: Array[String], equipped: Dictionary) -> Dictionary:
	var values_at: Dictionary = {}
	var cursors: Dictionary = {}
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		var item_id: String = str(equipped.get(slot_id, ""))
		if _is_shield(item_id):
			var values: Array = hero.shield_durabilities.get(item_id, [])
			var cursor: int = int(cursors.get(item_id, 0))
			values_at["equipment:%s" % slot_id] = int(values[cursor]) if cursor < values.size() else _new_shield_durability(item_id)
			cursors[item_id] = cursor + 1
	for index in range(bag.size()):
		var item_id: String = bag[index]
		if _is_shield(item_id):
			var values: Array = hero.shield_durabilities.get(item_id, [])
			var cursor: int = int(cursors.get(item_id, 0))
			values_at["bag:%d" % index] = int(values[cursor]) if cursor < values.size() else _new_shield_durability(item_id)
			cursors[item_id] = cursor + 1
	return values_at


func _new_shield_durability(item_id: String) -> int:
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	return maxi(item.max_durability, item.defense_bonus) if item != null else 0


func _apply_shield_layout(bag: Array[String], equipped: Dictionary, values_at: Dictionary) -> void:
	var updated: Dictionary = hero.shield_durabilities.duplicate(true)
	for item_id in updated.keys():
		if _is_shield(str(item_id)):
			updated.erase(item_id)
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		var item_id: String = str(equipped.get(slot_id, ""))
		if _is_shield(item_id):
			var values: Array = updated.get(item_id, [])
			values.append(int(values_at.get("equipment:%s" % slot_id, _new_shield_durability(item_id))))
			updated[item_id] = values
	for index in range(bag.size()):
		var item_id: String = bag[index]
		if _is_shield(item_id):
			var values: Array = updated.get(item_id, [])
			values.append(int(values_at.get("bag:%d" % index, _new_shield_durability(item_id))))
			updated[item_id] = values
	hero.shield_durabilities = updated


func inventory_shield_durability(index: int) -> int:
	var bag: Array[String] = _inventory_slots_snapshot()
	if index < 0 or index >= bag.size() or not _is_shield(bag[index]) or hero == null:
		return 0
	return int(_shield_layout(bag, _equipment_snapshot()).get("bag:%d" % index, 0))


func can_transfer_inventory_item(from_kind: String, from_slot: Variant, to_kind: String, to_slot: Variant) -> bool:
	return _planned_inventory_transfer(from_kind, from_slot, to_kind, to_slot).size() > 0


func transfer_inventory_item(from_kind: String, from_slot: Variant, to_kind: String, to_slot: Variant) -> bool:
	var plan: Dictionary = _planned_inventory_transfer(from_kind, from_slot, to_kind, to_slot)
	if plan.is_empty():
		return false
	_inventory_order = plan["bag"]
	var equipped: Dictionary = plan["equipment"]
	hero.equipped_weapon_id = str(equipped["main_hand"])
	hero.equipped_shield_id = str(equipped["off_hand"])
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		if slot_id != "main_hand" and slot_id != "off_hand":
			var item_id: String = str(equipped[slot_id])
			if item_id.is_empty():
				hero.equipped_accessories.erase(slot_id)
			else:
				hero.equipped_accessories[slot_id] = item_id
	hero._recalculate_equipment_stats()
	_apply_shield_layout(_inventory_order, equipped, plan["shield_layout"])
	return true


func _planned_inventory_transfer(from_kind: String, from_slot: Variant, to_kind: String, to_slot: Variant) -> Dictionary:
	if hero == null or not (from_kind in ["bag", "equipment"]) or not (to_kind in ["bag", "equipment"]):
		return {}
	if (from_kind == "bag" and typeof(from_slot) != TYPE_INT) or (to_kind == "bag" and typeof(to_slot) != TYPE_INT):
		return {}
	var bag: Array[String] = _inventory_slots_snapshot()
	var equipped: Dictionary = _equipment_snapshot()
	var shield_layout: Dictionary = _shield_layout(bag, equipped)
	var source: String = ""
	var target: String = ""
	var source_index: int = -1
	var target_index: int = -1
	var source_slot: String = ""
	var target_slot: String = ""
	if from_kind == "bag":
		source_index = int(from_slot)
		if source_index < 0 or source_index >= bag.size():
			return {}
		source = bag[source_index]
	else:
		source_slot = str(from_slot)
		if not equipped.has(source_slot):
			return {}
		source = str(equipped[source_slot])
	if source.is_empty():
		return {}
	if to_kind == "bag":
		target_index = int(to_slot)
		if target_index < 0 or target_index >= bag.size():
			return {}
		target = bag[target_index]
	else:
		target_slot = str(to_slot)
		if not equipped.has(target_slot):
			return {}
		target = str(equipped[target_slot])
	if from_kind == to_kind and from_slot == to_slot:
		return {}
	if to_kind == "equipment" and not EquipmentSlotRules.accepts(target_slot, ItemCatalog.get_item(source)):
		return {}
	if from_kind == "equipment" and not target.is_empty() and not EquipmentSlotRules.accepts(source_slot, ItemCatalog.get_item(target)):
		return {}
	var source_location: String = "bag:%d" % source_index if from_kind == "bag" else "equipment:%s" % source_slot
	var target_location: String = "bag:%d" % target_index if to_kind == "bag" else "equipment:%s" % target_slot
	var source_durability: Variant = shield_layout.get(source_location)
	var target_durability: Variant = shield_layout.get(target_location)
	shield_layout.erase(source_location)
	shield_layout.erase(target_location)
	if from_kind == "bag":
		bag[source_index] = target
	else:
		equipped[source_slot] = target
	if to_kind == "bag":
		bag[target_index] = source
	else:
		equipped[target_slot] = source
	if source_durability != null:
		shield_layout[target_location] = source_durability
	if target_durability != null:
		shield_layout[source_location] = target_durability
	var current_weapon: ItemDefinition = ItemCatalog.get_item(str(equipped["main_hand"]))
	if current_weapon != null and current_weapon.two_handed and not str(equipped["off_hand"]).is_empty():
		var off_hand: String = str(equipped["off_hand"])
		var free_index: int = bag.find("")
		if free_index < 0:
			return {}
		bag[free_index] = off_hand
		equipped["off_hand"] = ""
		if shield_layout.has("equipment:off_hand"):
			shield_layout["bag:%d" % free_index] = shield_layout["equipment:off_hand"]
			shield_layout.erase("equipment:off_hand")
	if not _can_equip_layout(equipped):
		return {}
	return {"bag": bag, "equipment": equipped, "shield_layout": shield_layout}


func party_members() -> Array[HeroState]:
	var members: Array[HeroState] = []
	members.append_array(party)
	return members


func _member_equipment_id(member: HeroState, slot_id: String) -> String:
	match slot_id:
		"main_hand":
			return member.equipped_weapon_id
		"off_hand":
			return member.equipped_shield_id
		_:
			return str(member.equipped_accessories.get(slot_id, ""))


func _clear_member_equipment(member: HeroState) -> void:
	member.equipped_weapon_id = ""
	member.equipped_shield_id = ""
	member.equipped_accessories.clear()
	member._recalculate_equipment_stats()


func _append_ground_loot(cell: Vector2i, entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		return
	var container: Dictionary = ground_container_at(cell)
	if not container.is_empty():
		var contents: Array = container["loot"]
		contents.append_array(entries)
		return
	_ground_loot_counter += 1
	ground_loot_containers.append({
		"id": "ground_%d" % _ground_loot_counter,
		"x": cell.x, "y": cell.y,
		"loot": entries.duplicate(true)
	})


func ground_container_at(cell: Vector2i) -> Dictionary:
	for container in ground_loot_containers:
		if int(container["x"]) == cell.x and int(container["y"]) == cell.y:
			return container
	return {}


func ground_container_by_id(container_id: String) -> Dictionary:
	for container in ground_loot_containers:
		if str(container["id"]) == container_id:
			return container
	return {}


func _shield_durability_for_drop(member: HeroState, item_id: String) -> int:
	var values: Array = member.shield_durabilities.get(item_id, [])
	if values.is_empty():
		var shield: ItemDefinition = ItemCatalog.get_item(item_id)
		return maxi(shield.max_durability, shield.defense_bonus) if shield != null else 0
	var durability: int = int(values.pop_front())
	member.shield_durabilities[item_id] = values
	return durability


func take_casualty_events() -> Array[HeroState]:
	var events: Array[HeroState] = _casualty_events.duplicate()
	_casualty_events.clear()
	return events


func record_casualties() -> Array[HeroState]:
	var casualties: Array[HeroState] = []
	for member in party:
		if member != null and member.health <= 0:
			casualties.append(member)
	if casualties.is_empty():
		return casualties
	var bag: Array[String] = inventory_slot_ids()
	var bag_shields: Dictionary = _shield_layout(bag, _equipment_snapshot()) if hero != null else {}
	var survivor: HeroState = null
	for member in party:
		if member != null and member.health > 0:
			survivor = member
			break
	if survivor != null:
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			var item_id: String = _member_equipment_id(survivor, slot_id)
			if _is_shield(item_id):
				bag_shields["equipment:%s" % slot_id] = survivor.current_shield_durability(item_id)
	var ground: Array[Dictionary] = []
	var death_gold: int = 0
	for member in casualties:
		var equipped_at_death: Dictionary = {}
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			var item_id: String = _member_equipment_id(member, slot_id)
			if not item_id.is_empty():
				equipped_at_death[slot_id] = item_id
		var durability_at_death: Dictionary = member.shield_durabilities.duplicate(true)
		var member_gold: int = member.gold
		death_gold += member_gold
		member.gold = 0
		if survivor != null:
			for slot_id in equipped_at_death:
				var item_id: String = str(equipped_at_death[slot_id])
				var durability: int = _shield_durability_for_drop(member, item_id) if _is_shield(item_id) else 0
				var free: int = bag.find("")
				if free >= 0:
					bag[free] = item_id
					if _is_shield(item_id):
						bag_shields["bag:%d" % free] = durability
				else:
					carried_items[item_id] = maxi(int(carried_items.get(item_id, 0)) - 1, 0)
					var entry: Dictionary = {"item_id": item_id, "quantity": 1}
					if _is_shield(item_id):
						entry["durabilities"] = [durability]
					ground.append(entry)
		_clear_member_equipment(member)
		fallen_heroes.append(member)
		fallen_hero_locations.append({
			"hero": member, "map_id": map_data.map_id,
			"position": player_pos, "equipment_at_death": equipped_at_death,
			"shield_durabilities_at_death": durability_at_death,
			"gold_at_death": member_gold
		})
		party.erase(member)
	if survivor == null:
		for key in carried_items:
			var item_id: String = str(key)
			var amount: int = int(carried_items[key])
			if amount <= 0:
				continue
			var entry: Dictionary = {"item_id": item_id, "quantity": amount}
			if _is_shield(item_id):
				var durabilities: Array = []
				for member in casualties:
					durabilities.append_array(member.shield_durabilities.get(item_id, []))
				entry["durabilities"] = durabilities
			ground.append(entry)
		carried_items.clear()
		bag.fill("")
		for member in casualties:
			member.shield_durabilities.clear()
	else:
		hero = survivor
		_apply_shield_layout(bag, _equipment_snapshot(), bag_shields)
		for member in casualties:
			member.shield_durabilities.clear()
	if death_gold > 0:
		ground.append({"item_id": "gold", "quantity": death_gold})
	_inventory_order = bag
	keys = int(carried_items.get("key", 0))
	potions = int(carried_items.get("potion", 0))
	_append_ground_loot(player_pos, ground)
	hero = survivor
	_casualty_events.append_array(casualties)
	return casualties


func _ground_loot_take_count(entry: Dictionary) -> int:
	var item_id: String = str(entry.get("item_id", ""))
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	var quantity: int = int(entry.get("quantity", 0))
	if hero == null or item == null or quantity <= 0:
		return 0
	if item.category == ItemDefinition.Category.CURRENCY:
		return quantity
	var bag: Array[String] = _inventory_slots_snapshot()
	if bag.find("") < 0 and not (item.stackable and bag.has(item_id)):
		return 0
	return quantity if item.stackable else 1


func can_take_ground_loot(container_id: String, entry_index: int) -> bool:
	var container: Dictionary = ground_container_by_id(container_id)
	if container.is_empty() or is_party_defeated():
		return false
	var cell := Vector2i(int(container["x"]), int(container["y"]))
	if absi(cell.x - player_pos.x) + absi(cell.y - player_pos.y) > 1:
		return false
	var loot: Array = container["loot"]
	return entry_index >= 0 and entry_index < loot.size() and _ground_loot_take_count(loot[entry_index]) > 0


func take_ground_loot(container_id: String, entry_index: int) -> int:
	if not can_take_ground_loot(container_id, entry_index):
		return 0
	var container: Dictionary = ground_container_by_id(container_id)
	var loot: Array = container["loot"]
	var entry: Dictionary = loot[entry_index]
	var item_id: String = str(entry["item_id"])
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	var amount: int = _ground_loot_take_count(entry)
	if item.category == ItemDefinition.Category.CURRENCY:
		hero.gold += amount
	else:
		var bag: Array[String] = _inventory_slots_snapshot()
		var equipped: Dictionary = _equipment_snapshot()
		var shield_layout: Dictionary = _shield_layout(bag, equipped)
		if not (item.stackable and bag.has(item_id)):
			var free: int = bag.find("")
			if free < 0:
				return 0
			bag[free] = item_id
			if _is_shield(item_id):
				var durabilities: Array = entry.get("durabilities", [])
				shield_layout["bag:%d" % free] = int(durabilities.pop_front()) if not durabilities.is_empty() else _new_shield_durability(item_id)
				entry["durabilities"] = durabilities
		_inventory_order = bag
		carried_items[item_id] = int(carried_items.get(item_id, 0)) + amount
		if _is_shield(item_id):
			_apply_shield_layout(bag, equipped, shield_layout)
		keys = int(carried_items.get("key", 0))
		potions = int(carried_items.get("potion", 0))
	entry["quantity"] = int(entry["quantity"]) - amount
	if int(entry["quantity"]) <= 0:
		loot.remove_at(entry_index)
	if loot.is_empty():
		ground_loot_containers.erase(container)
	return amount


func abandon_pending_encounter() -> void:
	encounter_monster_id = ""
	encounter_target = Vector2i(-1, -1)


func add_party_member(hero_id: String) -> bool:
	if not HeroCatalog.has(hero_id):
		return false
	if party.size() >= MAX_PARTY_SIZE or (party.is_empty() and not fallen_heroes.is_empty()):
		return false
	var member := HeroState.new(HeroCatalog.get_hero(hero_id))
	party.append(member)
	if hero == null:
		hero = member
	return true


func is_party_defeated() -> bool:
	for member in party:
		if member != null and member.health > 0:
			return false
	return true


func has_party_damage_events() -> bool:
	return not _party_damage_events.is_empty()


func take_party_damage_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = _party_damage_events.duplicate(true)
	_party_damage_events.clear()
	return result


func _record_party_damage(member: HeroState, damage: int, source: String) -> void:
	if damage <= 0:
		return
	var index: int = party_members().find(member)
	_party_damage_events.append({"hero_index": index, "member": member, "damage": damage, "source": source})


func _random_living_party_member() -> HeroState:
	var living: Array[HeroState] = []
	for member in party_members():
		if member != null and member.health > 0:
			living.append(member)
	if living.is_empty():
		return null
	return living[trap_random.randi_range(0, living.size() - 1)]


## Переход между этажами без пересоздания героя и инвентаря.
## Повторное посещение восстанавливает открытые двери, сундуки и исследованные клетки.
func enter_map(next_map: DungeonMap) -> bool:
	if is_party_defeated() or next_map == null or next_map.map_id.is_empty():
		return false
	var spawn := next_map.find_entity_position("player_spawn")
	if spawn.x < 0 or spawn.y < 0 or next_map.get_terrain(spawn.x, spawn.y) == "wall":
		return false
	if map_data != null:
		_floor_states[map_data.map_id] = {
			"map": map_data,
			"ground_loot": ground_loot_containers.duplicate(true),
			"exit_rewards": claimed_exit_rewards.duplicate(true),
			"position": player_pos,
			"removed": removed_entities.duplicate(true),
			"chests": opened_chests.duplicate(true),
			"traps": disarmed_traps.duplicate(true),
			"revealed_traps": revealed_traps.duplicate(true),
			"triggers": activated_triggers.duplicate(true),
			"messages": shown_messages.duplicate(true),
			"revealed": revealed.duplicate(true)
		}
	var saved: Dictionary = _floor_states.get(next_map.map_id, {})
	map_data = saved.get("map", next_map)
	ground_loot_containers.clear()
	for container in saved.get("ground_loot", []):
		ground_loot_containers.append(container.duplicate(true))
	claimed_exit_rewards = saved.get("exit_rewards", {}).duplicate(true)
	player_pos = saved.get("position", spawn)
	removed_entities = saved.get("removed", {}).duplicate(true)
	opened_chests = saved.get("chests", {}).duplicate(true)
	disarmed_traps = saved.get("traps", {}).duplicate(true)
	revealed_traps = saved.get("revealed_traps", {}).duplicate(true)
	pending_chest_id = ""
	activated_triggers = saved.get("triggers", {}).duplicate(true)
	shown_messages = saved.get("messages", {}).duplicate(true)
	encounter_monster_id = ""
	encounter_target = Vector2i(-1, -1)
	is_completed = false
	last_event_message = ""
	_message_events.clear()
	_trigger_events.clear()
	_party_damage_events.clear()
	_casualty_events.clear()
	_init_masks()
	if saved.has("revealed"):
		revealed = saved["revealed"].duplicate(true)
	else:
		_collect_pickups_at(player_pos)
		_activate_triggers_at(player_pos)
		_activate_message_at(player_pos, "enter")
	_refresh_visibility()
	return true


func next_map_id() -> String:
	if not is_completed:
		return ""
	var stairs := _find_active_entity(player_pos, "stairs_down")
	if stairs.is_empty():
		return ""
	return DungeonMap.stairs_target_id(stairs)


func _init_masks() -> void:
	_revealed_before_debug_open_map.clear()
	revealed.clear()
	visible.clear()
	for y in range(map_data.height):
		var revealed_row: Array = []
		var visible_row: Array = []
		for x in range(map_data.width):
			revealed_row.append(false)
			visible_row.append(false)
		revealed.append(revealed_row)
		visible.append(visible_row)


func contains(x: int, y: int) -> bool:
	return map_data != null and map_data.contains(x, y)


func is_revealed(x: int, y: int) -> bool:
	return contains(x, y) and bool(revealed[y][x])


func is_visible(x: int, y: int) -> bool:
	return contains(x, y) and bool(visible[y][x])


func is_entity_removed(entity: Dictionary) -> bool:
	return removed_entities.has(str(entity.get("id", "")))


func is_chest_open(entity: Dictionary) -> bool:
	return opened_chests.has(str(entity.get("id", "")))


func is_entity_hidden_from_hero(entity: Dictionary) -> bool:
	if str(entity.get("type", "")) == "trap" and is_trap_revealed(entity):
		return false
	return DungeonMap.is_entity_hidden(entity) and (hero == null or not hero.has_vision_effect())


func is_trap_disarmed(entity: Dictionary) -> bool:
	return disarmed_traps.has(str(entity.get("id", "")))


func is_trap_revealed(entity: Dictionary) -> bool:
	return revealed_traps.has(str(entity.get("id", ""))) or is_trap_disarmed(entity)


func entities_at(x: int, y: int) -> Array:
	var result: Array = map_data.entities_at(x, y)
	var container: Dictionary = ground_container_at(Vector2i(x, y))
	if not container.is_empty():
		result.append({"type": "ground_loot", "id": container["id"], "x": x, "y": y})
	return result


func _find_active_entity(cell: Vector2i, kind: String) -> Dictionary:
	for entity in entities_at(cell.x, cell.y):
		if str(entity["type"]) == kind and not is_entity_removed(entity):
			return entity
	return {}


func has_pending_encounter() -> bool:
	return not encounter_monster_id.is_empty()


## Возвращает описание монстра для следующего поединка; старые карты получают базовый тип.
func pending_monster_definitions() -> Array[MonsterDefinition]:
	var result: Array[MonsterDefinition] = []
	if not has_pending_encounter():
		return result
	for entity in map_data.entities:
		if str(entity.get("id", "")) != encounter_monster_id or str(entity.get("type", "")) != "monster":
			continue
		for monster_id in DungeonMap.monster_party_ids(entity):
			result.append(MonsterCatalog.get_monster(monster_id))
		break
	return result


func pending_monster_definition() -> MonsterDefinition:
	var definitions: Array[MonsterDefinition] = pending_monster_definitions()
	return definitions[0] if not definitions.is_empty() else MonsterCatalog.get_monster(MonsterCatalog.DEFAULT_MONSTER_ID)


## Победа снимает монстра только в сессии, затем повторяет вход в клетку
## через обычные правила дверей, сундуков и находок.
func win_pending_encounter() -> bool:
	if not has_pending_encounter() or hero == null or hero.health <= 0:
		return false
	var target: Vector2i = encounter_target
	var defeated_id: String = encounter_monster_id
	var defeated: Dictionary = {}
	for entity in map_data.entities:
		if str(entity.get("id", "")) == defeated_id and str(entity.get("type", "")) == "monster":
			defeated = entity
			break
	removed_entities[defeated_id] = true
	encounter_monster_id = ""
	encounter_target = Vector2i(-1, -1)
	var rewards: Array[Dictionary] = []
	if not defeated.is_empty():
		rewards = _resolve_rewards(
			DungeonMap.monster_loot_contents(defeated),
			DungeonMap.monster_loot_is_random(defeated),
			DungeonMap.monster_gold_amount(defeated),
			DungeonMap.monster_item_quantities(defeated))
		for reward in rewards:
			_receive_item(str(reward["item_id"]), int(reward["quantity"]), reward.get("durabilities", []))
		if not rewards.is_empty():
			_activate_message_at(target, "monster_defeated", defeated_id, rewards)
	return move_by(target.x - player_pos.x, target.y - player_pos.y)


## Отдаём события ровно один раз; они не являются всплывающими игровыми сообщениями.
func take_trigger_events() -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	for event in _trigger_events:
		pending.append(event)
	_trigger_events.clear()
	return pending


func _activate_triggers_at(cell: Vector2i) -> void:
	for entity in map_data.entities_at(cell.x, cell.y):
		if str(entity.get("type", "")) != "trigger":
			continue
		var entity_id := str(entity.get("id", ""))
		if activated_triggers.has(entity_id):
			continue
		activated_triggers[entity_id] = true
		var properties: Dictionary = entity.get("properties", {})
		_trigger_events.append({
			"entity_id": entity_id,
			"event_id": str(properties.get("event_id", "")),
			"position": cell
		})


## Авторские события потребляются контроллером интерфейса, состояние карты не меняется.
func take_message_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = _message_events.duplicate(true)
	_message_events.clear()
	return result


func _activate_message_at(cell: Vector2i, activation: String, target_id: String = "", loot: Array[Dictionary] = []) -> void:
	var message := map_data.message_at(cell.x, cell.y)
	var authored_text := ""
	if not message.is_empty():
		var message_id := str(message.get("id", ""))
		if not shown_messages.has(message_id):
			var properties: Dictionary = message.get("properties", {})
			var stored_activation := str(properties.get("activation", "enter"))
			var stored_target := str(properties.get("target_entity_id", ""))
			var matches := stored_activation == activation and (activation == "enter" or stored_target == target_id)
			# Совместимость: послания на монстрах и сундуках старых карт были привязаны к входу.
			if not matches and stored_activation == "enter" and activation in ["monster_encounter", "chest_open"]:
				matches = true
			if matches:
				authored_text = str(properties.get("text", "")).strip_edges()
				if not authored_text.is_empty():
					shown_messages[message_id] = true
	if not authored_text.is_empty() or not loot.is_empty():
		_message_events.append({"text": authored_text, "activation": activation, "loot": loot.duplicate(true)})


func _append_event_message(message: String) -> void:
	var clean := message.strip_edges()
	if clean.is_empty():
		return
	if last_event_message.is_empty():
		last_event_message = clean
	else:
		last_event_message += "  " + clean


func _activate_traps_at(cell: Vector2i) -> void:
	for entity in map_data.entities_at(cell.x, cell.y):
		if str(entity.get("type", "")) != "trap" or is_trap_disarmed(entity):
			continue
		var trap: TrapDefinition = TrapCatalog.from_entity(entity)
		if trap == null:
			continue
		var target: HeroState = _random_living_party_member()
		if target == null:
			continue
		revealed_traps[str(entity.get("id", ""))] = true
		var parts: Array[String] = []
		if trap.direct_damage > 0:
			var health_before: int = target.health
			target.take_damage(trap.direct_damage)
			var damage: int = health_before - target.health
			if damage > 0:
				_record_party_damage(target, damage, trap.trap_id)
				parts.append("-%d HP" % damage)
		if target.health > 0 and trap.applies_overworld_status():
			if target.apply_overworld_status(trap.overworld_status_id, trap.overworld_status_label,
				trap.overworld_status_damage, trap.overworld_status_ticks, trap.overworld_status_interval_steps):
				parts.append("%s %d на %d фазы" % [
					trap.overworld_status_label,
					trap.overworld_status_damage,
					trap.overworld_status_ticks
				])
		if not parts.is_empty():
			_append_event_message("%s: ловушка «%s», %s." % [
				target.definition.display_name, trap.display_name, " и ".join(parts)
			])
		if trap.disarm_on_trigger:
			disarmed_traps[str(entity.get("id", ""))] = true


func can_enter(cell: Vector2i) -> bool:
	return contains(cell.x, cell.y) and map_data.get_terrain(cell.x, cell.y) != "wall"


func move_by(dx: int, dy: int, defer_chest_open: bool = false) -> bool:
	last_event_message = ""
	_trigger_events.clear()
	_party_damage_events.clear()
	if is_party_defeated() or has_pending_encounter() or is_completed or not pending_chest_id.is_empty():
		return false
	var target := player_pos + Vector2i(dx, dy)
	if not can_enter(target):
		return false

	# Встреча инициирует поединок. Монстр исчезнет только после победы.
	var monster := _find_active_entity(target, "monster")
	if not monster.is_empty():
		encounter_monster_id = str(monster["id"])
		encounter_target = target
		_activate_message_at(target, "monster_encounter", encounter_monster_id)
		return false

	var door := _find_active_entity(target, "door")
	var opened_door_id := ""
	if not door.is_empty():
		var required_key: String = LockCatalog.required_key(door)
		if int(carried_items.get(required_key, 0)) <= 0:
			last_event_message = "Дверь заперта. Нужен %s ключ." % LockCatalog.label(required_key).to_lower()
			return false
		_remove_carried_item(required_key, 1)
		opened_door_id = str(door["id"])
		removed_entities[opened_door_id] = true
		last_event_message = "Ключ использован. Дверь открыта!"

	# Проверка сундука после двери: нельзя получить добычу через замок.
	var chest := _find_active_entity(target, "chest")
	if not chest.is_empty() and not is_chest_open(chest) and (DungeonMap.chest_is_random(chest) or not DungeonMap.chest_contents(chest).is_empty()):
		if defer_chest_open:
			pending_chest_id = str(chest["id"])
		else:
			_open_chest(chest)

	player_pos = target
	steps += 1
	for member in party_members():
		if member == null or member.health <= 0:
			continue
		member.advance_effects()
		for status_event in member.advance_overworld_statuses():
			var label: String = str(status_event.get("label", ""))
			var amount: int = int(status_event.get("damage", 0))
			if amount > 0:
				_record_party_damage(member, amount, str(status_event.get("status_id", "")))
				_append_event_message("%s: %s, -%d HP" % [member.definition.display_name, label, amount])
	if not is_party_defeated():
		_activate_traps_at(target)
	record_casualties()
	if is_party_defeated():
		_refresh_visibility()
		return true
	_collect_pickups_at(target)
	_activate_triggers_at(target)
	if not opened_door_id.is_empty():
		_activate_message_at(target, "door_open", opened_door_id)
	else:
		_activate_message_at(target, "enter")
	_refresh_visibility()
	# Пока лестница завершает приключение. Позже здесь появится переход на другую карту.
	var stairs: Dictionary = _find_active_entity(target, "stairs_down")
	if not stairs.is_empty():
		_claim_exit_reward(stairs)
		is_completed = true
	return true


## Завершает открытие сундука только после визуального прибытия героя.
func open_pending_chest() -> bool:
	if pending_chest_id.is_empty():
		return false
	var chest_id := pending_chest_id
	pending_chest_id = ""
	var chest := _find_active_entity(player_pos, "chest")
	if chest.is_empty() or str(chest.get("id", "")) != chest_id or is_chest_open(chest):
		return false
	_open_chest(chest)
	return true


## Случайная награда разыгрывается в момент открытия и живёт только в GameSession.
func _resolve_rewards(contents: Array[String], random_mode: bool, gold_amount: int, quantities: Dictionary = {}) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	if random_mode:
		rewards.append(ItemCatalog.roll_loot())
	else:
		for item_id in contents:
			var item: ItemDefinition = ItemCatalog.get_item(item_id)
			if item == null:
				continue
			var fallback: int = gold_amount if item_id == "gold" else item.default_quantity
			var quantity: int = clampi(int(quantities.get(item_id, fallback)), 1, 999999 if item_id == "gold" else 9999)
			rewards.append({"item_id": item_id, "quantity": quantity})
	return rewards


func _open_chest(chest: Dictionary) -> void:
	opened_chests[str(chest["id"])] = true
	var rewards: Array[Dictionary] = _resolve_rewards(
		DungeonMap.chest_contents(chest),
		DungeonMap.chest_is_random(chest),
		DungeonMap.chest_gold_amount(chest),
		DungeonMap.chest_item_quantities(chest))
	for reward in rewards:
		_receive_item(str(reward["item_id"]), int(reward["quantity"]))
	_activate_message_at(Vector2i(int(chest["x"]), int(chest["y"])), "chest_open", str(chest["id"]), rewards)


## Общая логика подбора. Описание предмета — Resource, состояние находок — GameSession.
func _receive_item(item_id: String, quantity: int, durabilities: Array = []) -> int:
	if item_id == "key_yellow":
		item_id = "key"
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	if item == null or quantity <= 0 or hero == null:
		return 0
	if item.category == ItemDefinition.Category.CURRENCY:
		hero.gold += quantity
		return quantity
	var bag: Array[String] = _inventory_slots_snapshot()
	var equipped: Dictionary = _equipment_snapshot()
	var shield_layout: Dictionary = _shield_layout(bag, equipped)
	var received: int = 0
	var overflow_durabilities: Array = []
	for index in range(quantity):
		var location: String = ""
		if item.stackable and bag.has(item_id):
			location = "stack"
		elif not item.stackable and item.category == ItemDefinition.Category.EQUIPMENT:
			if item.equipment_slot == ItemDefinition.EquipmentSlot.WEAPON and str(equipped["main_hand"]).is_empty():
				if not (item.two_handed and not str(equipped["off_hand"]).is_empty()):
					location = "equipment:main_hand"
			elif item.equipment_slot == ItemDefinition.EquipmentSlot.SHIELD and str(equipped["off_hand"]).is_empty():
				var weapon: ItemDefinition = ItemCatalog.get_item(str(equipped["main_hand"]))
				if weapon == null or not weapon.two_handed:
					location = "equipment:off_hand"
		if location.is_empty():
			var free: int = bag.find("")
			if free >= 0:
				location = "bag:%d" % free
				bag[free] = item_id
		if location.is_empty():
			if _is_shield(item_id):
				overflow_durabilities.append(int(durabilities[index]) if index < durabilities.size() else _new_shield_durability(item_id))
			continue
		if location.begins_with("equipment:"):
			equipped[location.trim_prefix("equipment:")] = item_id
		if _is_shield(item_id) and location != "stack":
			shield_layout[location] = int(durabilities[index]) if index < durabilities.size() else _new_shield_durability(item_id)
		received += 1
	if received > 0:
		carried_items[item_id] = int(carried_items.get(item_id, 0)) + received
		_inventory_order = bag
		hero.equipped_weapon_id = str(equipped["main_hand"])
		hero.equipped_shield_id = str(equipped["off_hand"])
		hero._recalculate_equipment_stats()
		if _is_shield(item_id):
			_apply_shield_layout(bag, equipped, shield_layout)
		keys = int(carried_items.get("key", 0))
		potions = int(carried_items.get("potion", 0))
	var overflow: int = quantity - received
	if overflow > 0:
		var entry: Dictionary = {"item_id": item_id, "quantity": overflow}
		if _is_shield(item_id):
			entry["durabilities"] = overflow_durabilities
		_append_ground_loot(player_pos, [entry])
	return received


## Боевой пояс: только расходники, применимые к бойцу вне исполнения фазы.
static func is_combat_item(item: ItemDefinition) -> bool:
	if item == null or item.category != ItemDefinition.Category.CONSUMABLE:
		return false
	return item.consumable_effect in [
		ItemDefinition.ConsumableEffect.HEAL,
		ItemDefinition.ConsumableEffect.ATTACK,
		ItemDefinition.ConsumableEffect.RESIST
	] or (item.consumable_effect == ItemDefinition.ConsumableEffect.NONE and item.healing_amount > 0)


func combat_item_ids() -> Array[String]:
	var result: Array[String] = []
	for key in carried_items:
		var item_id: String = str(key)
		if int(carried_items[item_id]) > 0 and is_combat_item(ItemCatalog.get_item(item_id)):
			result.append(item_id)
	result.sort()
	return result


## Применение через модель. Нельзя использовать предмет в момент проигрывания
## алгоритма; нельзя потратить один флакон дважды.
func use_combat_item(item_id: String, battle: BattleState) -> Dictionary:
	if battle == null or not battle.flow.can_use_item():
		return {"used": false, "message": "Сейчас предмет недоступен."}
	if hero == null or battle.get_hero() == null or battle.get_hero()._hero_snapshot == null:
		return {"used": false, "message": "Герой недоступен."}
	var definition: ItemDefinition = ItemCatalog.get_item(item_id)
	if not is_combat_item(definition):
		return {"used": false, "message": "Предмет нельзя использовать в бою."}
	var outcome: Dictionary = use_item(item_id)
	if bool(outcome.get("used", false)):
		battle.get_hero().sync_consumable_from_hero(hero)
		battle.events.append({"type": "item_used", "actor_id": battle.hero_id,
			"item_id": item_id, "message": outcome.get("message", "")})
	return outcome


## Инвентарь лишь запрашивает действие: предметы и здоровье изменяет игровая сессия.
## Снаряжение не расходуется при надевании.
func equip_item(item_id: String) -> bool:
	if hero == null or int(carried_items.get(item_id, 0)) <= 0:
		return false
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	if item == null or item.category != ItemDefinition.Category.EQUIPMENT:
		return false
	var bag: Array[String] = _inventory_slots_snapshot()
	var source: int = bag.find(item_id)
	if source < 0:
		return false
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		if EquipmentSlotRules.accepts(slot_id, item) and equipment_item_id(slot_id).is_empty():
			if transfer_inventory_item("bag", source, "equipment", slot_id):
				return true
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		if EquipmentSlotRules.accepts(slot_id, item) and equipment_item_id(slot_id) != item_id:
			if transfer_inventory_item("bag", source, "equipment", slot_id):
				return true
	return false


func unequip_item(item_id: String) -> bool:
	if hero == null or item_id.is_empty():
		return false
	var bag: Array[String] = _inventory_slots_snapshot()
	var free: int = bag.find("")
	if free < 0:
		return false
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		if equipment_item_id(slot_id) == item_id:
			return transfer_inventory_item("equipment", slot_id, "bag", free)
	return false


## Выполняется после ответной атаки; удаляем только сломанный экземпляр.
func resolve_broken_shield() -> String:
	if hero == null or hero.last_shield_broken.is_empty():
		return ""
	var item_id: String = hero.last_shield_broken
	hero.last_shield_broken = ""
	var count: int = int(carried_items.get(item_id, 0))
	if count > 0:
		carried_items[item_id] = count - 1
	return item_id


## Сообщение используется в самом окне инвентаря, не как всплывающий игровой диалог.
func use_item(item_id: String) -> Dictionary:
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	if item == null or int(carried_items.get(item_id, 0)) <= 0:
		return {"used": false, "message": "Этого предмета нет в рюкзаке."}
	if hero == null:
		return {"used": false, "message": "Герой недоступен."}
	var result: Dictionary = hero.apply_potion(item)
	if bool(result.get("used", false)):
		_remove_carried_item(item_id, 1)
		_refresh_visibility()
	return result


func _remove_carried_item(item_id: String, quantity: int) -> bool:
	var current: int = int(carried_items.get(item_id, 0))
	if quantity <= 0 or current < quantity:
		return false
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	var bag: Array[String] = _inventory_slots_snapshot()
	var shield_layout: Dictionary = _shield_layout(bag, _equipment_snapshot()) if hero != null and _is_shield(item_id) else {}
	var equipped_count: int = 0
	for member in party:
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			if _member_equipment_id(member, slot_id) == item_id:
				equipped_count += 1
	if current - quantity < equipped_count:
		return false
	if item != null and not item.stackable:
		var count_in_bag: int = bag.count(item_id)
		if count_in_bag < quantity:
			return false
		for removed in range(mini(count_in_bag, quantity)):
			var index: int = bag.find(item_id)
			bag[index] = ""
			shield_layout.erase("bag:%d" % index)
	elif current == quantity:
		var index: int = bag.find(item_id)
		if index >= 0:
			bag[index] = ""
	carried_items[item_id] = current - quantity
	_inventory_order = bag
	if _is_shield(item_id) and hero != null:
		_apply_shield_layout(bag, _equipment_snapshot(), shield_layout)
	keys = int(carried_items.get("key", 0))
	potions = int(carried_items.get("potion", 0))
	return true


func _collect_pickups_at(cell: Vector2i) -> void:
	for entity in map_data.entities_at(cell.x, cell.y):
		if is_entity_removed(entity):
			continue
		var item_id: String = str(entity.get("type", ""))
		var item := ItemCatalog.get_item(item_id)
		if item == null:
			continue
		var quantity: int = ItemCatalog.quantity_for_entity(entity)
		var received: int = _receive_item(item_id, quantity)
		removed_entities[str(entity["id"])] = true
		if received > 0:
			var pickup_message := "Получено: %s ×%d" % [item.display_name, received]
			_append_event_message(pickup_message)


func set_debug_open_map(enabled: bool) -> void:
	if debug_open_map == enabled:
		return
	debug_open_map = enabled
	if not enabled:
		if _revealed_before_debug_open_map.size() == revealed.size():
			revealed = _revealed_before_debug_open_map.duplicate(true)
		_revealed_before_debug_open_map.clear()
	_refresh_visibility()


func _refresh_visibility() -> void:
	if debug_open_map and _revealed_before_debug_open_map.is_empty():
		_revealed_before_debug_open_map = revealed.duplicate(true)
	for y in range(map_data.height):
		for x in range(map_data.width):
			visible[y][x] = debug_open_map
			if debug_open_map:
				revealed[y][x] = true
	if debug_open_map:
		return
	var radius: int = VISION_RADIUS + (hero.vision_bonus if hero != null and hero.has_vision_effect() else 0)
	for y in range(player_pos.y - radius, player_pos.y + radius + 1):
		for x in range(player_pos.x - radius, player_pos.x + radius + 1):
			if contains(x, y):
				visible[y][x] = true
				revealed[y][x] = true


func _claim_exit_reward(stairs: Dictionary) -> void:
	var entity_id: String = str(stairs["id"])
	if claimed_exit_rewards.has(entity_id):
		return
	claimed_exit_rewards[entity_id] = true
	var rewards: Array[Dictionary] = _resolve_rewards(DungeonMap.chest_contents(stairs), false,
		DungeonMap.chest_gold_amount(stairs), DungeonMap.chest_item_quantities(stairs))
	for reward in rewards:
		_receive_item(str(reward["item_id"]), int(reward["quantity"]))
	if not rewards.is_empty():
		_message_events.append({"text": "Награда за прохождение подземелья", "activation": "exit_reward", "loot": rewards})

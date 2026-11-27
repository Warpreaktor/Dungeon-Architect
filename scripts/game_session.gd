class_name GameSession
extends RefCounted

## Состояние конкретного прохождения карты. Не изменяет саму карту.

const VISION_RADIUS := 1
## Число одновременных портретов в походном интерфейсе.
const MAX_PARTY_SIZE: int = 4
const INVENTORY_SLOT_COUNT: int = 40

var map_data: DungeonMap
var campaign_id: String = ""
var _campaign_map_ids: Dictionary = {}
var hero: HeroState
var inventory_member: HeroState
var party: Array[HeroState] = []
var fallen_heroes: Array[HeroState] = []
var fallen_hero_locations: Array[Dictionary] = []
var _casualty_events: Array[HeroState] = []
var trap_random: RandomNumberGenerator = RandomNumberGenerator.new()
var _party_damage_events: Array[Dictionary] = []
var player_pos := Vector2i(-1, -1)
var steps: int = 0
var loot_victories: int = 0
var keys: int = 0
var potions: int = 0
var carried_items: Dictionary = {} # Количество найденных предметов по ID, без интерфейса инвентаря.
var _inventory_order: Array[String] = []
var _bag_quantities: Array[int] = []
var _item_instances: Dictionary = {}
var _bag_instance_ids: Array[String] = []
var _next_item_instance_number: int = 0
var is_completed: bool = false # Выход достигнут в текущем прохождении.
var removed_entities: Dictionary = {} # ID объектов, исчезнувших только в этом прохождении.
var opened_chests: Dictionary = {} # ID открытых сундуков только в этом прохождении.
var disarmed_traps: Dictionary = {} # Неактивные механизмы текущего этажа.
var revealed_traps: Dictionary = {}
var discharged_traps: Dictionary = {}
var failed_trap_disarms: Dictionary = {}
var last_move_detected_trap: bool = false
var pending_chest_id: String = "" # Ожидает завершения анимации шага до открытия сундука.
var pending_door_trap_id: String = ""
var pending_door_trap_cell := Vector2i(-1, -1)
var _pending_door_opener: HeroState
var _pending_door_accepted: Array[String] = []
var _pending_trap_choice: Dictionary = {}
var _pending_trap_actors: Array[HeroState] = []
var _pending_trap_accepted: Array[String] = []
var _pending_trap_opener: HeroState
var _trap_result_messages: Array[String] = []
var _trap_visual_events: Array[Dictionary] = []
var activated_triggers: Dictionary = {} # ID сработавших триггеров; обнуляется с новой сессией.
var shown_messages: Dictionary = {} # Авторские сообщения показываются один раз за прохождение.
var _message_events: Array[Dictionary] = []
var _trigger_events: Array[Dictionary] = [] # События последнего хода для игрового контроллера.
var last_event_message: String = ""
var encounter_monster_id: String = ""
var encounter_target := Vector2i(-1, -1)
var debug_open_map: bool = false # Только для теста редактора, никогда не сериализуется.
var is_editor_test: bool = false
var _revealed_before_debug_open_map: Array = []
var revealed: Array = [] # revealed[y][x] = bool
var visible: Array = []  # visible[y][x] = bool
var _ground_loot_containers: Array[Dictionary] = []
var _ground_by_cell: Dictionary = {}
var _ground_by_id: Dictionary = {}
var _visible_bounds := Rect2i()
var _debug_visibility_applied: bool = false
var ground_loot_containers: Array[Dictionary]:
	get:
		return _ground_loot_containers.duplicate(true)
var _ground_loot_counter: int = 0
var claimed_exit_rewards: Dictionary = {}
var _floor_states: Dictionary = {} # Состояние посещённых карт только в памяти этого прохождения.
var _stairs_history: Array[Dictionary] = []
var _pending_return_exit: Dictionary = {}



func _init() -> void:
	_inventory_order.resize(INVENTORY_SLOT_COUNT)
	_inventory_order.fill("")
	_bag_quantities.resize(INVENTORY_SLOT_COUNT)
	_bag_quantities.fill(0)
	_bag_instance_ids.resize(INVENTORY_SLOT_COUNT)
	_bag_instance_ids.fill("")


static func start_for(map_ref: DungeonMap, hero_id: String = HeroCatalog.DEFAULT_HERO_ID, open_map: bool = false, rng: RandomNumberGenerator = null) -> GameSession:
	return start_for_party(map_ref, [hero_id], open_map, rng)


static func start_for_party(map_ref: DungeonMap, hero_ids: Array[String], open_map: bool = false, rng: RandomNumberGenerator = null) -> GameSession:
	if hero_ids.is_empty() or hero_ids.size() > MAX_PARTY_SIZE:
		return null
	var unique_ids: Dictionary = {}
	for hero_id in hero_ids:
		if not HeroCatalog.has(hero_id) or unique_ids.has(hero_id):
			return null
		unique_ids[hero_id] = true
	if map_ref == null:
		return null
	var spawn := map_ref.find_entity_position("player_spawn")
	if spawn.x < 0 or spawn.y < 0:
		return null
	ItemCatalog.prepare()
	LootProfileCatalog.prepare()
	var session := GameSession.new()
	session.map_data = map_ref
	for hero_id in hero_ids:
		var member := HeroState.new(HeroCatalog.get_hero(hero_id))
		session.party.append(member)
		session._register_member_instances(member)
		if not member.equipped_weapon_id.is_empty():
			session.carried_items[member.equipped_weapon_id] = int(session.carried_items.get(member.equipped_weapon_id, 0)) + 1
	session.hero = session.party[0]
	if rng == null:
		session.trap_random.randomize()
	else:
		session.trap_random = rng
	session.player_pos = spawn
	session.debug_open_map = open_map
	session._init_masks()
	session._refresh_visibility()
	session._collect_pickups_at(spawn)
	session._activate_triggers_at(spawn)
	session._activate_message_at(spawn, "enter")
	return session


func set_campaign(campaign: CampaignDefinition) -> bool:
	if campaign == null or map_data == null or not campaign.map_ids.has(map_data.map_id):
		return false
	var allowed: Dictionary = {}
	for map_id in campaign.map_ids:
		allowed[map_id] = true
	campaign_id = campaign.campaign_id
	_campaign_map_ids = allowed
	return true


func is_map_in_campaign(map_id: String) -> bool:
	return _campaign_map_ids.has(map_id) if not campaign_id.is_empty() else not OfficialCampaignLibrary.is_official_id(map_id)


func equipment_item_id(slot_id: String) -> String:
	return _member_equipment_id(_inventory_equipment_member(), slot_id)


func _inventory_equipment_member() -> HeroState:
	return inventory_member if inventory_member != null and party.has(inventory_member) else hero


func inventory_slot_ids() -> Array[String]:
	return _inventory_order.duplicate()


func inventory_slot_quantity(index: int) -> int:
	return _bag_quantities[index] if index >= 0 and index < _bag_quantities.size() else 0


static func _stack_capacity(bag: Array[String], quantities: Array[int], item: ItemDefinition) -> int:
	var capacity: int = 0
	var limit: int = item.stack_limit()
	for index in range(bag.size()):
		if bag[index].is_empty():
			capacity += limit
		elif bag[index] == item.item_id and item.stackable:
			capacity += maxi(0, limit - quantities[index])
	return capacity


static func _fill_stack_slots(bag: Array[String], quantities: Array[int], item: ItemDefinition, amount: int) -> int:
	var remaining: int = amount
	var limit: int = item.stack_limit()
	for index in range(bag.size()):
		if bag[index] != item.item_id:
			continue
		var added: int = mini(remaining, maxi(0, limit - quantities[index]))
		quantities[index] += added
		remaining -= added
		if remaining == 0:
			return amount
	for index in range(bag.size()):
		if not bag[index].is_empty():
			continue
		var added: int = mini(remaining, limit)
		bag[index] = item.item_id
		quantities[index] = added
		remaining -= added
		if remaining == 0:
			break
	return amount - remaining


func _update_carried_count(item_id: String, delta: int) -> void:
	carried_items[item_id] = int(carried_items.get(item_id, 0)) + delta
	keys = int(carried_items.get("key", 0))
	potions = int(carried_items.get("potion", 0))


func item_instance(instance_id: String) -> ItemInstance:
	return _item_instances.get(instance_id) as ItemInstance


func inventory_instance_id(index: int) -> String:
	return _bag_instance_ids[index] if index >= 0 and index < _bag_instance_ids.size() else ""


func equipment_instance_id(slot_id: String, member: HeroState = null) -> String:
	var selected: HeroState = member if member != null else _inventory_equipment_member()
	return str(selected.equipped_instance_ids.get(slot_id, "")) if selected != null else ""


func _allocate_item_instance(item: ItemDefinition, durability: int = -1) -> ItemInstance:
	_next_item_instance_number += 1
	return ItemInstance.create("item_%d" % _next_item_instance_number, item, durability)


func _create_item_instance(item_id: String, durability: int = -1) -> ItemInstance:
	var result: ItemInstance = _allocate_item_instance(ItemCatalog.get_item(item_id), durability)
	if result != null:
		_item_instances[result.instance_id] = result
	return result


func _register_member_instances(member: HeroState) -> void:
	member.item_instances = _item_instances
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		var item_id: String = _member_equipment_id(member, slot_id)
		var definition: ItemDefinition = ItemCatalog.get_item(item_id)
		if definition == null or definition.category != ItemDefinition.Category.EQUIPMENT or definition.stackable:
			continue
		var durability: int = member.current_shield_durability(item_id) if _is_shield(item_id) else -1
		var instance: ItemInstance = _create_item_instance(item_id, durability)
		member.equipped_instance_ids[slot_id] = instance.instance_id


func _restore_legacy_item_instances() -> void:
	_bag_instance_ids.resize(INVENTORY_SLOT_COUNT)
	_bag_instance_ids.fill("")
	for member in party:
		member.equipped_instance_ids.clear()
		_register_member_instances(member)
	var shield_layout: Dictionary = _shield_layout(_inventory_order, _equipment_snapshot(hero), hero) if hero != null else {}
	for index in range(_inventory_order.size()):
		var item_id: String = _inventory_order[index]
		var definition: ItemDefinition = ItemCatalog.get_item(item_id)
		if definition == null or definition.category != ItemDefinition.Category.EQUIPMENT or definition.stackable:
			continue
		var instance: ItemInstance = _create_item_instance(item_id, int(shield_layout.get("bag:%d" % index, -1)))
		_bag_instance_ids[index] = instance.instance_id


func _instance_at(kind: String, slot: Variant, member: HeroState) -> String:
	if kind == "bag":
		return _bag_instance_ids[int(slot)]
	return str(member.equipped_instance_ids.get(str(slot), ""))


func _set_instance_at(kind: String, slot: Variant, member: HeroState, instance_id: String) -> void:
	if kind == "bag":
		_bag_instance_ids[int(slot)] = instance_id
	elif instance_id.is_empty():
		member.equipped_instance_ids.erase(str(slot))
	else:
		member.equipped_instance_ids[str(slot)] = instance_id


func _update_instance_shield_values(layout: Dictionary, member: HeroState) -> void:
	for index in range(_bag_instance_ids.size()):
		var bag_shield_instance: ItemInstance = item_instance(_bag_instance_ids[index])
		if bag_shield_instance != null and _is_shield(bag_shield_instance.item_id) and layout.has("bag:%d" % index):
			bag_shield_instance.durability = int(layout["bag:%d" % index])
	if member != null:
		for slot_id in member.equipped_instance_ids:
			var equipped_shield_instance: ItemInstance = item_instance(str(member.equipped_instance_ids[slot_id]))
			if equipped_shield_instance != null and _is_shield(equipped_shield_instance.item_id) and layout.has("equipment:%s" % slot_id):
				equipped_shield_instance.durability = int(layout["equipment:%s" % slot_id])


func swap_inventory_slots(source: int, destination: int) -> bool:
	return transfer_inventory_item("bag", source, "bag", destination)


func _equipment_snapshot(member: HeroState = null) -> Dictionary:
	var selected: HeroState = member if member != null else _inventory_equipment_member()
	var current: Dictionary = {}
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		current[slot_id] = _member_equipment_id(selected, slot_id)
	return current


func _can_equip_layout(equipped: Dictionary) -> bool:
	var weapon_id: String = str(equipped.get("main_hand", ""))
	var weapon: ItemDefinition = ItemCatalog.get_item(weapon_id)
	if weapon != null and weapon.two_handed and not str(equipped.get("off_hand", "")).is_empty():
		return false
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		var item_id: String = str(equipped.get(slot_id, ""))
		if item_id.is_empty():
			continue
		var definition: ItemDefinition = ItemCatalog.get_item(item_id)
		if definition == null or definition.stackable or not EquipmentSlotRules.accepts(slot_id, definition):
			return false
	return true


func _is_shield(item_id: String) -> bool:
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	return item != null and item.equipment_slot == ItemDefinition.EquipmentSlot.SHIELD


func _shield_layout(bag: Array[String], equipped: Dictionary, member: HeroState = null) -> Dictionary:
	var selected: HeroState = member if member != null else _inventory_equipment_member()
	if selected != hero:
		var shared: Dictionary = _shield_layout(bag, _equipment_snapshot(hero), hero)
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			var item_id: String = str(equipped.get(slot_id, ""))
			if _is_shield(item_id):
				shared["equipment:%s" % slot_id] = selected.current_shield_durability(item_id)
		return shared
	var values_at: Dictionary = {}
	var cursors: Dictionary = {}
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		var item_id: String = str(equipped.get(slot_id, ""))
		if _is_shield(item_id):
			var values: Array = selected.shield_durabilities.get(item_id, [])
			var cursor: int = int(cursors.get(item_id, 0))
			values_at["equipment:%s" % slot_id] = int(values[cursor]) if cursor < values.size() else _new_shield_durability(item_id)
			cursors[item_id] = cursor + 1
	for index in range(bag.size()):
		var item_id: String = bag[index]
		if _is_shield(item_id):
			var values: Array = selected.shield_durabilities.get(item_id, [])
			var cursor: int = int(cursors.get(item_id, 0))
			values_at["bag:%d" % index] = int(values[cursor]) if cursor < values.size() else _new_shield_durability(item_id)
			cursors[item_id] = cursor + 1
	return values_at

func _new_shield_durability(item_id: String) -> int:
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	return maxi(item.max_durability, item.defense_bonus) if item != null else 0


func _apply_shield_layout(bag: Array[String], equipped: Dictionary, values_at: Dictionary, member: HeroState = null) -> void:
	var selected: HeroState = member if member != null else _inventory_equipment_member()
	if selected != hero:
		var primary_equipment: Dictionary = _equipment_snapshot(hero)
		var primary_values: Dictionary = _shield_layout(bag, primary_equipment, hero)
		for index in range(bag.size()):
			if _is_shield(bag[index]):
				primary_values["bag:%d" % index] = values_at.get("bag:%d" % index, _new_shield_durability(bag[index]))
		_apply_shield_layout(bag, primary_equipment, primary_values, hero)
		var selected_values: Dictionary = selected.shield_durabilities.duplicate(true)
		for item_id in selected_values.keys():
			if _is_shield(str(item_id)):
				selected_values.erase(item_id)
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			var item_id: String = str(equipped.get(slot_id, ""))
			if _is_shield(item_id):
				var values: Array = selected_values.get(item_id, [])
				values.append(int(values_at.get("equipment:%s" % slot_id, _new_shield_durability(item_id))))
				selected_values[item_id] = values
		selected.shield_durabilities = selected_values
		return
	var updated: Dictionary = selected.shield_durabilities.duplicate(true)
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
	selected.shield_durabilities = updated

func inventory_shield_durability(index: int) -> int:
	var instance: ItemInstance = item_instance(inventory_instance_id(index))
	return instance.durability if instance != null and _is_shield(instance.item_id) else 0


func can_transfer_inventory_item(from_kind: String, from_slot: Variant, to_kind: String, to_slot: Variant) -> bool:
	return _planned_inventory_transfer(from_kind, from_slot, to_kind, to_slot).size() > 0


func transfer_inventory_item(from_kind: String, from_slot: Variant, to_kind: String, to_slot: Variant) -> bool:
	var plan: Dictionary = _planned_inventory_transfer(from_kind, from_slot, to_kind, to_slot)
	if plan.is_empty():
		return false
	if bool(plan.get("merge", false)):
		_inventory_order = plan["bag"]
		_bag_quantities = plan["quantities"]
		return true
	var member: HeroState = _inventory_equipment_member()
	var source_instance: String = _instance_at(from_kind, from_slot, member)
	var target_instance: String = _instance_at(to_kind, to_slot, member)
	_set_instance_at(from_kind, from_slot, member, target_instance)
	_set_instance_at(to_kind, to_slot, member, source_instance)
	if str(plan["equipment"]["off_hand"]).is_empty() and not str(_equipment_snapshot(member)["off_hand"]).is_empty():
		var misplaced: String = str(member.equipped_instance_ids.get("off_hand", ""))
		if not misplaced.is_empty():
			for index in range(INVENTORY_SLOT_COUNT):
				if _bag_instance_ids[index].is_empty() and str(plan["bag"][index]) == item_instance(misplaced).item_id:
					_bag_instance_ids[index] = misplaced
					member.equipped_instance_ids.erase("off_hand")
					break
	_inventory_order = plan["bag"]
	_bag_quantities = plan["quantities"]
	var equipped: Dictionary = plan["equipment"]
	member.equipped_weapon_id = str(equipped["main_hand"])
	member.equipped_shield_id = str(equipped["off_hand"])
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		if slot_id != "main_hand" and slot_id != "off_hand":
			var item_id: String = str(equipped[slot_id])
			if item_id.is_empty():
				member.equipped_accessories.erase(slot_id)
			else:
				member.equipped_accessories[slot_id] = item_id
	_apply_shield_layout(_inventory_order, equipped, plan["shield_layout"])
	_update_instance_shield_values(plan["shield_layout"], member)
	member._recalculate_equipment_stats()
	member.health = mini(member.health, member.effective_max_health())
	return true


func _planned_inventory_transfer(from_kind: String, from_slot: Variant, to_kind: String, to_slot: Variant) -> Dictionary:
	if hero == null or not (from_kind in ["bag", "equipment"]) or not (to_kind in ["bag", "equipment"]):
		return {}
	if (from_kind == "bag" and typeof(from_slot) != TYPE_INT) or (to_kind == "bag" and typeof(to_slot) != TYPE_INT):
		return {}
	var bag: Array[String] = inventory_slot_ids()
	var quantities: Array[int] = _bag_quantities.duplicate()
	var equipped: Dictionary = _equipment_snapshot()
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
	if from_kind == "bag" and to_kind == "bag" and source == target:
		var definition: ItemDefinition = ItemCatalog.get_item(source)
		if definition != null and definition.stackable:
			var moved: int = mini(quantities[source_index], definition.stack_limit() - quantities[target_index])
			if moved <= 0:
				return {}
			quantities[source_index] -= moved
			quantities[target_index] += moved
			if quantities[source_index] == 0:
				bag[source_index] = ""
			return {"bag": bag, "quantities": quantities, "merge": true}
	if to_kind == "equipment" and not EquipmentSlotRules.accepts(target_slot, ItemCatalog.get_item(source)):
		return {}
	if from_kind == "equipment" and not target.is_empty() and not EquipmentSlotRules.accepts(source_slot, ItemCatalog.get_item(target)):
		return {}
	var shield_layout: Dictionary = _shield_layout(bag, equipped)
	var source_quantity: int = quantities[source_index] if from_kind == "bag" else 1
	var target_quantity: int = quantities[target_index] if to_kind == "bag" else (0 if target.is_empty() else 1)
	var source_location: String = "bag:%d" % source_index if from_kind == "bag" else "equipment:%s" % source_slot
	var target_location: String = "bag:%d" % target_index if to_kind == "bag" else "equipment:%s" % target_slot
	var source_durability: Variant = shield_layout.get(source_location)
	var target_durability: Variant = shield_layout.get(target_location)
	shield_layout.erase(source_location)
	shield_layout.erase(target_location)
	if from_kind == "bag":
		bag[source_index] = target
		quantities[source_index] = target_quantity
	else:
		equipped[source_slot] = target
	if to_kind == "bag":
		bag[target_index] = source
		quantities[target_index] = source_quantity
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
		quantities[free_index] = 1
		equipped["off_hand"] = ""
		if shield_layout.has("equipment:off_hand"):
			shield_layout["bag:%d" % free_index] = shield_layout["equipment:off_hand"]
			shield_layout.erase("equipment:off_hand")
	if not _can_equip_layout(equipped):
		return {}
	return {"bag": bag, "quantities": quantities, "equipment": equipped, "shield_layout": shield_layout}


func party_members() -> Array[HeroState]:
	var members: Array[HeroState] = []
	members.append_array(party)
	return members


func _member_equipment_id(member: HeroState, slot_id: String) -> String:
	if member == null:
		return ""
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
	member.equipped_instance_ids.clear()
	member._recalculate_equipment_stats()


func _append_ground_loot(cell: Vector2i, entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		return
	var container: Dictionary = _ground_container_at(cell)
	if not container.is_empty():
		var contents: Array = container["loot"]
		contents.append_array(entries.duplicate(true))
		return
	_ground_loot_counter += 1
	_add_ground_container({
		"id": "ground_%d" % _ground_loot_counter,
		"x": cell.x, "y": cell.y,
		"loot": entries.duplicate(true)
	})


func _add_ground_container(container: Dictionary) -> void:
	_ground_loot_containers.append(container)
	var cell := Vector2i(int(container["x"]), int(container["y"]))
	if not _ground_by_cell.has(cell):
		_ground_by_cell[cell] = []
	_ground_by_cell[cell].append(container)
	_ground_by_id[str(container["id"])] = container


func _remove_ground_container(container: Dictionary) -> void:
	_ground_loot_containers.erase(container)
	_ground_by_id.erase(str(container["id"]))
	var cell := Vector2i(int(container["x"]), int(container["y"]))
	var entries: Array = _ground_by_cell[cell]
	entries.erase(container)
	if entries.is_empty():
		_ground_by_cell.erase(cell)


func _ground_container_at(cell: Vector2i) -> Dictionary:
	var entries: Array = _ground_by_cell.get(cell, [])
	return entries.front() if not entries.is_empty() else {}


func ground_container_at(cell: Vector2i) -> Dictionary:
	return _ground_container_at(cell).duplicate(true)


func ground_container_by_id(container_id: String) -> Dictionary:
	var container: Dictionary = _ground_by_id.get(container_id, {})
	return container.duplicate(true)


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
		if member == null:
			continue
		if member.equipped_shield_id.is_empty() and member.equipped_instance_ids.has("off_hand"):
			resolve_broken_shield(member)
		if member.health <= 0:
			casualties.append(member)
	if casualties.is_empty():
		return casualties
	var bag: Array[String] = inventory_slot_ids()
	var bag_instance_ids: Array[String] = _bag_instance_ids.duplicate()
	var bag_shields: Dictionary = _shield_layout(bag, _equipment_snapshot(hero), hero) if hero != null else {}
	_update_instance_shield_values(bag_shields, hero)
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
	var death_instances: Dictionary = {}
	for member in casualties:
		var equipped_at_death: Dictionary = {}
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			var item_id: String = _member_equipment_id(member, slot_id)
			if not item_id.is_empty():
				equipped_at_death[slot_id] = item_id
		var durability_at_death: Dictionary = member.shield_durabilities.duplicate(true)
		if survivor == null:
			for slot_id in equipped_at_death:
				var dead_item_id: String = str(equipped_at_death[slot_id])
				var dead_instance: ItemInstance = item_instance(str(member.equipped_instance_ids.get(slot_id, "")))
				if dead_instance != null:
					if _is_shield(dead_item_id):
						dead_instance.durability = member.current_shield_durability(dead_item_id)
					if not death_instances.has(dead_item_id):
						death_instances[dead_item_id] = []
					death_instances[dead_item_id].append(dead_instance.to_dict())
		var member_gold: int = member.gold
		death_gold += member_gold
		member.gold = 0
		if survivor != null:
			for slot_id in equipped_at_death:
				var item_id: String = str(equipped_at_death[slot_id])
				var instance_id: String = str(member.equipped_instance_ids.get(slot_id, ""))
				var durability: int = _shield_durability_for_drop(member, item_id) if _is_shield(item_id) else 0
				var instance: ItemInstance = item_instance(instance_id)
				if instance != null and _is_shield(item_id):
					instance.durability = durability
				var free: int = bag.find("")
				if free >= 0:
					bag[free] = item_id
					_bag_quantities[free] = 1
					bag_instance_ids[free] = instance_id
					if _is_shield(item_id):
						bag_shields["bag:%d" % free] = durability
				else:
					carried_items[item_id] = maxi(int(carried_items.get(item_id, 0)) - 1, 0)
					var entry: Dictionary = {"item_id": item_id, "quantity": 1}
					if _is_shield(item_id):
						entry["durabilities"] = [durability]
					if instance != null:
						entry["instances"] = [instance.to_dict()]
						_item_instances.erase(instance_id)
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
		var instance_groups: Dictionary = death_instances.duplicate(true)
		for bag_instance_id in bag_instance_ids:
			var bag_instance: ItemInstance = item_instance(bag_instance_id)
			if bag_instance != null:
				if not instance_groups.has(bag_instance.item_id):
					instance_groups[bag_instance.item_id] = []
				instance_groups[bag_instance.item_id].append(bag_instance.to_dict())
		for key in carried_items:
			var item_id: String = str(key)
			var amount: int = int(carried_items[key])
			if amount <= 0:
				continue
			var entry: Dictionary = {"item_id": item_id, "quantity": amount}
			if instance_groups.has(item_id):
				entry["instances"] = instance_groups[item_id]
				if _is_shield(item_id):
					var remaining_durabilities: Array = []
					for record in instance_groups[item_id]:
						remaining_durabilities.append(int(record["durability"]))
					entry["durabilities"] = remaining_durabilities
			ground.append(entry)
		carried_items.clear()
		bag.fill("")
		_bag_quantities.fill(0)
		bag_instance_ids.fill("")
		_item_instances.clear()
		for member in casualties:
			member.shield_durabilities.clear()
	else:
		hero = survivor
		_apply_shield_layout(bag, _equipment_snapshot(survivor), bag_shields, survivor)
		for member in casualties:
			member.shield_durabilities.clear()
	if death_gold > 0:
		ground.append({"item_id": "gold", "quantity": death_gold})
	_inventory_order = bag
	_bag_instance_ids = bag_instance_ids
	if survivor != null:
		_update_instance_shield_values(bag_shields, survivor)
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
	if item.stackable:
		return mini(quantity, _stack_capacity(_inventory_order, _bag_quantities, item))
	return 1 if _inventory_order.has("") else 0


func can_take_ground_loot(container_id: String, entry_index: int) -> bool:
	var container: Dictionary = _ground_by_id.get(container_id, {})
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
	var container: Dictionary = _ground_by_id.get(container_id, {})
	var loot: Array = container["loot"]
	var entry: Dictionary = loot[entry_index]
	var item_id: String = str(entry["item_id"])
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	var amount: int = _ground_loot_take_count(entry)
	if item.category == ItemDefinition.Category.CURRENCY:
		hero.gold += amount
	elif item.stackable:
		amount = _fill_stack_slots(_inventory_order, _bag_quantities, item, amount)
		_update_carried_count(item_id, amount)
	else:
		var bag: Array[String] = inventory_slot_ids()
		var equipped: Dictionary = _equipment_snapshot(hero)
		var shield_layout: Dictionary = _shield_layout(bag, equipped, hero) if _is_shield(item_id) else {}
		var free: int = bag.find("")
		if free < 0:
			return 0
		var restored: ItemInstance = null
		if item.category == ItemDefinition.Category.EQUIPMENT and not item.stackable:
			if entry.has("instances"):
				var saved_instances: Array = entry["instances"]
				if saved_instances.is_empty():
					return 0
				restored = ItemInstance.from_dict(saved_instances.front())
				if restored == null or restored.item_id != item_id or _item_instances.has(restored.instance_id):
					return 0
				saved_instances.pop_front()
				_item_instances[restored.instance_id] = restored
			else:
				restored = _create_item_instance(item_id)
			_bag_instance_ids[free] = restored.instance_id
		bag[free] = item_id
		_bag_quantities[free] = 1
		if _is_shield(item_id):
			var durabilities: Array = entry.get("durabilities", [])
			var shield_instance: ItemInstance = item_instance(_bag_instance_ids[free])
			var durability: int = shield_instance.durability if shield_instance != null else _new_shield_durability(item_id)
			shield_layout["bag:%d" % free] = int(durabilities.pop_front()) if not durabilities.is_empty() else durability
			if entry.has("durabilities"):
				entry["durabilities"] = durabilities
		_inventory_order = bag
		carried_items[item_id] = int(carried_items.get(item_id, 0)) + amount
		if _is_shield(item_id):
			_apply_shield_layout(bag, equipped, shield_layout, hero)
			_update_instance_shield_values(shield_layout, hero)
		keys = int(carried_items.get("key", 0))
		potions = int(carried_items.get("potion", 0))
	entry["quantity"] = int(entry["quantity"]) - amount
	if int(entry["quantity"]) <= 0:
		loot.remove_at(entry_index)
	if loot.is_empty():
		_remove_ground_container(container)
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
	_register_member_instances(member)
	if not member.equipped_weapon_id.is_empty():
		carried_items[member.equipped_weapon_id] = int(carried_items.get(member.equipped_weapon_id, 0)) + 1
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


func _living_party_members() -> Array[HeroState]:
	var living: Array[HeroState] = []
	for member in party:
		if member != null and member.health > 0:
			living.append(member)
	return living


func _door_opener(requested: HeroState = null) -> HeroState:
	var living: Array[HeroState] = _living_party_members()
	if requested != null and living.has(requested):
		return requested
	return living[0] if not living.is_empty() else null


func _capture_floor_state() -> Dictionary:
	if map_data == null:
		return {}
	var visited_cells: Array = revealed
	if debug_open_map and _revealed_before_debug_open_map.size() == map_data.height:
		visited_cells = _revealed_before_debug_open_map
	return {
		"map_id": map_data.map_id,
		"position": player_pos,
		"ground_loot": _ground_loot_containers.duplicate(true),
		"exit_rewards": claimed_exit_rewards.duplicate(true),
		"removed": removed_entities.duplicate(true),
		"chests": opened_chests.duplicate(true),
		"traps": disarmed_traps.duplicate(true),
		"revealed_traps": revealed_traps.duplicate(true),
		"discharged_traps": discharged_traps.duplicate(true),
		"failed_trap_disarms": failed_trap_disarms.duplicate(true),
		"triggers": activated_triggers.duplicate(true),
		"messages": shown_messages.duplicate(true),
		"revealed": visited_cells.duplicate(true)
	}


func floor_state_snapshot(map_id: String = "") -> Dictionary:
	var selected_id: String = map_id
	if selected_id.is_empty() and map_data != null:
		selected_id = map_data.map_id
	if map_data != null and selected_id == map_data.map_id:
		return _capture_floor_state()
	var saved: Dictionary = _floor_states.get(selected_id, {})
	if saved.is_empty():
		return {}
	var snapshot: Dictionary = saved.duplicate(true)
	snapshot.erase("map")
	return snapshot


func visited_floor_snapshots() -> Dictionary:
	var snapshots: Dictionary = {}
	for map_id in _floor_states:
		snapshots[str(map_id)] = floor_state_snapshot(str(map_id))
	if map_data != null:
		snapshots[map_data.map_id] = _capture_floor_state()
	return snapshots


func party_state_snapshot() -> Dictionary:
	var instances: Array[Dictionary] = []
	for instance_id in _item_instances:
		instances.append((_item_instances[instance_id] as ItemInstance).to_dict())
	var active: Array[Dictionary] = []
	for member in party:
		active.append(member.to_snapshot())
	var fallen: Array[Dictionary] = []
	for member in fallen_heroes:
		fallen.append(member.to_snapshot())
	var locations: Array[Dictionary] = []
	for location in fallen_hero_locations:
		var index: int = fallen_heroes.find(location.get("hero"))
		if index < 0:
			return {}
		var cell: Vector2i = location.get("position", Vector2i(-1, -1))
		locations.append({
			"fallen_index": index,
			"map_id": str(location.get("map_id", "")),
			"x": cell.x,
			"y": cell.y,
			"equipment_at_death": location.get("equipment_at_death", {}).duplicate(true),
			"shield_durabilities_at_death": location.get("shield_durabilities_at_death", {}).duplicate(true),
			"gold_at_death": int(location.get("gold_at_death", 0))
		})
	return {
		"active_heroes": active,
		"fallen_heroes": fallen,
		"fallen_locations": locations,
		"hero_index": party.find(hero),
		"inventory_member_index": party.find(inventory_member),
		"carried_items": carried_items.duplicate(true),
		"inventory_slots": inventory_slot_ids(),
		"bag_quantities": _bag_quantities.duplicate(),
		"item_instances": instances,
		"bag_instance_ids": _bag_instance_ids.duplicate(),
		"next_item_instance_number": _next_item_instance_number,
		"steps": steps,
		"loot_victories": loot_victories,
		"random_seed": str(trap_random.seed),
		"random_state": str(trap_random.state)
	}


func restore_party_state(snapshot: Dictionary) -> bool:
	if not (snapshot.get("active_heroes") is Array) or not (snapshot.get("fallen_heroes") is Array):
		return false
	if not (snapshot.get("fallen_locations") is Array) or not (snapshot.get("carried_items") is Dictionary):
		return false
	if not (snapshot.get("inventory_slots") is Array):
		return false
	var active_data: Array = snapshot["active_heroes"]
	var fallen_data: Array = snapshot["fallen_heroes"]
	if active_data.size() > MAX_PARTY_SIZE or (active_data.is_empty() and fallen_data.is_empty()):
		return false
	var restored_party: Array[HeroState] = []
	for active_snapshot in active_data:
		if not (active_snapshot is Dictionary):
			return false
		var active_member: HeroState = HeroState.from_snapshot(active_snapshot)
		if active_member == null or active_member.health <= 0:
			return false
		restored_party.append(active_member)
	var restored_fallen: Array[HeroState] = []
	for fallen_snapshot in fallen_data:
		if not (fallen_snapshot is Dictionary):
			return false
		var fallen_member: HeroState = HeroState.from_snapshot(fallen_snapshot)
		if fallen_member == null or fallen_member.health != 0:
			return false
		restored_fallen.append(fallen_member)
	var hero_index: int = int(snapshot.get("hero_index", -2))
	var inventory_index: int = int(snapshot.get("inventory_member_index", -2))
	if restored_party.is_empty():
		if hero_index != -1:
			return false
	elif hero_index < 0 or hero_index >= restored_party.size():
		return false
	if inventory_index < -1 or inventory_index >= restored_party.size():
		return false
	var locations_data: Array = snapshot["fallen_locations"]
	if locations_data.size() != restored_fallen.size():
		return false
	var restored_locations: Array[Dictionary] = []
	var seen_fallen: Dictionary = {}
	for location in locations_data:
		if not (location is Dictionary):
			return false
		var index: int = int(location.get("fallen_index", -1))
		if index < 0 or index >= restored_fallen.size() or seen_fallen.has(index):
			return false
		if str(location.get("map_id", "")).is_empty():
			return false
		if not (location.get("equipment_at_death") is Dictionary) or not (location.get("shield_durabilities_at_death") is Dictionary):
			return false
		seen_fallen[index] = true
		restored_locations.append({
			"hero": restored_fallen[index],
			"map_id": str(location["map_id"]),
			"position": Vector2i(int(location.get("x", -1)), int(location.get("y", -1))),
			"equipment_at_death": location["equipment_at_death"].duplicate(true),
			"shield_durabilities_at_death": location["shield_durabilities_at_death"].duplicate(true),
			"gold_at_death": int(location.get("gold_at_death", 0))
		})
	var new_carried: Dictionary = snapshot["carried_items"]
	var new_slots: Array = snapshot["inventory_slots"]
	var saved_quantities: Variant = snapshot.get("bag_quantities", [])
	if snapshot.has("bag_quantities") and (not (saved_quantities is Array) or saved_quantities.size() != INVENTORY_SLOT_COUNT):
		return false
	if new_slots.size() != INVENTORY_SLOT_COUNT or not _valid_snapshot_inventory(new_carried, new_slots, restored_party, saved_quantities):
		return false
	if not (snapshot.get("steps") is int) and not (snapshot.get("steps") is float):
		return false
	var restored_steps: int = int(snapshot["steps"])
	if restored_steps < 0 or float(snapshot["steps"]) != float(restored_steps):
		return false
	var restored_victories: Variant = snapshot.get("loot_victories", 0)
	if not ProgressSnapshotCodec._is_integer(restored_victories) or int(restored_victories) < 0:
		return false
	var seed_text: String = str(snapshot.get("random_seed", ""))
	var state_text: String = str(snapshot.get("random_state", ""))
	if not seed_text.is_valid_int() or not state_text.is_valid_int():
		return false
	var restored_slots: Array[String] = []
	for item_id in new_slots:
		restored_slots.append(str(item_id))
	var restored_instances: Dictionary = {}
	var restored_bag_instances: Array[String] = []
	var restored_serial: int = 0
	if snapshot.has("item_instances") or snapshot.has("bag_instance_ids") or snapshot.has("next_item_instance_number"):
		if not (snapshot.get("item_instances") is Array) or not (snapshot.get("bag_instance_ids") is Array):
			return false
		if not ProgressSnapshotCodec._is_integer(snapshot.get("next_item_instance_number")) or int(snapshot["next_item_instance_number"]) < 0:
			return false
		restored_serial = int(snapshot["next_item_instance_number"])
		for raw_instance in snapshot["item_instances"]:
			var instance: ItemInstance = ItemInstance.from_dict(raw_instance)
			if instance == null or restored_instances.has(instance.instance_id):
				return false
			var number_text: String = instance.instance_id.trim_prefix("item_")
			if not instance.instance_id.begins_with("item_") or not number_text.is_valid_int() or int(number_text) < 1 or int(number_text) > restored_serial:
				return false
			restored_instances[instance.instance_id] = instance
		if snapshot["bag_instance_ids"].size() != INVENTORY_SLOT_COUNT:
			return false
		var assigned: Dictionary = {}
		for i in range(INVENTORY_SLOT_COUNT):
			var bag_binding_id: Variant = snapshot["bag_instance_ids"][i]
			if typeof(bag_binding_id) != TYPE_STRING:
				return false
			restored_bag_instances.append(bag_binding_id)
			var bag_item_type_id: String = str(new_slots[i])
			var definition: ItemDefinition = ItemCatalog.get_item(bag_item_type_id)
			var must_have: bool = definition != null and definition.category == ItemDefinition.Category.EQUIPMENT and not definition.stackable
			if must_have != (not bag_binding_id.is_empty()):
				return false
			if must_have:
				if not restored_instances.has(bag_binding_id) or (restored_instances[bag_binding_id] as ItemInstance).item_id != bag_item_type_id or assigned.has(bag_binding_id):
					return false
				assigned[bag_binding_id] = true
		for member in restored_party:
			for slot_id in EquipmentSlotRules.SLOT_IDS:
				var item_id: String = _member_equipment_id(member, slot_id)
				var instance_id: String = str(member.equipped_instance_ids.get(slot_id, ""))
				if item_id.is_empty() != instance_id.is_empty():
					return false
				if not instance_id.is_empty():
					if not restored_instances.has(instance_id) or (restored_instances[instance_id] as ItemInstance).item_id != item_id or assigned.has(instance_id):
						return false
					assigned[instance_id] = true
		if assigned.size() != restored_instances.size():
			return false
	for member in restored_party:
		member.item_instances = restored_instances
		if member.health > member.effective_max_health():
			return false
		if member.max_health != member.definition.max_health:
			var previous_limit: int = member.effective_max_health()
			member.max_health = member.definition.max_health
			var current_limit: int = member.effective_max_health()
			member.health = clampi(roundi(float(member.health) * current_limit / previous_limit), 1, current_limit)
		member._recalculate_equipment_stats()
	for member in restored_fallen:
		member.max_health = member.definition.max_health
	var restored_quantities: Array[int] = []
	var legacy_overflow: Array[Dictionary] = []
	if snapshot.has("bag_quantities"):
		for quantity in saved_quantities:
			restored_quantities.append(int(quantity))
	else:
		restored_quantities.resize(INVENTORY_SLOT_COUNT)
		restored_quantities.fill(0)
		var remainder: Dictionary = {}
		for index in range(restored_slots.size()):
			var item_id: String = restored_slots[index]
			if item_id.is_empty():
				continue
			var item: ItemDefinition = ItemCatalog.get_item(item_id)
			var quantity: int = int(new_carried[item_id]) if item.stackable else 1
			restored_quantities[index] = mini(quantity, item.stack_limit())
			if quantity > restored_quantities[index]:
				remainder[item_id] = quantity - restored_quantities[index]
		new_carried = new_carried.duplicate(true)
		for item_id in remainder:
			var quantity: int = int(remainder[item_id])
			var added: int = _fill_stack_slots(restored_slots, restored_quantities, ItemCatalog.get_item(item_id), quantity)
			if added < quantity:
				var overflow: int = quantity - added
				if map_data == null or not map_data.contains(player_pos.x, player_pos.y) or map_data.get_terrain(player_pos.x, player_pos.y) != "floor":
					return false
				legacy_overflow.append({"item_id": item_id, "quantity": overflow})
				new_carried[item_id] = int(new_carried[item_id]) - overflow
	party = restored_party
	fallen_heroes = restored_fallen
	fallen_hero_locations = restored_locations
	hero = restored_party[hero_index] if hero_index >= 0 else null
	inventory_member = restored_party[inventory_index] if inventory_index >= 0 else null
	carried_items = new_carried.duplicate(true)
	_inventory_order = restored_slots
	_bag_quantities = restored_quantities
	_item_instances = restored_instances
	_bag_instance_ids = restored_bag_instances
	_next_item_instance_number = restored_serial
	if not snapshot.has("item_instances"):
		_restore_legacy_item_instances()
	elif hero != null:
		_update_instance_shield_values(_shield_layout(_inventory_order, _equipment_snapshot(hero), hero), hero)
		for member in party:
			member.sync_equipped_shield_instance()
	steps = restored_steps
	loot_victories = int(restored_victories)
	keys = int(carried_items.get("key", 0))
	potions = int(carried_items.get("potion", 0))
	trap_random.seed = seed_text.to_int()
	trap_random.state = state_text.to_int()
	_casualty_events.clear()
	_party_damage_events.clear()
	_append_ground_loot(player_pos, legacy_overflow)
	return true


func _valid_snapshot_inventory(counts: Dictionary, bag: Array, members: Array[HeroState], quantities: Array = []) -> bool:
	var seen: Dictionary = {}
	for count_item_id in counts:
		if typeof(count_item_id) != TYPE_STRING or ItemCatalog.get_item(str(count_item_id)) == null:
			return false
		if typeof(counts[count_item_id]) not in [TYPE_INT, TYPE_FLOAT] or int(counts[count_item_id]) < 0 or float(counts[count_item_id]) != float(int(counts[count_item_id])):
			return false
	for index in range(bag.size()):
		var bag_entry: Variant = bag[index]
		if not quantities.is_empty() and not ProgressSnapshotCodec._is_integer(quantities[index]):
			return false
		if typeof(bag_entry) != TYPE_STRING:
			return false
		var bag_item_id: String = str(bag_entry)
		if bag_item_id.is_empty():
			if not quantities.is_empty() and int(quantities[index]) != 0:
				return false
			continue
		var item: ItemDefinition = ItemCatalog.get_item(bag_item_id)
		if item == null or int(counts.get(bag_item_id, 0)) <= 0:
			return false
		var amount: int = 1
		if quantities.is_empty():
			if item.stackable and seen.has(bag_item_id):
				return false
			amount = int(counts[bag_item_id]) if item.stackable else 1
		else:
			amount = int(quantities[index])
			if amount <= 0 or amount > item.stack_limit():
				return false
		seen[bag_item_id] = int(seen.get(bag_item_id, 0)) + amount
	for member in members:
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			var equipped_item_id: String = _member_equipment_id(member, slot_id)
			if equipped_item_id.is_empty():
				continue
			if not EquipmentSlotRules.accepts(slot_id, ItemCatalog.get_item(equipped_item_id)):
				return false
			seen[equipped_item_id] = int(seen.get(equipped_item_id, 0)) + 1
	for seen_item_id in seen:
		if not counts.has(seen_item_id):
			return false
	for total_item_id in counts:
		if int(seen.get(total_item_id, 0)) != int(counts[total_item_id]):
			return false
	return true


func enter_map(next_map: DungeonMap) -> bool:
	if has_pending_trap_choice() or has_pending_door_trap() or is_party_defeated() or next_map == null or next_map.map_id.is_empty() or not is_map_in_campaign(next_map.map_id):
		return false
	var source_exit: Dictionary = current_exit()
	var source_id: String = map_data.map_id if map_data != null else ""
	var source_kind: String = str(source_exit.get("type", ""))
	var saved: Dictionary = _floor_states.get(next_map.map_id, {})
	var destination: DungeonMap = saved.get("map", next_map)
	if map_data != null and map_data.map_id == next_map.map_id:
		saved = _capture_floor_state()
		destination = map_data
	elif is_editor_test and saved.is_empty():
		destination = DungeonMap.from_dict(next_map.to_dict().duplicate(true))
		if destination == null:
			return false
	var arrival: Vector2i = destination.find_entity_position("player_spawn")
	if source_kind == "stairs_up":
		arrival = _return_arrival_cell(destination)
		if arrival.x < 0:
			return false
	elif not DungeonMap.valid_arrival_cell(destination, arrival):
		return false
	if is_completed and source_kind in ["stairs_down", "stairs_up", "portal"] and DungeonMap.exit_target_id(source_exit) != next_map.map_id:
		return false
	if map_data != null:
		var current: Dictionary = _capture_floor_state()
		current["map"] = map_data
		_floor_states[map_data.map_id] = current
	if source_kind == "stairs_down" and DungeonMap.exit_target_id(source_exit) == next_map.map_id:
		_stairs_history.append({
			"from": source_id,
			"to": next_map.map_id,
			"from_cell": [player_pos.x, player_pos.y],
			"from_exit_id": str(source_exit.get("id", ""))
		})
	elif source_kind == "stairs_up" and not _stairs_history.is_empty():
		_stairs_history.pop_back()
	_pending_return_exit.clear()
	map_data = destination
	_ground_loot_containers.clear()
	_ground_by_cell.clear()
	_ground_by_id.clear()
	for container in saved.get("ground_loot", []):
		_add_ground_container(container.duplicate(true))
	claimed_exit_rewards = saved.get("exit_rewards", {}).duplicate(true)
	player_pos = arrival
	removed_entities = saved.get("removed", {}).duplicate(true)
	opened_chests = saved.get("chests", {}).duplicate(true)
	disarmed_traps = saved.get("traps", {}).duplicate(true)
	revealed_traps = saved.get("revealed_traps", {}).duplicate(true)
	discharged_traps = saved.get("discharged_traps", {}).duplicate(true)
	failed_trap_disarms = saved.get("failed_trap_disarms", {}).duplicate(true)
	last_move_detected_trap = false
	pending_chest_id = ""
	pending_door_trap_id = ""
	pending_door_trap_cell = Vector2i(-1, -1)
	_pending_door_opener = null
	_pending_door_accepted.clear()
	_clear_trap_choice()
	_trap_result_messages.clear()
	_trap_visual_events.clear()
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


func has_stairs_up() -> bool:
	return map_data != null and not _stairs_history.is_empty() and str(_stairs_history.back().get("to", "")) == map_data.map_id


static func _history_origin(record: Dictionary, fallback: Vector2i) -> Vector2i:
	if not record.has("from_cell"):
		return fallback
	var coords: Variant = record["from_cell"]
	if not (coords is Array) or coords.size() != 2:
		return Vector2i(-1, -1)
	if not ProgressSnapshotCodec._is_integer(coords[0]) or not ProgressSnapshotCodec._is_integer(coords[1]):
		return Vector2i(-1, -1)
	return Vector2i(int(coords[0]), int(coords[1]))


static func _matching_return_stair(map_ref: DungeonMap, cell: Vector2i, exit_id: String, target_id: String) -> bool:
	if map_ref == null or not map_ref.contains(cell.x, cell.y):
		return false
	for entity in map_ref.entities_at(cell.x, cell.y):
		if str(entity.get("type", "")) != "stairs_down":
			continue
		if not exit_id.is_empty() and str(entity.get("id", "")) != exit_id:
			continue
		if DungeonMap.exit_target_id(entity) == target_id:
			return true
	return false


static func _return_cell_is_open(map_ref: DungeonMap, cell: Vector2i, removed: Dictionary) -> bool:
	if map_ref == null or map_ref.get_terrain(cell.x, cell.y) != "floor":
		return false
	for entity in map_ref.entities_at(cell.x, cell.y):
		if str(entity.get("type", "")) in ["door", "monster"] and not removed.has(str(entity.get("id", ""))):
			return false
	return true


func _return_arrival_cell(destination: DungeonMap) -> Vector2i:
	var invalid := Vector2i(-1, -1)
	if not has_stairs_up() or destination == null or _stairs_history.is_empty():
		return invalid
	var record: Dictionary = _stairs_history.back()
	if str(record.get("from", "")) != destination.map_id:
		return invalid
	var previous: Dictionary = _floor_states.get(destination.map_id, {})
	var old_position: Vector2i = previous.get("position", invalid)
	var cell: Vector2i = _history_origin(record, old_position)
	if not _matching_return_stair(destination, cell, str(record.get("from_exit_id", "")), map_data.map_id):
		return invalid
	if not _return_cell_is_open(destination, cell, previous.get("removed", {})):
		return invalid
	return cell


func known_map(map_id: String) -> DungeonMap:
	if map_data != null and map_data.map_id == map_id:
		return map_data
	var state: Dictionary = _floor_states.get(map_id, {})
	return state.get("map") as DungeonMap


func current_exit() -> Dictionary:
	if not _pending_return_exit.is_empty():
		return _pending_return_exit.duplicate(true)
	if not is_completed:
		return {}
	var stairs: Dictionary = _find_active_entity(player_pos, "stairs_down")
	if not stairs.is_empty():
		return stairs
	return _find_active_entity(player_pos, "portal")


func next_map_id() -> String:
	return DungeonMap.exit_target_id(current_exit())


func next_arrival_cell(destination: DungeonMap) -> Vector2i:
	if str(current_exit().get("type", "")) == "stairs_up":
		return _return_arrival_cell(destination)
	return DungeonMap.exit_target_cell(current_exit(), destination)


func can_enter_next_map(destination: DungeonMap) -> bool:
	if destination == null or destination.map_id != next_map_id() or not is_map_in_campaign(destination.map_id):
		return false
	var arrival: Vector2i = next_arrival_cell(destination)
	if str(current_exit().get("type", "")) == "stairs_up":
		return arrival.x >= 0
	return DungeonMap.valid_arrival_cell(destination, arrival)


func cancel_exit_transition() -> void:
	is_completed = false
	_pending_return_exit.clear()


func _init_masks() -> void:
	_visible_bounds = Rect2i()
	_debug_visibility_applied = false
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


func trap_state(entity: Dictionary) -> String:
	var entity_id: String = str(entity.get("id", ""))
	if disarmed_traps.has(entity_id):
		return "discharged" if discharged_traps.has(entity_id) else "disarmed"
	return "armed"


func is_trap_disarmed(entity: Dictionary) -> bool:
	return trap_state(entity) != "armed"


func can_disarm_trap(entity: Dictionary) -> bool:
	return not is_trap_disarmed(entity) and not failed_trap_disarms.has(str(entity.get("id", "")))


func is_trap_known_by(entity: Dictionary, member: HeroState) -> bool:
	if map_data == null or member == null:
		return false
	var knowledge: Dictionary = member.known_traps_by_map.get(map_data.map_id, {})
	return knowledge.has(str(entity.get("id", "")))


func is_trap_revealed(entity: Dictionary) -> bool:
	if revealed_traps.has(str(entity.get("id", ""))) or is_trap_disarmed(entity):
		return true
	for member in party:
		if member.health > 0 and is_trap_known_by(entity, member):
			return true
	return false


func is_door_trap_visible(door: Dictionary) -> bool:
	var trap: TrapDefinition = TrapCatalog.from_door(door)
	return trap != null and (not bool(TrapCatalog.settings(door).get("hidden", true)) or is_trap_revealed(door) or (hero != null and hero.has_vision_effect()))


func _discover_trap(entity: Dictionary, trap: TrapDefinition, hidden: bool) -> bool:
	if trap == null or not hidden or is_trap_disarmed(entity):
		return false
	var already_revealed: bool = is_trap_revealed(entity)
	var discovered: bool = false
	var trap_id: String = str(entity.get("id", ""))
	if trap_id.is_empty():
		return false
	for member in party:
		if member.health <= 0 or is_trap_known_by(entity, member) or member.effective_perception() < trap.detection_difficulty:
			continue
		if not member.known_traps_by_map.has(map_data.map_id):
			member.known_traps_by_map[map_data.map_id] = {}
		member.known_traps_by_map[map_data.map_id][trap_id] = true
		discovered = true
	return discovered and not already_revealed


func _discover_floor_traps(cell: Vector2i) -> bool:
	var discovered: bool = false
	for entity in map_data.entities_at(cell.x, cell.y):
		if str(entity.get("type", "")) != "trap":
			continue
		var trap: TrapDefinition = TrapCatalog.from_entity(entity)
		if trap != null and trap.can_attach_to("floor"):
			if _discover_trap(entity, trap, DungeonMap.is_entity_hidden(entity)):
				discovered = true
	return discovered


func entities_at(x: int, y: int) -> Array:
	var result: Array = map_data.entities_at(x, y)
	var container: Dictionary = _ground_container_at(Vector2i(x, y))
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
func win_pending_encounter(battle: BattleState = null) -> bool:
	if not has_pending_encounter() or (battle != null and not battle.is_victory):
		return false
	record_casualties()
	if is_party_defeated():
		return false
	var target: Vector2i = encounter_target
	var defeated_id: String = encounter_monster_id
	var defeated: Dictionary = {}
	for entity in map_data.entities:
		if str(entity.get("id", "")) == defeated_id and str(entity.get("type", "")) == "monster":
			defeated = entity
			break
	encounter_monster_id = ""
	encounter_target = Vector2i(-1, -1)
	if defeated.is_empty() or is_entity_removed(defeated):
		return false
	removed_entities[defeated_id] = true
	loot_victories += 1
	var rewards: Array[Dictionary] = _resolve_source_rewards(defeated)
	for reward in rewards:
		_receive_reward(reward, target)
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


func _append_trap_result(message: String) -> void:
	_trap_result_messages.append(message)
	_append_event_message(message)


func take_trap_result_message() -> String:
	var result: String = "\n".join(_trap_result_messages)
	_trap_result_messages.clear()
	return result


func has_trap_visual_events() -> bool:
	return not _trap_visual_events.is_empty()


func take_trap_visual_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = _trap_visual_events.duplicate(true)
	_trap_visual_events.clear()
	return result


func _activate_trap(trap: TrapDefinition, trap_key: String, opener: HeroState = null, door_cell: Vector2i = Vector2i(-1, -1)) -> void:
	revealed_traps[trap_key] = true
	if trap.trigger_visual != "none" and trap.can_attach_to("floor"):
		_trap_visual_events.append({"effect": trap.trigger_visual, "cell": player_pos})
	var targets: Array[HeroState] = _living_party_members()
	if trap.can_attach_to("door"):
		targets.clear()
		if opener != null and opener.health > 0 and party.has(opener):
			targets.append(opener)
	for target in targets:
		var avoided: bool = trap.check(target, trap_random)
		if trap.can_attach_to("door") and trap.trigger_visual != "none":
			_trap_visual_events.append({"effect": trap.trigger_visual, "cell": door_cell, "opener_cell": player_pos, "avoided": avoided})
		if avoided:
			_append_trap_result("%s: избежал ловушки «%s»." % [target.definition.display_name, trap.display_name])
			continue
		_apply_trap_effects(trap, target)
	if trap.disarm_on_trigger:
		disarmed_traps[trap_key] = true
		discharged_traps[trap_key] = true


func _apply_trap_effects(trap: TrapDefinition, target: HeroState) -> void:
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
				trap.overworld_status_label, trap.overworld_status_damage, trap.overworld_status_ticks
			])
	if parts.is_empty():
		parts.append("без повреждений")
	_append_trap_result("%s: ловушка «%s», %s." % [
		target.definition.display_name, trap.display_name, " и ".join(parts)
	])


func _activate_traps_at(cell: Vector2i) -> void:
	for entity in map_data.entities_at(cell.x, cell.y):
		if str(entity.get("type", "")) != "trap" or is_trap_disarmed(entity):
			continue
		var trap: TrapDefinition = TrapCatalog.from_entity(entity)
		if trap != null and trap.can_attach_to("floor"):
			_activate_trap(trap, str(entity.get("id", "")))


func has_pending_trap_choice() -> bool:
	return not _pending_trap_choice.is_empty()


func _clear_trap_choice() -> void:
	_pending_trap_choice.clear()
	_pending_trap_actors.clear()
	_pending_trap_accepted.clear()
	_pending_trap_opener = null


func _request_trap_choice(entity: Dictionary, trap: TrapDefinition, cell: Vector2i, accepted: Array[String], opener: HeroState) -> void:
	_pending_trap_choice = {"entity_id": str(entity["id"]), "kind": str(entity["type"]), "cell": cell}
	_pending_trap_accepted = accepted.duplicate()
	_pending_trap_opener = opener
	_pending_trap_actors = _living_party_members()
	var actors: Array[Dictionary] = []
	for member in _pending_trap_actors:
		actors.append({
			"name": member.definition.display_name,
			"portrait": member.definition.portrait,
			"summary": "%d/%d HP" % [member.health, member.effective_max_health()]
		})
	var selected: int = _pending_trap_actors.find(opener)
	var can_disarm: bool = can_disarm_trap(entity)
	var choices: Dictionary = {"cancel": "Нет" if can_disarm else "Отмена", "avoid": "Проскочить (%s)" % trap.avoidance_stat_label()}
	if can_disarm:
		choices["disarm"] = "Да"
	_message_events.append({
		"activation": "trap_choice", "entity_id": entity["id"],
		"text": "%s. Обезвредить ловушку?" % trap.display_name if can_disarm else "%s. Преодолеть ловушку?" % trap.display_name,
		"icon_type": "trap", "icon_id": trap.trap_id,
		"choices": choices,
		"actors": actors, "selected_actor": maxi(selected, 0),
		"select_actor": can_disarm or trap.can_attach_to("door")
	})


func _discard_trap_message(activation: String, entity_id: String) -> void:
	for index in range(_message_events.size() - 1, -1, -1):
		var event: Dictionary = _message_events[index]
		if event.get("activation", "") == activation and event.get("entity_id", "") == entity_id:
			_message_events.remove_at(index)


func _escape_cell_available(cell: Vector2i) -> bool:
	return can_enter(cell) and _find_active_entity(cell, "door").is_empty() and _find_active_entity(cell, "monster").is_empty()


func _request_trap_reaction(entity: Dictionary, trap: TrapDefinition, cell: Vector2i, opened_door_id: String) -> void:
	var direction: Vector2i = cell - player_pos
	var forward: Vector2i = cell + direction
	var forward_available: bool = _escape_cell_available(forward)
	_pending_trap_choice = {
		"entity_id": str(entity["id"]), "kind": "reaction", "cell": cell,
		"origin": player_pos, "forward": forward, "forward_available": forward_available,
		"opened_door_id": opened_door_id
	}
	revealed_traps[str(entity["id"])] = true
	var stat_label: String = trap.avoidance_stat_label()
	_message_events.append({
		"activation": "trap_reaction", "entity_id": entity["id"],
		"title": "%s!" % trap.display_name, "text": trap.trigger_message,
		"prompt": "Куда броситься?", "icon_type": "trap", "icon_id": trap.trap_id,
		"choices": {"back": "Назад (%s)" % stat_label, "forward": "Вперёд (%s)" % stat_label},
		"disabled_choices": [] if forward_available else ["forward"], "select_actor": false
	})


func _resolve_trap_reaction(choice: String, defer_chest_open: bool) -> bool:
	if choice not in ["back", "forward"]:
		return false
	var pending: Dictionary = _pending_trap_choice.duplicate()
	var cell: Vector2i = pending["cell"]
	var origin: Vector2i = pending["origin"]
	var forward: Vector2i = pending["forward"]
	if choice == "forward" and (not pending["forward_available"] or not _escape_cell_available(forward)):
		return false
	var entity: Dictionary = _find_active_entity(cell, "trap")
	if entity.is_empty() or entity["id"] != pending["entity_id"] or is_trap_disarmed(entity):
		return false
	var trap: TrapDefinition = TrapCatalog.from_entity(entity)
	if trap == null or player_pos != origin:
		return false
	_clear_trap_choice()
	_discard_trap_message("trap_reaction", str(entity["id"]))
	last_event_message = ""
	_trap_result_messages.clear()
	_party_damage_events.clear()
	player_pos = cell
	_activate_trap(trap, str(entity["id"]))
	record_casualties()
	if is_party_defeated():
		steps += 1
		_refresh_visibility()
		return true
	if choice == "back":
		player_pos = origin
		_advance_movement_effects()
		record_casualties()
	else:
		var damage: Array[Dictionary] = _party_damage_events.duplicate(true)
		var outcome: Array[String] = _trap_result_messages.duplicate()
		var event_message: String = last_event_message
		var delta: Vector2i = forward - cell
		var accepted: Array[String] = []
		var moved: bool = _move_by(delta.x, delta.y, defer_chest_open, accepted, null)
		if not moved:
			_advance_movement_effects()
			record_casualties()
			if is_party_defeated() and has_pending_trap_choice():
				var pending_id: String = str(_pending_trap_choice["entity_id"])
				_discard_trap_message("trap_choice", pending_id)
				_discard_trap_message("trap_reaction", pending_id)
				_clear_trap_choice()
		damage.append_array(_party_damage_events)
		_party_damage_events = damage
		outcome.append_array(_trap_result_messages)
		_trap_result_messages = outcome
		if not event_message.is_empty():
			_append_event_message(event_message)
	var opened_door_id: String = str(pending.get("opened_door_id", ""))
	if not opened_door_id.is_empty() and not is_party_defeated():
		_activate_message_at(cell, "door_open", opened_door_id)
	_refresh_visibility()
	return player_pos != origin


func resolve_pending_trap_choice(choice: String, actor_index: int = -1, defer_chest_open: bool = false) -> bool:
	if not has_pending_trap_choice():
		return false
	if _pending_trap_choice.get("kind") == "reaction":
		return _resolve_trap_reaction(choice, defer_chest_open)
	if choice not in ["disarm", "cancel", "avoid"]:
		return false
	if choice == "disarm" and failed_trap_disarms.has(str(_pending_trap_choice["entity_id"])):
		return false
	var pending: Dictionary = _pending_trap_choice.duplicate()
	var accepted: Array[String] = _pending_trap_accepted.duplicate()
	var opener: HeroState = _pending_trap_opener
	var actor: HeroState = _door_opener(opener)
	if actor_index >= 0:
		if actor_index >= _pending_trap_actors.size():
			return false
		actor = _pending_trap_actors[actor_index]
	_clear_trap_choice()
	_discard_trap_message("trap_choice", str(pending["entity_id"]))
	if choice == "cancel" or actor == null or actor.health <= 0 or not party.has(actor):
		return false
	var cell: Vector2i = pending["cell"]
	var kind: String = pending["kind"]
	var entity: Dictionary = _find_active_entity(cell, kind)
	if entity.is_empty() or entity.get("id") != pending["entity_id"] or is_trap_disarmed(entity) or not can_enter(cell):
		return false
	var door: Dictionary = _find_active_entity(cell, "door")
	if not door.is_empty() and int(carried_items.get(LockCatalog.required_key(door), 0)) <= 0:
		return false
	var trap: TrapDefinition = TrapCatalog.from_door(entity) if kind == "door" else TrapCatalog.from_entity(entity)
	if trap == null:
		return false
	var entity_id: String = str(entity["id"])
	last_event_message = ""
	_trap_result_messages.clear()
	_party_damage_events.clear()
	if choice == "disarm":
		if trap.check(actor, trap_random, true):
			disarmed_traps[entity_id] = true
			discharged_traps.erase(entity_id)
			revealed_traps[entity_id] = true
			_append_trap_result("%s: ловушка «%s» обезврежена." % [actor.definition.display_name, trap.display_name])
			return false
		failed_trap_disarms[entity_id] = true
		revealed_traps[entity_id] = true
		_append_trap_result("%s: не удалось обезвредить ловушку «%s»." % [actor.definition.display_name, trap.display_name])
		_apply_trap_effects(trap, actor)
		record_casualties()
		_refresh_visibility()
		return false
	if kind == "door":
		opener = actor
	accepted.append(entity_id)
	var prefix: String = last_event_message
	var delta: Vector2i = cell - player_pos
	var moved: bool = _move_by(delta.x, delta.y, defer_chest_open, accepted, opener)
	if not prefix.is_empty():
		_append_trap_result(prefix)
	return moved


func has_pending_door_trap() -> bool:
	return not pending_door_trap_id.is_empty()


func resolve_pending_door_trap() -> bool:
	if not has_pending_door_trap():
		return false
	var door_id: String = pending_door_trap_id
	var cell: Vector2i = pending_door_trap_cell
	var opener: HeroState = _pending_door_opener
	var accepted: Array[String] = _pending_door_accepted.duplicate()
	pending_door_trap_id = ""
	pending_door_trap_cell = Vector2i(-1, -1)
	_pending_door_opener = null
	_pending_door_accepted.clear()
	_discard_trap_message("door_trap", door_id)
	var door: Dictionary = _find_active_entity(cell, "door")
	if door.is_empty() or str(door.get("id", "")) != door_id or not can_enter(cell) or int(carried_items.get(LockCatalog.required_key(door), 0)) <= 0:
		return false
	var trap: TrapDefinition = TrapCatalog.from_door(door)
	if trap != null and not is_trap_disarmed(door):
		if opener == null or opener.health <= 0 or not party.has(opener):
			return false
		_activate_trap(trap, door_id, opener, cell)
		record_casualties()
		if is_party_defeated():
			return false
	var trap_damage: Array[Dictionary] = _party_damage_events.duplicate(true)
	var trap_message: String = last_event_message
	var outcome: String = take_trap_result_message()
	var delta: Vector2i = cell - player_pos
	var moved: bool = _move_by(delta.x, delta.y, true, accepted, opener, door_id)
	trap_damage.append_array(_party_damage_events)
	_party_damage_events = trap_damage
	if not trap_message.is_empty():
		_append_event_message(trap_message)
	if not outcome.is_empty():
		var combined: bool = false
		for event in _message_events:
			if str(event.get("activation", "")) == "door_open":
				event["result_text"] = outcome
				combined = true
				break
		if not combined and trap != null:
			_message_events.append({"activation": "trap_result", "text": outcome, "icon_type": "trap", "icon_id": trap.trap_id})
	return moved


func can_enter(cell: Vector2i) -> bool:
	return contains(cell.x, cell.y) and map_data.get_terrain(cell.x, cell.y) != "wall"


func move_by(dx: int, dy: int, defer_chest_open: bool = false, opener: HeroState = null) -> bool:
	var accepted: Array[String] = []
	return _move_by(dx, dy, defer_chest_open, accepted, opener)


func _move_by(dx: int, dy: int, defer_chest_open: bool, accepted: Array[String], opener: HeroState, resolved_door_id: String = "") -> bool:
	if is_party_defeated() or has_pending_encounter() or is_completed or not pending_chest_id.is_empty() or has_pending_door_trap() or has_pending_trap_choice():
		return false
	last_move_detected_trap = false
	last_event_message = ""
	_trap_result_messages.clear()
	_trigger_events.clear()
	_party_damage_events.clear()
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
	var required_key: String = ""
	var door_trap: TrapDefinition = null
	if not door.is_empty():
		required_key = LockCatalog.required_key(door)
		if int(carried_items.get(required_key, 0)) <= 0:
			last_event_message = "Дверь заперта. Нужен %s ключ." % LockCatalog.label(required_key).to_lower()
			return false
		door_trap = TrapCatalog.from_door(door)
		if door_trap != null and resolved_door_id != str(door["id"]) and _discover_trap(door, door_trap, bool(TrapCatalog.settings(door).get("hidden", true))):
			last_move_detected_trap = true
	var arrival: Vector2i = target
	var local_portal: Dictionary = _find_active_entity(target, "portal_local")
	if not local_portal.is_empty():
		var paired: Vector2i = map_data.local_portal_destination(str(local_portal["id"]))
		if DungeonMap.valid_arrival_cell(map_data, paired):
			arrival = paired
	if arrival == target and resolved_door_id.is_empty() and _discover_floor_traps(target):
		last_move_detected_trap = true
	if last_move_detected_trap:
		return false

	if arrival == target and resolved_door_id.is_empty():
		var floor_trap: Dictionary = _find_active_entity(target, "trap")
		if not floor_trap.is_empty() and not is_trap_disarmed(floor_trap) and not is_entity_hidden_from_hero(floor_trap) and not accepted.has(str(floor_trap["id"])):
			var definition: TrapDefinition = TrapCatalog.from_entity(floor_trap)
			if definition != null:
				_request_trap_choice(floor_trap, definition, target, accepted, opener)
				return false
	if not door.is_empty():
		if door_trap != null and not is_trap_disarmed(door) and resolved_door_id != str(door["id"]):
			if is_door_trap_visible(door) and not accepted.has(str(door["id"])):
				_request_trap_choice(door, door_trap, target, accepted, opener)
				return false
			_pending_door_opener = _door_opener(opener)
			_pending_door_accepted = accepted.duplicate()
			pending_door_trap_id = str(door["id"])
			pending_door_trap_cell = target
			_message_events.append({
				"activation": "door_trap", "entity_id": pending_door_trap_id,
				"text": DungeonMap.door_trap_message(door), "loot": [],
				"icon_type": "trap", "icon_id": door_trap.trap_id
			})
			return false
		_remove_carried_item(required_key, 1)
		opened_door_id = str(door["id"])
		removed_entities[opened_door_id] = true
		last_event_message = "Ключ использован. Дверь открыта!"

	if arrival == target and absi(dx) + absi(dy) == 1:
		var hidden_trap: Dictionary = _find_active_entity(target, "trap")
		if not hidden_trap.is_empty() and not is_trap_disarmed(hidden_trap) and not accepted.has(str(hidden_trap["id"])) and is_entity_hidden_from_hero(hidden_trap):
			var hidden_definition: TrapDefinition = TrapCatalog.from_entity(hidden_trap)
			if hidden_definition != null and hidden_definition.hidden_entry_reaction == "directional_escape":
				_request_trap_reaction(hidden_trap, hidden_definition, target, opened_door_id)
				return false

	# Проверка сундука после двери: нельзя получить добычу через замок.
	var chest := _find_active_entity(target, "chest")
	if not chest.is_empty() and not is_chest_open(chest):
		if defer_chest_open:
			pending_chest_id = str(chest["id"])
		else:
			_open_chest(chest)

	player_pos = arrival
	target = arrival
	_advance_movement_effects()
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
	var stairs: Dictionary = _find_active_entity(target, "stairs_down")
	if has_stairs_up() and target == map_data.find_entity_position("player_spawn"):
		_pending_return_exit = {
			"type": "stairs_up", "id": "return_stairs",
			"properties": {"target_map_id": str(_stairs_history.back()["from"])}
		}
		is_completed = true
	elif not stairs.is_empty():
		_claim_exit_reward(stairs)
		is_completed = true
	else:
		var portal: Dictionary = _find_active_entity(target, "portal")
		if not portal.is_empty() and not DungeonMap.exit_target_id(portal).is_empty():
			is_completed = true
	return true


func _advance_movement_effects() -> void:
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
	return is_chest_open(chest)


func loot_depth() -> int:
	var configured: Variant = map_data.metadata.get("loot_depth", null) if map_data != null else null
	if typeof(configured) in [TYPE_INT, TYPE_FLOAT]:
		return maxi(int(configured), 0)
	return _stairs_history.size()


func _resolve_source_rewards(source: Dictionary) -> Array[Dictionary]:
	match str(source.get("type", "")):
		"monster":
			return _resolve_rewards(DungeonMap.monster_loot_contents(source), DungeonMap.monster_loot_is_random(source),
				DungeonMap.monster_gold_amount(source), DungeonMap.monster_item_quantities(source), source)
		"chest", "stairs_down":
			return _resolve_rewards(DungeonMap.chest_contents(source), DungeonMap.chest_is_random(source),
				DungeonMap.chest_gold_amount(source), DungeonMap.chest_item_quantities(source), source)
	return []


func _resolve_rewards(contents: Array[String], random_mode: bool, gold_amount: int, quantities: Dictionary = {}, source: Dictionary = {}) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	var level: int = DungeonMap.loot_level(source)
	var rules: LootRewardLevel = LootProfile.level_rules(level)
	if random_mode:
		var profile: LootProfile = LootProfileCatalog.for_source(source)
		if profile != null:
			rewards = profile.roll(trap_random, loot_victories, loot_depth(), level)
		else:
			var stage: int = rules.stage_for(ItemCatalog.LOOT_TABLE, loot_victories, loot_depth())
			var reward: Dictionary = ItemCatalog.roll_loot(trap_random, ItemCatalog.LOOT_TABLE, stage)
			if not reward.is_empty():
				if bool(reward.get("roll_magic", false)):
					reward["loot_stage"] = stage
				rules.apply_quantity(reward)
				rewards.append(reward)
	for item_id in contents:
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		if item == null:
			continue
		var fallback: int = gold_amount if item_id == "gold" else item.default_quantity
		var quantity: int = clampi(int(quantities.get(item_id, fallback)), 1, 999999 if item_id == "gold" else 9999)
		var reward: Dictionary = {"item_id": item_id, "quantity": quantity}
		if item.category == ItemDefinition.Category.EQUIPMENT and not item.stackable:
			reward["roll_magic"] = true
			reward["loot_stage"] = maxi(ItemCatalog.LOOT_TABLE.stage_for_victories(loot_victories), rules.minimum_stage)
		rewards.append(reward)
	for index in range(rewards.size()):
		rewards[index] = _materialize_reward(rewards[index], trap_random)
	return rewards


func _materialize_reward(reward: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var item_id: String = str(reward["item_id"])
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	var quantity: int = int(reward["quantity"])
	var resolved: Dictionary = {"item_id": item_id, "quantity": quantity}
	if item == null or item.category != ItemDefinition.Category.EQUIPMENT or item.stackable:
		return resolved
	var instances: Array[Dictionary] = []
	var durabilities: Array = reward.get("durabilities", [])
	var stage: int = int(reward.get("loot_stage", -1))
	if stage < 0:
		stage = ItemCatalog.LOOT_TABLE.stage_for_victories(loot_victories)
	for index in range(quantity):
		var durability: int = int(durabilities[index]) if index < durabilities.size() else -1
		var instance: ItemInstance = _allocate_item_instance(item, durability)
		if bool(reward.get("roll_magic", false)):
			ItemMagicCatalog.roll(instance, item, rng, stage, reward.get("rarity_weights", {}))
			if _is_shield(item_id) and durability < 0:
				instance.durability = maxi(instance.stat("max_durability"), instance.stat("defense_bonus"))
		instances.append(instance.to_dict())
	resolved["instances"] = instances
	return resolved


func _open_chest(chest: Dictionary) -> void:
	if hero == null or is_party_defeated() or is_chest_open(chest) or is_entity_removed(chest):
		return
	opened_chests[str(chest["id"])] = true
	var rewards: Array[Dictionary] = _resolve_source_rewards(chest)
	var cell := Vector2i(int(chest["x"]), int(chest["y"]))
	for reward in rewards:
		_receive_reward(reward, cell)
	_activate_message_at(cell, "chest_open", str(chest["id"]), rewards)


func _receive_item(item_id: String, quantity: int, durabilities: Array = [], roll_magic: bool = false, drop_cell: Vector2i = Vector2i(-1, -1), loot_stage: int = -1, rarity_weights: Dictionary = {}) -> int:
	if quantity <= 0 or hero == null or ItemCatalog.get_item(item_id) == null:
		return 0
	var reward: Dictionary = _materialize_reward({"item_id": item_id, "quantity": quantity,
		"durabilities": durabilities, "roll_magic": roll_magic, "loot_stage": loot_stage,
		"rarity_weights": rarity_weights}, trap_random)
	return _receive_reward(reward, drop_cell)


func _receive_reward(reward: Dictionary, drop_cell: Vector2i) -> int:
	if drop_cell.x < 0:
		drop_cell = player_pos
	var item_id: String = str(reward["item_id"])
	if item_id == "key_yellow":
		item_id = "key"
	var quantity: int = int(reward["quantity"])
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	if item == null or quantity <= 0 or hero == null:
		return 0
	var instances: Array[ItemInstance] = []
	if item.category == ItemDefinition.Category.EQUIPMENT and not item.stackable:
		var records: Array = reward.get("instances", [])
		if records.size() != quantity:
			return 0
		var seen: Dictionary = {}
		for record in records:
			var instance: ItemInstance = ItemInstance.from_dict(record)
			if instance == null or instance.item_id != item_id or seen.has(instance.instance_id) or _item_instances.has(instance.instance_id):
				return 0
			seen[instance.instance_id] = true
			instances.append(instance)
	if item.category == ItemDefinition.Category.CURRENCY:
		hero.gold += quantity
		return quantity
	if item.stackable and item.category != ItemDefinition.Category.EQUIPMENT:
		var added: int = _fill_stack_slots(_inventory_order, _bag_quantities, item, quantity)
		if added > 0:
			_update_carried_count(item_id, added)
		if added < quantity:
			_append_ground_loot(drop_cell, [{"item_id": item_id, "quantity": quantity - added}])
		return added
	var bag: Array[String] = inventory_slot_ids()
	var equipped: Dictionary = _equipment_snapshot(hero)
	var is_shield: bool = _is_shield(item_id)
	var shield_layout: Dictionary = _shield_layout(bag, equipped, hero) if is_shield else {}
	var equipment_changed: bool = false
	var received: int = 0
	var overflow_durabilities: Array = []
	var overflow_instances: Array[Dictionary] = []
	for index in range(quantity):
		var location: String = ""
		if item.category == ItemDefinition.Category.EQUIPMENT:
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
				_bag_quantities[free] = 1
		var instance: ItemInstance = instances[index] if not instances.is_empty() else null
		if location.is_empty():
			if instance != null:
				overflow_instances.append(instance.to_dict())
			if is_shield:
				overflow_durabilities.append(instance.durability if instance != null else _new_shield_durability(item_id))
			continue
		if location.begins_with("equipment:"):
			equipped[location.trim_prefix("equipment:")] = item_id
			equipment_changed = true
		if instance != null:
			_item_instances[instance.instance_id] = instance
			if location.begins_with("bag:"):
				_bag_instance_ids[int(location.trim_prefix("bag:"))] = instance.instance_id
			elif location.begins_with("equipment:"):
				hero.equipped_instance_ids[location.trim_prefix("equipment:")] = instance.instance_id
		if is_shield:
			shield_layout[location] = instance.durability if instance != null else _new_shield_durability(item_id)
		received += 1
	if received > 0:
		carried_items[item_id] = int(carried_items.get(item_id, 0)) + received
		_inventory_order = bag
		hero.equipped_weapon_id = str(equipped["main_hand"])
		hero.equipped_shield_id = str(equipped["off_hand"])
		if is_shield:
			_apply_shield_layout(bag, equipped, shield_layout, hero)
			_update_instance_shield_values(shield_layout, hero)
		if equipment_changed:
			hero._recalculate_equipment_stats()
		keys = int(carried_items.get("key", 0))
		potions = int(carried_items.get("potion", 0))
	var overflow: int = quantity - received
	if overflow > 0:
		var entry: Dictionary = {"item_id": item_id, "quantity": overflow}
		if is_shield:
			entry["durabilities"] = overflow_durabilities
		if not overflow_instances.is_empty():
			entry["instances"] = overflow_instances
		_append_ground_loot(drop_cell, [entry])
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
	var outcome: Dictionary = use_item(item_id, hero)
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
	var bag: Array[String] = inventory_slot_ids()
	var source: int = bag.find(item_id)
	if source < 0:
		return false
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		if EquipmentSlotRules.accepts(slot_id, item) and equipment_item_id(slot_id).is_empty():
			if transfer_inventory_item("bag", source, "equipment", slot_id):
				return true
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		if EquipmentSlotRules.accepts(slot_id, item):
			if transfer_inventory_item("bag", source, "equipment", slot_id):
				return true
	return false


func unequip_item(item_id: String) -> bool:
	if hero == null or item_id.is_empty():
		return false
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		if equipment_item_id(slot_id) == item_id:
			return unequip_equipment_slot(slot_id)
	return false


func unequip_equipment_slot(slot_id: String) -> bool:
	if hero == null or not EquipmentSlotRules.SLOT_IDS.has(slot_id) or equipment_item_id(slot_id).is_empty():
		return false
	var free: int = inventory_slot_ids().find("")
	return free >= 0 and transfer_inventory_item("equipment", slot_id, "bag", free)


## Выполняется после ответной атаки; удаляем только сломанный экземпляр.
func resolve_broken_shield(member: HeroState = null) -> String:
	var owner: HeroState = member if member != null else hero
	if owner == null or not owner.equipped_shield_id.is_empty():
		return ""
	var broken_instance_id: String = str(owner.equipped_instance_ids.get("off_hand", ""))
	var instance: ItemInstance = item_instance(broken_instance_id)
	owner.equipped_instance_ids.erase("off_hand")
	owner.last_shield_broken = ""
	if instance == null or not _is_shield(instance.item_id):
		return ""
	var item_id: String = instance.item_id
	_item_instances.erase(broken_instance_id)
	var count: int = int(carried_items.get(item_id, 0))
	if count > 0:
		carried_items[item_id] = count - 1
	return item_id

## Сообщение используется в самом окне инвентаря, не как всплывающий игровой диалог.
func use_item(item_id: String, recipient: HeroState = null, bag_index: int = -1) -> Dictionary:
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	if item == null or int(carried_items.get(item_id, 0)) <= 0:
		return {"used": false, "message": "Этого предмета нет в рюкзаке."}
	if hero == null:
		return {"used": false, "message": "Герой недоступен."}
	var chosen: HeroState = recipient if recipient != null else hero
	if not party.has(chosen) or chosen.health <= 0:
		return {"used": false, "message": "Герой недоступен."}
	if bag_index >= 0 and (bag_index >= _inventory_order.size() or _inventory_order[bag_index] != item_id or _bag_quantities[bag_index] <= 0):
		return {"used": false, "message": "Этого предмета нет в рюкзаке."}
	var result: Dictionary = chosen.apply_potion(item)
	if bool(result.get("used", false)):
		_remove_carried_item(item_id, 1, bag_index)
		_refresh_visibility()
	return result


func _remove_carried_item(item_id: String, quantity: int, preferred_index: int = -1) -> bool:
	var current: int = int(carried_items.get(item_id, 0))
	if quantity <= 0 or current < quantity:
		return false
	var bag: Array[String] = inventory_slot_ids()
	var indices: Array[int] = []
	var available: int = 0
	if preferred_index >= 0:
		if preferred_index >= bag.size() or bag[preferred_index] != item_id:
			return false
		indices.append(preferred_index)
		available += _bag_quantities[preferred_index]
	for index in range(bag.size()):
		if index != preferred_index and bag[index] == item_id:
			indices.append(index)
			available += _bag_quantities[index]
	if available < quantity:
		return false
	var shield_layout: Dictionary = _shield_layout(bag, _equipment_snapshot(hero), hero) if hero != null and _is_shield(item_id) else {}
	var remaining: int = quantity
	for index in indices:
		var removed: int = mini(remaining, _bag_quantities[index])
		_bag_quantities[index] -= removed
		remaining -= removed
		if _bag_quantities[index] == 0:
			bag[index] = ""
			_item_instances.erase(_bag_instance_ids[index])
			_bag_instance_ids[index] = ""
			shield_layout.erase("bag:%d" % index)
		if remaining == 0:
			break
	_inventory_order = bag
	_update_carried_count(item_id, -quantity)
	if _is_shield(item_id) and hero != null:
		_apply_shield_layout(bag, _equipment_snapshot(hero), shield_layout, hero)
		_update_instance_shield_values(shield_layout, hero)
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
	var radius: int = VISION_RADIUS + (hero.vision_bonus if hero != null and hero.has_vision_effect() else 0)
	var bounds := Rect2i(player_pos - Vector2i(radius, radius), Vector2i.ONE * (2 * radius + 1))
	bounds = bounds.intersection(Rect2i(0, 0, map_data.width, map_data.height))
	if debug_open_map:
		if not _debug_visibility_applied:
			_revealed_before_debug_open_map = revealed.duplicate(true)
			for y in range(map_data.height):
				visible[y].fill(true)
				revealed[y].fill(true)
			_debug_visibility_applied = true
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				_revealed_before_debug_open_map[y][x] = true
		return
	if _debug_visibility_applied:
		for y in range(map_data.height):
			visible[y].fill(false)
		_debug_visibility_applied = false
	else:
		for y in range(_visible_bounds.position.y, _visible_bounds.end.y):
			for x in range(_visible_bounds.position.x, _visible_bounds.end.x):
				visible[y][x] = false
	_visible_bounds = bounds
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			visible[y][x] = true
			revealed[y][x] = true


func _claim_exit_reward(stairs: Dictionary) -> void:
	var entity_id: String = str(stairs["id"])
	if claimed_exit_rewards.has(entity_id):
		return
	claimed_exit_rewards[entity_id] = true
	var rewards: Array[Dictionary] = _resolve_source_rewards(stairs)
	for reward in rewards:
		_receive_reward(reward, player_pos)
	if not rewards.is_empty():
		_message_events.append({"text": "Награда за прохождение подземелья", "activation": "exit_reward", "loot": rewards})


func progress_snapshot() -> Dictionary:
	if is_editor_test or map_data == null or is_party_defeated() or has_pending_encounter() or not pending_chest_id.is_empty() or has_pending_door_trap() or has_pending_trap_choice() or is_completed:
		return {}
	var party_data: Dictionary = party_state_snapshot()
	if party_data.is_empty():
		return {}
	var floors_data: Dictionary = {}
	for map_id in visited_floor_snapshots():
		var snapshot: Dictionary = floor_state_snapshot(str(map_id))
		var source_map: DungeonMap = known_map(str(map_id))
		if source_map == null:
			return {}
		var encoded: Dictionary = ProgressSnapshotCodec.encode_floor(snapshot)
		encoded["map_signature"] = ProgressSnapshotCodec.map_signature(source_map)
		floors_data[str(map_id)] = encoded
	return {
		"version": ProgressSnapshotCodec.FORMAT_VERSION,
		"campaign_id": campaign_id,
		"current_map_id": map_data.map_id,
		"party": party_data,
		"floors": floors_data,
		"ground_loot_counter": _ground_loot_counter,
		"stairs_history": _stairs_history.duplicate(true)
	}


static func from_progress_snapshot(snapshot: Variant, maps_by_id: Dictionary, campaigns: Dictionary = {}) -> GameSession:
	if not (snapshot is Dictionary) or not ProgressSnapshotCodec._is_integer(snapshot.get("version")):
		return null
	var version: int = int(snapshot["version"])
	if version not in [ProgressSnapshotCodec.FORMAT_VERSION, ProgressSnapshotCodec.PREVIOUS_FORMAT_VERSION, ProgressSnapshotCodec.LEGACY_FORMAT_VERSION]:
		return null
	if version == ProgressSnapshotCodec.LEGACY_FORMAT_VERSION and snapshot.has("campaign_id"):
		return null
	if version != ProgressSnapshotCodec.LEGACY_FORMAT_VERSION and typeof(snapshot.get("campaign_id")) != TYPE_STRING:
		return null
	if version == ProgressSnapshotCodec.FORMAT_VERSION and not (snapshot.get("party") is Dictionary and snapshot["party"].has("item_instances")):
		return null
	var current_id: String = str(snapshot.get("current_map_id", ""))
	var floors_data: Variant = snapshot.get("floors")
	if current_id.is_empty() or not (floors_data is Dictionary) or not floors_data.has(current_id) or not (snapshot.get("party") is Dictionary):
		return null
	var saved_campaign_id: String = str(snapshot.get("campaign_id", ""))
	var owners: Dictionary = {}
	for campaign_key in campaigns:
		var listed: Variant = campaigns[campaign_key]
		if not (listed is CampaignDefinition) or listed.campaign_id != campaign_key or not listed.has_valid_maps(maps_by_id):
			return null
		for member_id in listed.map_ids:
			if owners.has(member_id):
				return null
			owners[member_id] = campaign_key
	if version == ProgressSnapshotCodec.LEGACY_FORMAT_VERSION:
		var inferred_id: String = str(owners.get(current_id, ""))
		for floor_id in floors_data:
			if str(owners.get(floor_id, "")) != inferred_id:
				return null
		saved_campaign_id = inferred_id
	elif not saved_campaign_id.is_empty():
		if not campaigns.has(saved_campaign_id):
			return null
	elif owners.has(current_id):
		return null
	var allowed: Dictionary = {}
	if not saved_campaign_id.is_empty():
		var saved_campaign: CampaignDefinition = campaigns[saved_campaign_id]
		for member_id in saved_campaign.map_ids:
			allowed[member_id] = true
	for floor_id in floors_data:
		if not (floor_id is String):
			return null
		if not saved_campaign_id.is_empty() and not allowed.has(floor_id):
			return null
		if saved_campaign_id.is_empty() and owners.has(floor_id):
			return null
	var counter_value: Variant = snapshot.get("ground_loot_counter")
	if not ProgressSnapshotCodec._is_integer(counter_value) or int(counter_value) < 0:
		return null
	var history_data: Variant = snapshot.get("stairs_history")
	if not (history_data is Array):
		return null
	var restored_history: Array[Dictionary] = []
	for record in history_data:
		if not (record is Dictionary):
			return null
		if typeof(record.get("from")) != TYPE_STRING or typeof(record.get("to")) != TYPE_STRING:
			return null
		var from_id: String = str(record["from"])
		var to_id: String = str(record["to"])
		if not maps_by_id.has(from_id) or not maps_by_id.has(to_id) or not (maps_by_id[from_id] is DungeonMap) or not (maps_by_id[to_id] is DungeonMap):
			return null
		if not saved_campaign_id.is_empty() and (not allowed.has(from_id) or not allowed.has(to_id)):
			return null
		var normalized: Dictionary = {"from": from_id, "to": to_id}
		if record.has("from_cell"):
			var coords: Variant = record["from_cell"]
			if not (coords is Array) or coords.size() != 2 or not ProgressSnapshotCodec._is_integer(coords[0]) or not ProgressSnapshotCodec._is_integer(coords[1]):
				return null
			normalized["from_cell"] = [int(coords[0]), int(coords[1])]
		if record.has("from_exit_id"):
			if typeof(record["from_exit_id"]) != TYPE_STRING or str(record["from_exit_id"]).is_empty():
				return null
			normalized["from_exit_id"] = record["from_exit_id"]
		restored_history.append(normalized)
	var restored_floors: Dictionary = {}
	for raw_map_id in floors_data:
		if typeof(raw_map_id) != TYPE_STRING or not maps_by_id.has(raw_map_id) or not (maps_by_id[raw_map_id] is DungeonMap):
			return null
		var map_ref: DungeonMap = maps_by_id[raw_map_id]
		if map_ref.map_id != raw_map_id or not DungeonMap.valid_arrival_cell(map_ref, map_ref.find_entity_position("player_spawn")):
			return null
		var raw_floor: Variant = floors_data[raw_map_id]
		if not (raw_floor is Dictionary):
			return null
		if raw_floor.has("map_signature"):
			if typeof(raw_floor["map_signature"]) != TYPE_STRING or str(raw_floor["map_signature"]) != ProgressSnapshotCodec.map_signature(map_ref):
				return null
		var floor_data: Dictionary = ProgressSnapshotCodec.decode_floor(raw_floor, map_ref)
		if floor_data.is_empty():
			return null
		floor_data["map"] = map_ref
		restored_floors[raw_map_id] = floor_data
	for record in restored_history:
		if not restored_floors.has(record["from"]) or not restored_floors.has(record["to"]):
			return null
		var origin: Dictionary = restored_floors[record["from"]]
		var origin_map: DungeonMap = origin["map"]
		var cell: Vector2i = _history_origin(record, origin["position"])
		if not _matching_return_stair(origin_map, cell, str(record.get("from_exit_id", "")), str(record["to"])):
			return null
		if not _return_cell_is_open(origin_map, cell, origin["removed"]):
			return null
		if not record.has("from_cell"):
			record["from_cell"] = [cell.x, cell.y]
		if not record.has("from_exit_id"):
			for entity in origin_map.entities_at(cell.x, cell.y):
				if str(entity.get("type", "")) == "stairs_down" and DungeonMap.exit_target_id(entity) == str(record["to"]):
					record["from_exit_id"] = str(entity["id"])
					break
	var ground_ids: Dictionary = {}
	for floor_id in restored_floors:
		for container in restored_floors[floor_id]["ground_loot"]:
			var container_id: String = str(container["id"])
			if ground_ids.has(container_id):
				return null
			ground_ids[container_id] = true
			if container_id.begins_with("ground_"):
				var counter_text: String = container_id.trim_prefix("ground_")
				if not counter_text.is_valid_int() or int(counter_text) > int(counter_value):
					return null
	var session := GameSession.new()
	var current: Dictionary = restored_floors[current_id]
	session.map_data = current["map"]
	session.player_pos = current["position"]
	session._ground_loot_counter = int(counter_value)
	for container in current["ground_loot"]:
		session._add_ground_container(container.duplicate(true))
	if not session.restore_party_state(snapshot["party"]):
		return null
	var known_instance_ids: Dictionary = {}
	for instance_id in session._item_instances:
		known_instance_ids[instance_id] = true
	for restored_floor in restored_floors.values():
		for container in restored_floor["ground_loot"]:
			for entry in container["loot"]:
				for raw_instance in entry.get("instances", []):
					var instance: ItemInstance = ItemInstance.from_dict(raw_instance)
					if instance == null or known_instance_ids.has(instance.instance_id):
						return null
					var number_text: String = instance.instance_id.trim_prefix("item_")
					if not instance.instance_id.begins_with("item_") or not number_text.is_valid_int() or int(number_text) > session._next_item_instance_number:
						return null
					known_instance_ids[instance.instance_id] = true
	session._floor_states = restored_floors.duplicate()
	session._floor_states.erase(current_id)
	session._stairs_history = restored_history
	session.claimed_exit_rewards = current["exit_rewards"].duplicate(true)
	session.removed_entities = current["removed"].duplicate(true)
	session.opened_chests = current["chests"].duplicate(true)
	session.disarmed_traps = current["traps"].duplicate(true)
	session.revealed_traps = current["revealed_traps"].duplicate(true)
	session.discharged_traps = current["discharged_traps"].duplicate(true)
	session.failed_trap_disarms = current["failed_trap_disarms"].duplicate(true)
	session.activated_triggers = current["triggers"].duplicate(true)
	session.shown_messages = current["messages"].duplicate(true)
	session._init_masks()
	session.revealed = current["revealed"].duplicate(true)
	session._refresh_visibility()
	if not saved_campaign_id.is_empty() and not session.set_campaign(campaigns[saved_campaign_id]):
		return null
	ItemCatalog.prepare()
	LootProfileCatalog.prepare()
	return session


func developer_remove_bag_slot(index: int) -> bool:
	if not DeveloperMode.is_enabled() or not is_editor_test:
		return false
	var bag: Array[String] = inventory_slot_ids()
	if index < 0 or index >= bag.size() or bag[index].is_empty():
		return false
	var item_id: String = bag[index]
	var definition: ItemDefinition = ItemCatalog.get_item(item_id)
	if definition == null:
		return false
	if definition.stackable:
		return _remove_carried_item(item_id, _bag_quantities[index], index)
	var member: HeroState = _inventory_equipment_member()
	var equipped: Dictionary = _equipment_snapshot(member)
	var shield_layout: Dictionary = _shield_layout(bag, equipped, member) if _is_shield(item_id) else {}
	_item_instances.erase(_bag_instance_ids[index])
	_bag_instance_ids[index] = ""
	bag[index] = ""
	_bag_quantities[index] = 0
	_inventory_order = bag
	carried_items[item_id] = maxi(0, int(carried_items.get(item_id, 0)) - 1)
	if _is_shield(item_id):
		shield_layout.erase("bag:%d" % index)
		_apply_shield_layout(bag, equipped, shield_layout, member)
		_update_instance_shield_values(shield_layout, member)
	keys = int(carried_items.get("key", 0))
	potions = int(carried_items.get("potion", 0))
	return true


func developer_add_item(item_id: String, quantity: int = 1) -> Dictionary:
	if not DeveloperMode.is_enabled() or not is_editor_test or hero == null:
		return {}
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	if item == null or quantity < 1 or quantity > 9999:
		return {}
	if item.category == ItemDefinition.Category.CURRENCY:
		hero.gold += quantity
		return {"received": quantity, "instances": []}
	if item.stackable:
		var received: int = _fill_stack_slots(_inventory_order, _bag_quantities, item, quantity)
		if received > 0:
			_update_carried_count(item_id, received)
		return {"received": received, "instances": []}
	var bag: Array[String] = inventory_slot_ids()
	var created_ids: Array[String] = []
	var added: int = 0
	for _n in range(quantity):
		var index: int = bag.find("")
		if index < 0:
			break
		bag[index] = item_id
		_bag_quantities[index] = 1
		if item.category == ItemDefinition.Category.EQUIPMENT and not item.stackable:
			var instance: ItemInstance = _create_item_instance(item_id)
			if instance == null:
				break
			_bag_instance_ids[index] = instance.instance_id
			created_ids.append(instance.instance_id)
		added += 1
	if added > 0:
		_inventory_order = bag
		carried_items[item_id] = int(carried_items.get(item_id, 0)) + added
		if _is_shield(item_id):
			var layout: Dictionary = _shield_layout(bag, _equipment_snapshot(hero), hero)
			for i in range(bag.size()):
				if bag[i] == item_id and not layout.has("bag:%d" % i):
					layout["bag:%d" % i] = _new_shield_durability(item_id)
			_apply_shield_layout(bag, _equipment_snapshot(hero), layout, hero)
			_update_instance_shield_values(layout, hero)
		keys = int(carried_items.get("key", 0))
		potions = int(carried_items.get("potion", 0))
	return {"received": added, "instances": created_ids}


func developer_refresh_shield(instance_id: String) -> void:
	if not DeveloperMode.is_enabled() or not is_editor_test:
		return
	var instance: ItemInstance = item_instance(instance_id)
	if instance == null or not _is_shield(instance.item_id):
		return
	var bag: Array[String] = inventory_slot_ids()
	var index: int = _bag_instance_ids.find(instance_id)
	if index >= 0:
		var equipped: Dictionary = _equipment_snapshot(hero)
		var layout: Dictionary = _shield_layout(bag, equipped, hero)
		layout["bag:%d" % index] = instance.durability
		_apply_shield_layout(bag, equipped, layout, hero)
		return
	for member in party:
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			if str(member.equipped_instance_ids.get(slot_id, "")) == instance_id:
				var equipped: Dictionary = _equipment_snapshot(member)
				var layout: Dictionary = _shield_layout(bag, equipped, member)
				layout["equipment:%s" % slot_id] = instance.durability
				_apply_shield_layout(bag, equipped, layout, member)
				return

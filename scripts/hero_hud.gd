class_name HeroHUD
extends MarginContainer

signal status_info_requested(title: String, description: String)

@onready var _party_row: HBoxContainer = $PartyRow
var _slots: Array[PartyPortraitSlot] = []


func set_hero(hero: HeroState) -> void:
	var members: Array[HeroState] = []
	if hero != null:
		members.append(hero)
	set_party(members)


func set_party(members: Array[HeroState]) -> void:
	if _party_row == null:
		return
	var count: int = mini(members.size(), GameSession.MAX_PARTY_SIZE)
	while _slots.size() < count:
		var slot := PartyPortraitSlot.new()
		_party_row.add_child(slot)
		slot.status_info_requested.connect(_forward_status_info)
		_slots.append(slot)
	for i in range(_slots.size()):
		if i < count:
			_slots[i].display_member(members[i])
		else:
			_slots[i].hide()


func flash_hero(member_index: int) -> void:
	if member_index >= 0 and member_index < _slots.size() and _slots[member_index].visible:
		_slots[member_index].flash_damage()


func _forward_status_info(title: String, description: String) -> void:
	status_info_requested.emit(title, description)

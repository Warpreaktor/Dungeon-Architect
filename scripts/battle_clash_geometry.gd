class_name BattleClashGeometry
extends RefCounted


static func contact_positions(idle_positions: Dictionary, portrait_sizes: Dictionary, attackers: Dictionary, overlap_fraction: float, portrait_scale: float = 1.0) -> Dictionary:
	var positions: Dictionary = {}
	for raw_actor_id in attackers:
		var actor_id: String = str(raw_actor_id)
		var target_id: String = str(attackers[actor_id])
		if not idle_positions.has(actor_id) or not idle_positions.has(target_id):
			continue
		if not portrait_sizes.has(actor_id) or not portrait_sizes.has(target_id):
			continue
		var actor_pos: Vector2 = idle_positions[actor_id]
		var target_pos: Vector2 = idle_positions[target_id]
		var actor_size: Vector2 = portrait_sizes[actor_id]
		var target_size: Vector2 = portrait_sizes[target_id]
		var scale_factor: float = maxf(portrait_scale, 0.0)
		var actor_visual_width: float = actor_size.x * scale_factor
		var target_visual_width: float = target_size.x * scale_factor
		var actor_visual_inset: float = (actor_visual_width - actor_size.x) * 0.5
		var target_visual_inset: float = (target_visual_width - target_size.x) * 0.5
		var actor_center_x: float = actor_pos.x + actor_size.x * 0.5
		var target_center_x: float = target_pos.x + target_size.x * 0.5
		var approaches_from_left: bool = actor_center_x < target_center_x
		var overlap: float = minf(actor_visual_width, target_visual_width) * clampf(overlap_fraction, 0.0, 1.0)
		var visual_contact_x: float
		if str(attackers.get(target_id, "")) == actor_id:
			var shared_contact_x: float = (actor_center_x + target_center_x) * 0.5
			visual_contact_x = shared_contact_x - actor_visual_width + overlap * 0.5 if approaches_from_left else shared_contact_x - overlap * 0.5
		else:
			var target_visual_left: float = target_pos.x - target_visual_inset
			visual_contact_x = target_visual_left - actor_visual_width + overlap if approaches_from_left else target_visual_left + target_visual_width - overlap
		var actor_center_y: float = actor_pos.y + actor_size.y * 0.5
		var target_center_y: float = target_pos.y + target_size.y * 0.5
		var contact_center_y: float = (actor_center_y + target_center_y) * 0.5 if str(attackers.get(target_id, "")) == actor_id else target_center_y
		positions[actor_id] = Vector2(visual_contact_x + actor_visual_inset, contact_center_y - actor_size.y * 0.5)
	return positions


static func approach_seconds(base_seconds: float, start_positions: Dictionary, contact_positions_by_actor: Dictionary, portrait_sizes: Dictionary) -> float:
	var longest_distance_in_portrait_widths: float = 1.0
	for raw_actor_id in contact_positions_by_actor:
		var actor_id: String = str(raw_actor_id)
		if not start_positions.has(actor_id) or not portrait_sizes.has(actor_id):
			continue
		var start_pos: Vector2 = start_positions[actor_id]
		var end_pos: Vector2 = contact_positions_by_actor[actor_id]
		var size: Vector2 = portrait_sizes[actor_id]
		longest_distance_in_portrait_widths = maxf(longest_distance_in_portrait_widths,
			start_pos.distance_to(end_pos) / maxf(size.x, 1.0))
	return base_seconds * longest_distance_in_portrait_widths

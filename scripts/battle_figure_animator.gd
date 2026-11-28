class_name BattleFigureAnimator
extends RefCounted

const IDLE: StringName = &"idle"
const WIND_UP: StringName = &"wind_up"
const STRIKE: StringName = &"strike"
const HURT: StringName = &"hurt"
const DEFEATED_MODULATE: Color = Color("#87909c")

var figure: TextureRect
var profile: CombatVisualProfile
var state: StringName = IDLE
var current_pose: CombatVisualPose
var home: Vector2
var ground: Vector2
var reference_height: float
var _pose_sprite: TextureRect
var _idle_self_modulate: Color
var _idle_modulate: Color
var _idle_scale: Vector2
var _idle_z_index: int


func _init(node: TextureRect, visual_profile: CombatVisualProfile = null) -> void:
	figure = node
	profile = visual_profile
	home = figure.position
	_idle_self_modulate = figure.self_modulate
	_idle_modulate = figure.modulate
	_idle_scale = figure.scale
	_idle_z_index = figure.z_index
	if profile == null or profile.resolve_pose(IDLE) == null:
		profile = null
		return
	current_pose = profile.resolve_pose(IDLE)
	var idle_rect: Rect2 = BattleFigureLayout.visual_rect(figure)
	ground = idle_rect.position + CombatVisualPose.point_offset(current_pose.ground_anchor, idle_rect.size, figure.flip_h)
	reference_height = idle_rect.size.y / current_pose.height_scale
	figure.pivot_offset = ground
	_pose_sprite = TextureRect.new()
	_pose_sprite.name = "CombatPose"
	_pose_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pose_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	_pose_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pose_sprite.flip_h = figure.flip_h
	_pose_sprite.material = figure.material
	_pose_sprite.hide()
	figure.add_child(_pose_sprite)
	figure.move_child(_pose_sprite, 0)


func set_pose(next_state: StringName, ability_id: String = "") -> void:
	state = next_state
	if profile == null:
		return
	current_pose = profile.resolve_pose(next_state, ability_id)
	if current_pose == profile.resolve_pose(IDLE):
		_pose_sprite.hide()
		figure.self_modulate = _idle_self_modulate
		return
	_pose_sprite.texture = current_pose.texture
	_pose_sprite.size = current_pose.rendered_size(reference_height)
	_pose_sprite.position = ground - CombatVisualPose.point_offset(current_pose.ground_anchor, _pose_sprite.size, figure.flip_h)
	_pose_sprite.self_modulate = _idle_self_modulate
	figure.self_modulate.a = 0.0
	_pose_sprite.show()


func reset() -> void:
	if not is_instance_valid(figure):
		return
	set_pose(IDLE)
	figure.position = home
	figure.scale = _idle_scale
	figure.modulate = _idle_modulate
	figure.z_index = _idle_z_index


func prepare_attack(target: BattleFigureAnimator, ability_id: String) -> void:
	figure.z_index = 2
	target.figure.z_index = 1
	set_pose(WIND_UP, ability_id)


func strike(target: BattleFigureAnimator, event: Dictionary, strike_scale: float) -> void:
	set_pose(STRIKE, str(event.get("ability_id", "")))
	if profile != null:
		figure.scale = _idle_scale * strike_scale
	if receives_hurt(event):
		target.set_pose(HURT)


func mark_defeated() -> void:
	_idle_modulate = DEFEATED_MODULATE
	reset()


static func receives_hurt(event: Dictionary) -> bool:
	return BattleImpactProfile.hp_damage(event) > 0


func pose_point_at_home(pose: CombatVisualPose, point: Vector2, scale_multiplier: float = 1.0) -> Vector2:
	if profile == null or pose == null:
		return home + figure.pivot_offset + (figure.size * point - figure.pivot_offset) * _idle_scale * scale_multiplier
	var pose_size: Vector2 = pose.rendered_size(reference_height)
	var offset: Vector2 = CombatVisualPose.point_offset(point, pose_size, figure.flip_h) - CombatVisualPose.point_offset(pose.ground_anchor, pose_size, figure.flip_h)
	return home + ground + offset * _idle_scale * scale_multiplier


func melee_contact(target: BattleFigureAnimator, event: Dictionary, choreography: BattleMeleeChoreography) -> Vector2:
	var attack_pose: CombatVisualPose = profile.resolve_pose(STRIKE, str(event.get("ability_id", "")))
	var hurt_state: StringName = HURT if receives_hurt(event) else IDLE
	var target_pose: CombatVisualPose = target.profile.resolve_pose(hurt_state) if target.profile != null else null
	var target_anchor: Vector2 = target_pose.hit_anchor if target_pose != null else Vector2(0.5, 0.5)
	var target_point: Vector2 = target.pose_point_at_home(target_pose, target_anchor)
	var weapon_point: Vector2 = pose_point_at_home(attack_pose, attack_pose.contact_anchor, choreography.strike_scale)
	var destination: Vector2 = home + target_point - weapon_point
	if BattleImpactProfile.is_miss(event):
		var direction: float = signf(target.home.x - home.x)
		destination.x -= direction * reference_height * choreography.dodge_gap_fraction
	return destination


func queue_melee(tween: Tween, target: BattleFigureAnimator, event: Dictionary,
		choreography: BattleMeleeChoreography, impact: Callable, hit_stop: float = 0.0,
		effect_advance: Callable = Callable(), effect_finish: Callable = Callable(), dodge_recoil: float = 0.0) -> bool:
	if profile == null or choreography == null:
		return false
	var pose: CombatVisualPose = profile.resolve_pose(STRIKE, str(event.get("ability_id", "")))
	if pose == null or not pose.has_contact_anchor():
		return false
	var contact: Vector2 = melee_contact(target, event, choreography)
	var direction: float = signf(target.home.x - home.x)
	var windup: Vector2 = home - Vector2(direction * reference_height * choreography.windup_fraction, 0.0)
	var approach: float = choreography.approach_duration(windup.distance_to(contact), reference_height)
	queue_attack(tween, target, event, contact, windup, choreography.windup_seconds,
		approach, choreography.contact_seconds + choreography.hold_seconds, choreography.recover_seconds,
		choreography.hurt_recoil_fraction, choreography.strike_scale, impact, choreography.contact_seconds, hit_stop, effect_advance, effect_finish, dodge_recoil)
	return true


func queue_attack(tween: Tween, target: BattleFigureAnimator, event: Dictionary,
		contact: Vector2, windup: Vector2, windup_seconds: float, approach_seconds: float,
		hold_seconds: float, recover_seconds: float, recoil_fraction: float, strike_scale: float,
		impact: Callable, contact_seconds: float = 0.09, hit_stop: float = 0.0,
		effect_advance: Callable = Callable(), effect_finish: Callable = Callable(), dodge_recoil: float = 0.0) -> void:
	tween.tween_callback(prepare_attack.bind(target, str(event.get("ability_id", ""))))
	tween.tween_property(figure, "position", windup, windup_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(figure, "position", contact, approach_seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_callback(strike.bind(target, event, strike_scale))
	tween.tween_callback(impact)
	if hit_stop > 0.0:
		if effect_advance.is_valid():
			tween.tween_method(effect_advance, 0.0, hit_stop, hit_stop).set_trans(Tween.TRANS_LINEAR)
		else:
			tween.tween_interval(hit_stop)
	tween.tween_interval(hold_seconds)
	var direction: Vector2 = (target.home - home).normalized()
	if target.profile != null and receives_hurt(event):
		var recoil: Vector2 = target.home + direction * target.figure.size.x * recoil_fraction
		tween.parallel().tween_property(target.figure, "position", recoil, minf(contact_seconds, hold_seconds))
	elif bool(event.get("dodged", false)) and dodge_recoil > 0.0:
		var evade: Vector2 = target.home + direction * target.figure.size.x * dodge_recoil
		tween.parallel().tween_property(target.figure, "position", evade, minf(contact_seconds, hold_seconds)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	if effect_advance.is_valid():
		tween.parallel().tween_method(effect_advance, hit_stop, hit_stop + hold_seconds, hold_seconds).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(set_pose.bind(IDLE, ""))
	tween.tween_property(figure, "position", home, recover_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(figure, "scale", _idle_scale, recover_seconds)
	tween.parallel().tween_property(target.figure, "position", target.home, recover_seconds)
	tween.parallel().tween_property(target.figure, "modulate", target._idle_modulate, recover_seconds)
	if effect_advance.is_valid():
		tween.parallel().tween_method(effect_advance, hit_stop + hold_seconds, hit_stop + hold_seconds + recover_seconds, recover_seconds).set_trans(Tween.TRANS_LINEAR)
	if effect_finish.is_valid():
		tween.tween_callback(effect_finish)
	tween.tween_callback(reset)
	tween.tween_callback(target.reset)


func visible_point(point: Vector2) -> Vector2:
	var local: Vector2
	if profile == null or current_pose == null:
		local = figure.size * point
	else:
		var pose_size: Vector2 = current_pose.rendered_size(reference_height)
		local = ground + CombatVisualPose.point_offset(point, pose_size, figure.flip_h) - CombatVisualPose.point_offset(current_pose.ground_anchor, pose_size, figure.flip_h)
	return figure.get_transform() * local

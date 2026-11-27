class_name AbilityIcon
extends TextureRect

enum State { NORMAL, INACTIVE, SPENT }

const LOCK_OVERLAY: Texture2D = preload("res://assets/ui/lock_overlay.png")

@onready var _background: TextureRect = $Background
@onready var _frame: TextureRect = $Frame
@onready var _lock_shade: ColorRect = $LockShade
@onready var _lock_overlay: TextureRect = $LockOverlay

var _state: State = State.NORMAL
var _locked: bool = false


func _ready() -> void:
	set_locked(_locked)


func configure(art: Texture2D, frame: Texture2D = null, background: Texture2D = null, state: State = State.NORMAL) -> void:
	texture = art
	_frame.texture = frame
	_background.texture = background
	_frame.visible = frame != null
	_background.visible = background != null
	visible = art != null or frame != null or background != null
	set_state(state)
	set_locked(false)


func configure_ability(ability: AbilityDefinition, actor: BattleParticipant = null, state: State = State.NORMAL) -> void:
	if ability == null:
		configure(null, null, null, state)
		return
	var style: AbilityIconStyle = AbilityIconCatalog.style_for_actor(actor)
	var frame: Texture2D = null
	var background: Texture2D = null
	if style != null:
		var monster: MonsterDefinition = MonsterCatalog.get_monster(actor.definition_id)
		frame = style.frame_for_rank(monster.rank)
		background = style.background
	configure(AbilityIconCatalog.art_for(ability), frame, background, state)


func set_state(state: State) -> void:
	_state = state
	match state:
		State.INACTIVE:
			modulate = Color(0.52, 0.54, 0.60)
		State.SPENT:
			modulate = Color(0.48, 0.48, 0.48)
		_:
			modulate = Color.WHITE


func set_locked(value: bool) -> void:
	_locked = value
	if _lock_overlay == null:
		return
	_lock_shade.visible = value
	_lock_overlay.texture = LOCK_OVERLAY
	_lock_overlay.visible = value
	_lock_overlay.modulate = Color(1.0, 1.0, 1.0, 0.88)
	var shade: Color = Color(0.40, 0.40, 0.40) if value else Color.WHITE
	self_modulate = shade
	_frame.self_modulate = shade
	_background.self_modulate = shade

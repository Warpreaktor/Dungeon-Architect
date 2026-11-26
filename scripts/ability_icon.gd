class_name AbilityIcon
extends TextureRect

enum State { NORMAL, INACTIVE, SPENT }

@onready var _background: TextureRect = $Background
@onready var _frame: TextureRect = $Frame

var _state: State = State.NORMAL


func configure(art: Texture2D, frame: Texture2D = null, background: Texture2D = null, state: State = State.NORMAL) -> void:
	texture = art
	_frame.texture = frame
	_background.texture = background
	_frame.visible = frame != null
	_background.visible = background != null
	visible = art != null or frame != null or background != null
	set_state(state)


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

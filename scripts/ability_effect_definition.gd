class_name AbilityEffectDefinition
extends Resource

## Описание результата приёма, но не его исполнение (DA-4.04).
enum Kind { DAMAGE, BLOCK, HEAL, APPLY_STATUS, REMOVE_STATUS, WAIT }
enum Recipient { SELF, TARGET }
enum Clock { LEGACY_HERO_PHASE, OWNER_PHASE, INCOMING_ATTACK }
enum Stack { REFRESH, ADD, ONCE }
enum Stat { NONE, DODGE_PERCENT, AGILITY, ACCURACY }


@export var kind: Kind = Kind.DAMAGE
@export var recipient: Recipient = Recipient.TARGET
@export_range(0, 9999, 1) var amount: int = 0
@export var status_id: String = ""
## Configurable damage rules. Only meaningful for DAMAGE.
@export_range(0.0, 10.0, 0.01) var damage_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.01) var first_slot_multiplier: float = 0.0
## Доля урона, проходящая сквозь активный блок и будущую броню.
@export_range(0.0, 1.0, 0.01) var armor_pierce_fraction: float = 0.0
@export_range(0.0, 10.0, 0.01) var vs_rest_multiplier: float = 0.0
@export_range(0.0, 10.0, 0.01) var vs_block_multiplier: float = 0.0
@export_range(1, 20, 1) var hit_count: int = 1
## APPLY_STATUS metadata: positive percentages, signed attribute changes.
@export var status_stat: Stat = Stat.NONE
@export var status_modifier: int = 0
@export var status_clock: Clock = Clock.LEGACY_HERO_PHASE
@export var stack_policy: Stack = Stack.REFRESH
@export var requires_unblocked_hit: bool = false
@export_range(0, 999, 1) var duration_ticks: int = 0


func validation_error() -> String:
	if amount < 0 or duration_ticks < 0 or hit_count <= 0 or damage_multiplier < 0.0:
		return "Отрицательные параметры эффекта"
	if kind < Kind.DAMAGE or kind > Kind.WAIT:
		return "Неизвестный тип эффекта"
	if recipient < Recipient.SELF or recipient > Recipient.TARGET:
		return "Некорректная цель эффекта"
	if kind in [Kind.APPLY_STATUS, Kind.REMOVE_STATUS] and status_id.strip_edges().is_empty():
		return "Для эффекта состояния нужен status_id"
	if kind == Kind.APPLY_STATUS and duration_ticks == 0:
		return "Эффект состояния должен иметь длительность"
	return ""

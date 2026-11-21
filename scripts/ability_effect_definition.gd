class_name AbilityEffectDefinition
extends Resource

## Данные эффекта отделены от алгоритма его исполнения.
enum Kind { DAMAGE, BLOCK, HEAL, APPLY_STATUS, REMOVE_STATUS, WAIT }
enum Recipient { SELF, TARGET }
enum Clock { LEGACY_HERO_PHASE, OWNER_PHASE, INCOMING_ATTACK }
enum Stack { REFRESH, ADD, ONCE }
enum Stat { NONE, DODGE_PERCENT, AGILITY, ACCURACY, ATTACK_POWER }


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
## Параметры боевых ресурсов выражены через проценты от динамической базы.
## Нулевое значение использует damage_multiplier, положительное задаёт долю базы.
@export_range(0, 1000, 1) var damage_scale_percent: int = 0
@export_range(0, 1000, 1) var bonus_vs_damaged_armor_percent: int = 0
## APPLY_STATUS metadata: positive percentages, signed attribute changes.
@export var status_stat: Stat = Stat.NONE
@export var status_modifier: int = 0
@export var status_clock: Clock = Clock.LEGACY_HERO_PHASE
@export var stack_policy: Stack = Stack.REFRESH
@export var requires_unblocked_hit: bool = false
@export_range(0, 999, 1) var duration_ticks: int = 0
## Периодический урон раз в собственный отдых владельца эффекта.
@export_range(0, 9999, 1) var tick_damage: int = 0
@export_range(0, 100, 1) var heal_percent_max: int = 0
@export_range(-100, 100, 1) var accuracy_offset_percent: int = 0
## Дебафф после атаки требует попадания (обычное попадание или через блок).
@export var requires_hit: bool = false
## Совместимость ресурсов стартовых способностей Волчи.
@export var modifier_kind: Stat = Stat.NONE
@export var stack_mode: Stack = Stack.REFRESH
@export var expires_on_incoming_attack: bool = false


func effective_damage_multiplier() -> float:
	return float(damage_scale_percent) / 100.0 if damage_scale_percent > 0 else damage_multiplier


func effective_status_stat() -> int:
	return modifier_kind if modifier_kind != Stat.NONE else status_stat


func effective_status_modifier() -> int:
	if status_modifier != 0:
		return status_modifier
	return amount if effective_status_stat() != Stat.NONE else 0


func effective_status_clock() -> int:
	return Clock.INCOMING_ATTACK if expires_on_incoming_attack else status_clock


func effective_stack_policy() -> int:
	return stack_policy if stack_policy != Stack.REFRESH else stack_mode


func status_duration_description() -> String:
	if effective_status_clock() == Clock.INCOMING_ATTACK:
		return "до следующей входящей атаки" if duration_ticks == 1 else "на %s" % DescriptionTemplate.quantity(duration_ticks, "входящую атаку", "входящие атаки", "входящих атак")
	return "на %s" % DescriptionTemplate.phases(duration_ticks)


func stack_description() -> String:
	match effective_stack_policy():
		Stack.ADD:
			return "Повторные применения складываются."
		Stack.ONCE:
			return "Одинаковые эффекты не складываются."
		_:
			return "Повтор обновляет длительность."


func validation_error() -> String:
	if amount < 0 or duration_ticks < 0 or hit_count <= 0 or damage_multiplier < 0.0 or tick_damage < 0:
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

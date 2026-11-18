class_name AbilityEffectDefinition
extends Resource

## Описание результата приёма, но не его исполнение (DA-4.04).
enum Kind { DAMAGE, BLOCK, HEAL, APPLY_STATUS, REMOVE_STATUS, WAIT }
enum Recipient { SELF, TARGET }

@export var kind: Kind = Kind.DAMAGE
@export var recipient: Recipient = Recipient.TARGET
@export_range(0, 9999, 1) var amount: int = 0
@export var status_id: String = ""
@export_range(0, 999, 1) var duration_ticks: int = 0


func validation_error() -> String:
	if amount < 0 or duration_ticks < 0:
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

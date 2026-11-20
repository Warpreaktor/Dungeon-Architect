class_name BattleFlow
extends RefCounted

## Единственный источник разрешений на переходы между состояниями.
## UI не изменяет состояние напрямую; исполнение одного такта принадлежит BattleState.
enum Stage { PREPARATION, EXECUTING, BETWEEN_PHASES, RECONFIGURING, FINISHED }

var stage: Stage = Stage.PREPARATION
var phase_number: int = 0
var completed_ticks: int = 0
var reconfiguration_tokens: int = 0
var _half_health_token_granted: bool = false


func start_phase() -> bool:
	if stage != Stage.PREPARATION and stage != Stage.BETWEEN_PHASES and stage != Stage.RECONFIGURING:
		return false
	stage = Stage.EXECUTING
	phase_number += 1
	completed_ticks = 0
	return true


func can_execute() -> bool:
	return stage == Stage.EXECUTING


func mark_tick() -> bool:
	if not can_execute():
		return false
	completed_ticks += 1
	return true


func complete_phase() -> bool:
	if not can_execute():
		return false
	stage = Stage.BETWEEN_PHASES
	return true


func finish_battle() -> bool:
	if stage == Stage.FINISHED:
		return false
	stage = Stage.FINISHED
	return true


func can_use_item() -> bool:
	return stage == Stage.BETWEEN_PHASES


func grant_half_health_reconfiguration(current_hp: int, maximum_hp: int) -> void:
	# Дополнительная перенастройка выдаётся при первом достижении порога HP.
	if not _half_health_token_granted and maximum_hp > 0 and current_hp > 0 and current_hp * 2 < maximum_hp:
		_half_health_token_granted = true
		reconfiguration_tokens += 1


## После любой завершённой фазы можно менять тактику
## бесплатно. Система жетонов сохранена для будущих испытаний баланса.
func request_reconfiguration() -> bool:
	if stage != Stage.BETWEEN_PHASES:
		return false
	stage = Stage.RECONFIGURING
	return true


func confirm_reconfiguration() -> bool:
	if stage != Stage.RECONFIGURING:
		return false
	stage = Stage.BETWEEN_PHASES
	return true


func cancel_reconfiguration() -> bool:
	if stage != Stage.RECONFIGURING:
		return false
	stage = Stage.BETWEEN_PHASES
	return true

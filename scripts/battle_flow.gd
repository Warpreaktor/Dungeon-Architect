class_name BattleFlow
extends RefCounted

## Единственный источник разрешений на переходы между состояниями.
## UI не изменяет состояние напрямую; исполнение одного такта принадлежит BattleState.
enum Stage { PREPARATION, EXECUTING, BETWEEN_PHASES, FINISHED }

var stage: Stage = Stage.PREPARATION
var phase_number: int = 0
var completed_ticks: int = 0


func start_phase() -> bool:
	if stage != Stage.PREPARATION and stage != Stage.BETWEEN_PHASES:
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
	return stage in [Stage.PREPARATION, Stage.BETWEEN_PHASES]

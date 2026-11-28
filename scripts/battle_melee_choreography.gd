class_name BattleMeleeChoreography
extends Resource

@export_range(0.0, 2.0, 0.01) var windup_seconds: float = 0.18
@export_range(0.0, 2.0, 0.01) var approach_seconds: float = 0.12
@export_range(0.0, 2.0, 0.01) var max_approach_seconds: float = 0.24
@export_range(0.0, 2.0, 0.01) var contact_seconds: float = 0.08
@export_range(0.0, 2.0, 0.01) var hold_seconds: float = 0.20
@export_range(0.0, 2.0, 0.01) var recover_seconds: float = 0.22
@export_range(0.0, 1.0, 0.01) var windup_fraction: float = 0.15
@export_range(0.0, 0.5, 0.01) var hurt_recoil_fraction: float = 0.06
@export_range(1.0, 1.2, 0.01) var strike_scale: float = 1.03
@export_range(0.0, 0.5, 0.01) var dodge_gap_fraction: float = 0.12
@export_range(0.1, 5.0, 0.1) var approach_distance_in_heights: float = 2.0


func approach_duration(distance: float, reference_height: float) -> float:
	var factor: float = maxf(1.0, distance / maxf(reference_height * approach_distance_in_heights, 1.0))
	return minf(approach_seconds * factor, maxf(approach_seconds, max_approach_seconds))

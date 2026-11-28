class_name BattleImpactProfile
extends Resource

@export var slash_enabled: bool = true
@export var slash_color: Color = Color("ffc177")
@export var hit_color: Color = Color("ffbb72")
@export var block_color: Color = Color("80d9ff")
@export_range(0.0, 0.5, 0.005) var hit_stop_seconds: float = 0.055
@export_range(0.01, 1.0, 0.01) var effect_seconds: float = 0.24
@export_range(0.0, 0.5, 0.01) var radius_fraction: float = 0.23
@export_range(0, 64, 1) var particle_count: int = 12
@export_range(0.0, 0.1, 0.001) var shake_fraction: float = 0.012
@export var hit_sound: AudioStream
@export var block_sound: AudioStream
@export var swing_sound: AudioStream
@export_range(-40.0, 6.0, 0.5) var sound_volume_db: float = -8.0


static func is_miss(event: Dictionary) -> bool:
	return bool(event.get("dodged", false)) or bool(event.get("missed", false))


static func is_block(event: Dictionary) -> bool:
	return int(event.get("block_absorbed", event.get("shield_blocked", 0))) > 0


func contact_pause(event: Dictionary) -> float:
	return 0.0 if is_miss(event) else hit_stop_seconds


func sound_for(event: Dictionary) -> AudioStream:
	if is_miss(event):
		return swing_sound
	if is_block(event):
		return block_sound
	return hit_sound

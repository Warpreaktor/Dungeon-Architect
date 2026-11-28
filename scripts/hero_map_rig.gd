class_name HeroMapRig
extends Node2D

@export var render_size: Vector2i = Vector2i(256, 256)
@onready var skeleton: Skeleton2D = $Skeleton2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func start_walk(direction: Vector2, duration: float) -> void:
	if not is_node_ready():
		return
	if not is_zero_approx(direction.x):
		var horizontal := -1.0 if direction.x < 0.0 else 1.0
		skeleton.transform = Transform2D(Vector2(horizontal, 0.0), Vector2.DOWN, skeleton.position)
	if animation_player.has_animation(&"walk"):
		var cycle := animation_player.get_animation(&"walk").length
		animation_player.play(&"walk", -1.0, cycle / maxf(duration, 0.001))
		animation_player.seek(0.0, true)


func stop_walk() -> void:
	if is_node_ready() and animation_player.has_animation(&"idle") and animation_player.current_animation != &"idle":
		animation_player.play(&"idle")

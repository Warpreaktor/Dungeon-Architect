@tool
extends EditorPlugin

var panel: Control


func _enter_tree() -> void:
    panel = preload("res://addons/dungeon_tests/test_panel.gd").new()
    add_control_to_bottom_panel(panel, "Тесты")


func _exit_tree() -> void:
    if panel != null:
        remove_control_from_bottom_panel(panel)
        panel.queue_free()

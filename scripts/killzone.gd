extends Area2D

@onready var timer = $Timer

func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return

	if not body.is_in_group("player"):
		return

	if body.has_method("die"):
		body.die()


func _on_timer_timeout() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

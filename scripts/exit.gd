extends Area2D

signal world_changed(world_name)

var entered = false

@export var world_name: String = "world"

func _process(delta: float) -> void:
	if entered == true:
		if Input.is_action_just_pressed("enterkey"):
			emit_signal("world_changed", world_name)
			print("entered")

func _on_exit_erea_body_entered(body: PhysicsBody2D) -> void:
	entered == true

func _on_exit_erea_body_exited(body: PhysicsBody2D) -> void:
	entered == false

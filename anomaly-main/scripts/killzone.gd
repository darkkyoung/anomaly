extends Area2D

@onready var timer = $Timer 
@export var damage := 1

func _on_body_entered(body:Node2D):
	if body.has_node("Health"):
		body.get_node("Health").take_damage(damage)

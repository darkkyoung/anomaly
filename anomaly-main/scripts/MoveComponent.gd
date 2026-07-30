class_name MoveComponent
extends Node

@export var gravity : float = 980.0
@export var push_speed : float = 80.0

@onready var parent : CharacterBody2D = get_parent()

@onready var push_left : RayCast2D = $PushLeft
@onready var push_right : RayCast2D = $PushRight


func _physics_process(delta):

	apply_gravity(delta)

	push_box()

	parent.move_and_slide()


func apply_gravity(delta):

	if !parent.is_on_floor():
		parent.velocity.y += gravity * delta
	else:
		parent.velocity.y = 0


func push_box():

	parent.velocity.x = 0

	if !is_player_pushing():
		return

	var direction = Input.get_axis("move_left", "move_right")

	parent.velocity.x = direction * push_speed


func get_push_direction() -> float:

	if push_left.is_colliding():
		return 1

	if push_right.is_colliding():
		return -1

	return 0


func get_player():

	for ray in [push_left,push_right]:

		if ray.is_colliding():

			var collider = ray.get_collider()

			if collider != null and collider.is_in_group("player"):
				return collider

	return null

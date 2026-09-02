extends RigidBody2D

@export var max_hp := 3

var current_hp := 3
var is_dead := false

func _ready():
	current_hp = max_hp
	add_to_group("pushable")
	add_to_group("objects")

func take_damage(
	damage:int,
	knockback_direction:int = 0,
	knockback_power:float = 200
):

	if is_dead:
		return
	current_hp -= damage
	print("Box HP :", current_hp)
	# 공격 맞으면 약간 밀림
	if knockback_direction != 0:
		apply_impulse(Vector2(knockback_direction * knockback_power,0))
	if current_hp <= 0:
		die()


func die():
	is_dead = true
	queue_free()

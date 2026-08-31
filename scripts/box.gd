extends RigidBody2D


@export var max_hp: int = 5

const ATTACK_IMPULSE_MULTIPLIER: float = 0.25

var current_hp: int
var is_destroyed: bool = false


func _ready() -> void:
	current_hp = max_hp
	add_to_group("pushable")


func take_damage(
	amount: int,
	knockback_direction: int = 0,
	knockback_power: float = 180.0
) -> void:
	if is_destroyed:
		return

	current_hp -= amount
	current_hp = max(current_hp, 0)

	print("Box HP: ", current_hp, "/", max_hp)

	if knockback_direction != 0:
		var impulse_x := (
			knockback_direction
			* knockback_power
			* ATTACK_IMPULSE_MULTIPLIER
		)

		apply_central_impulse(Vector2(impulse_x, 0.0))

	if current_hp <= 0:
		destroy()


func destroy() -> void:
	if is_destroyed:
		return

	is_destroyed = true
	queue_free()

extends Node2D

const SPEED = 60
const KNOCKBACK_FRICTION = 700.0

@export var max_hp: int = 3

var current_hp: int
var direction = 1
var is_dead: bool = false
var hit_anim_id: int = 0
var knockback_velocity: float = 0.0

@onready var ray_cast_right = $RayCastRight
@onready var ray_cast_left = $RayCastLeft
@onready var animated_sprite = $AnimatedSprite2D


func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemy")


func _process(delta: float) -> void:
	if is_dead:
		return

	if ray_cast_right.is_colliding():
		direction = -1
		animated_sprite.flip_h = true

	if ray_cast_left.is_colliding():
		direction = 1
		animated_sprite.flip_h = false

	# 기본 이동 + 넉백 이동
	position.x += direction * SPEED * delta
	position.x += knockback_velocity * delta

	# 넉백 속도를 점점 0으로 줄임
	knockback_velocity = move_toward(knockback_velocity, 5.0, KNOCKBACK_FRICTION * delta)


func take_damage(damage: int, knockback_direction: int = 0, knockback_power: float = 180.0) -> void:
	if is_dead:
		return

	current_hp -= damage
	print("Slime HP: ", current_hp, "/", max_hp)

	# 넉백 적용
	if knockback_direction != 0:
		knockback_velocity = knockback_direction * knockback_power

	if current_hp <= 0:
		die()
	else:
		play_hit_animation()


func play_hit_animation() -> void:
	hit_anim_id += 1
	var this_hit_id = hit_anim_id

	if animated_sprite.sprite_frames.has_animation("slime_hit"):
		animated_sprite.play("slime_hit")
	else:
		print("slime_hit animation not found")

	await get_tree().create_timer(.7).timeout

	if is_dead:
		return

	if this_hit_id != hit_anim_id:
		return

	if animated_sprite.sprite_frames.has_animation("default"):
		animated_sprite.play("default")


func die() -> void:
	is_dead = true
	print("Slime died")
	queue_free()

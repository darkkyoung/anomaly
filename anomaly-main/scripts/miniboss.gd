extends Node2D

const SPEED = 60
const KNOCKBACK_FRICTION = 700.0

# 체력 설정
@export var max_hp: int = 3

#아이템 드랍 설정
@export var coin_scene: PackedScene
@export var drop_count: int = 1

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

#피격 애니메이션
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
	#'드랍코인' 실행
	drop_coin()
	queue_free()

#죽으면 아이템 드랍
func drop_coin():
	if coin_scene == null:
		return
	for i in range(drop_count):
		var coin = coin_scene.instantiate()
		get_parent().add_child(coin)
		# 슬라임 위치에 생성
		coin.global_position = global_position
		# 여러 개 드랍 시 약간 퍼뜨리기
		coin.global_position += Vector2(randf_range(-8, 8), randf_range(-4, 4))

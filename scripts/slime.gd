extends CharacterBody2D

const SPEED: float = 85.0
const GRAVITY_MULTIPLIER: float = 1.0

const KNOCKBACK_FRICTION: float = 700.0

const ATTACK_DAMAGE: int = 1
const ATTACK_COOLDOWN: float = 0.8
const ATTACK_PAUSE_TIME: float = 0.25
const PLAYER_KNOCKBACK_POWER: float = 280.0

@export var max_hp: int = 3

var current_hp: int
var direction: int = 1
var is_dead: bool = false
var is_attacking: bool = false
var can_attack: bool = true
var hit_anim_id: int = 0
var knockback_velocity: float = 0.0

var target_player: Node = null
var player: Node = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_damage_area: Area2D = $PlayerDamageArea
@onready var player_damage_shape: CollisionShape2D = $PlayerDamageArea/CollisionShape2D


func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemy")

	player = get_tree().get_first_node_in_group("player")

	player_damage_area.monitoring = true
	player_damage_shape.disabled = false


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 중력 적용
	if not is_on_floor():
		velocity += get_gravity() * GRAVITY_MULTIPLIER * delta

	# 피격 넉백 처리
	if abs(knockback_velocity) > 1.0:
		velocity.x = knockback_velocity
		knockback_velocity = move_toward(knockback_velocity, 0.0, KNOCKBACK_FRICTION * delta)
		move_and_slide()
		return

	# 공격 중에는 잠깐 정지
	if is_attacking:
		velocity.x = 0.0
		move_and_slide()
		return

	chase_player()

	move_and_slide()


func chase_player() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		velocity.x = 0.0
		return

	var x_diff: float = player.global_position.x - global_position.x

	if abs(x_diff) < 4.0:
		velocity.x = 0.0
		return

	direction = sign(x_diff)

	velocity.x = direction * SPEED

	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

	if animated_sprite.sprite_frames.has_animation("default"):
		if animated_sprite.animation != "default":
			animated_sprite.play("default")


func take_damage(amount: int, knockback_direction: int = 0, knockback_power: float = 180.0) -> void:
	if is_dead:
		return

	current_hp -= amount
	current_hp = max(current_hp, 0)

	print("Slime HP: ", current_hp, "/", max_hp)

	if knockback_direction != 0:
		knockback_velocity = knockback_direction * knockback_power

	if current_hp <= 0:
		die()
		return

	play_hit_animation()


func play_hit_animation() -> void:
	hit_anim_id += 1
	var this_hit_id = hit_anim_id

	if animated_sprite.sprite_frames.has_animation("slime_hit"):
		animated_sprite.play("slime_hit")
	else:
		print("slime_hit animation not found")

	await get_tree().create_timer(0.25).timeout

	if is_dead:
		return

	if this_hit_id != hit_anim_id:
		return

	if animated_sprite.sprite_frames.has_animation("default"):
		animated_sprite.play("default")


func damage_player(player_body: Node) -> void:
	if is_dead:
		return

	if not can_attack:
		return

	if player_body == null:
		return

	if not is_instance_valid(player_body):
		return

	if not player_body.has_method("take_damage"):
		return

	can_attack = false
	is_attacking = true
	velocity.x = 0.0

	if animated_sprite.sprite_frames.has_animation("slime_attack"):
		animated_sprite.play("slime_attack")

	var knockback_direction: int = sign(player_body.global_position.x - global_position.x)

	if knockback_direction == 0:
		knockback_direction = direction

	player_body.take_damage(ATTACK_DAMAGE, knockback_direction, PLAYER_KNOCKBACK_POWER)

	# 플레이어가 죽어서 씬이 재시작되는 순간, 이 슬라임도 트리에서 빠질 수 있다.
	# 그러면 아래에서 get_tree().create_timer()를 호출하면 오류가 난다.
	if not is_inside_tree():
		return

	var tree := get_tree()
	if tree == null:
		return

	await tree.create_timer(ATTACK_PAUSE_TIME).timeout

	if not is_inside_tree():
		return

	is_attacking = false

	var remaining_cooldown: float = max(ATTACK_COOLDOWN - ATTACK_PAUSE_TIME, 0.0)

	tree = get_tree()
	if tree == null:
		return

	await tree.create_timer(remaining_cooldown).timeout

	if not is_inside_tree():
		return

	can_attack = true

	if target_player != null and is_instance_valid(target_player):
		damage_player(target_player)

func die() -> void:
	if is_dead:
		return

	is_dead = true
	print("Slime died")
	queue_free()

func _on_player_damage_area_body_entered(body: Node2D) -> void:
	if body == null:
		return

	if not is_instance_valid(body):
		return

	if body.is_in_group("player"):
		target_player = body
		damage_player(target_player)


func _on_player_damage_area_body_exited(body: Node2D) -> void:
	if target_player != null and body == target_player:
		target_player = null

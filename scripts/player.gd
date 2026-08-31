extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D

@onready var attack_area = $AttackArea
@onready var attack_shape = $AttackArea/CollisionShape2D

@onready var player_hp_bar: ProgressBar = $"../UI/PlayerHPBar"

const ATTACK_DAMAGE = 1
const ATTACK_TIME = 0.5

const LADDER_SPEED: float = 85.0
const LADDER_SNAP_SPEED: float = 180.0

const DEATH_RESTART_DELAY: float = 0.6

const MAX_HP: int = 20
const INVINCIBLE_TIME: float = 0.8
const PLAYER_KNOCKBACK_FRICTION: float = 900.0

const SPEED = 125.0
const JUMP_VELOCITY = -300.0

const BOX_PUSH_SPEED: float = 55.0

const STOMP_DAMAGE: int = 1
const STOMP_BOUNCE_VELOCITY: float = -220.0

var current_ladder: Area2D = null
var is_climbing: bool = false

var is_attacking: bool = false
var already_hit_enemies: Array = []
var facing_direction: int = 1
var attack_has_hit: bool = false
var is_dead: bool = false

var hp: int = MAX_HP
var is_invincible: bool = false
var knockback_velocity: float = 0.0

func _ready() -> void:
	add_to_group("player")

	attack_area.monitoring = false
	attack_shape.disabled = true
	
	player_hp_bar.min_value = 0
	player_hp_bar.max_value = MAX_HP
	player_hp_bar.value = hp

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return
		
	var climb_direction: float = Input.get_axis(
		"climb_up",
		"climb_down"
	)

	var ladder_available: bool = (
		current_ladder != null
		and is_instance_valid(current_ladder)
	)

	# 사다리 영역에서 위/아래 입력을 하면 사다리 타기 시작
	if ladder_available and climb_direction != 0.0:
		is_climbing = true

	# 사다리를 벗어나면 일반 상태로 복귀
	if not ladder_available:
		is_climbing = false

	# 사다리를 타는 동안에는 중력과 일반 이동을 처리하지 않음
	if is_climbing:
		velocity.y = climb_direction * LADDER_SPEED
		velocity.x = 0.0

		global_position.x = move_toward(
			global_position.x,
			current_ladder.global_position.x,
			LADDER_SNAP_SPEED * delta
		)

		if not is_attacking:
			animated_sprite.play("idle")

		move_and_slide()
		return

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# Attack
	if not is_attacking:
		if Input.is_action_just_pressed("attack_left"):
			facing_direction = -1
			attack(Vector2.LEFT)
		elif Input.is_action_just_pressed("attack_right"):
			facing_direction = 1
			attack(Vector2.RIGHT)
		elif Input.is_action_just_pressed("attack_up"):
			attack(Vector2.UP)
		elif Input.is_action_just_pressed("attack_down"):
			attack(Vector2.DOWN)

	# Get the input direction: -1, 0, 1
	var direction := Input.get_axis("move_left", "move_right")
	
	# Flip the sprite
	if not is_attacking:
		if direction > 0:
			facing_direction = 1
			animated_sprite.flip_h = false
		elif direction < 0:
			facing_direction = -1
			animated_sprite.flip_h = true
		
	# Play Animation
	if not is_attacking:
		if is_on_floor():
			if direction == 0:
				animated_sprite.play("idle")
			else:
				animated_sprite.play("run")
		else:
			animated_sprite.play("jump")

	# Attack hit timing
	if is_attacking and animated_sprite.animation == "attack1":
		if animated_sprite.frame == 3 and not attack_has_hit:
			apply_attack_damage()
			attack_has_hit = true

	if abs(knockback_velocity) > 1.0:
		velocity.x = knockback_velocity
		knockback_velocity = move_toward(knockback_velocity, 0.0, PLAYER_KNOCKBACK_FRICTION * delta)
	elif is_attacking:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
	elif direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	var fall_speed_before_move: float = velocity.y

	move_and_slide()

	push_boxes(direction)
	check_stomp_collisions(fall_speed_before_move)
	
func enter_ladder(ladder: Area2D) -> void:
	current_ladder = ladder


func exit_ladder(ladder: Area2D) -> void:
	if current_ladder != ladder:
		return

	current_ladder = null
	is_climbing = false

func push_boxes(input_direction: float) -> void:
	if input_direction == 0.0:
		return

	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)

		if collision == null:
			continue

		var collider: Object = collision.get_collider()

		if collider == null:
			continue

		if not (collider is RigidBody2D):
			continue

		var box := collider as RigidBody2D

		if not box.is_in_group("pushable"):
			continue

		var normal: Vector2 = collision.get_normal()

		# 박스 윗면/아랫면이 아니라 좌우 면에 부딪쳤을 때만
		if abs(normal.x) < 0.7:
			continue

		var push_direction: float

		if input_direction > 0.0:
			push_direction = 1.0
		else:
			push_direction = -1.0

		# 플레이어가 실제로 박스 방향으로 밀고 있는지 검사
		if push_direction > 0.0 and normal.x >= 0.0:
			continue

		if push_direction < 0.0 and normal.x <= 0.0:
			continue

		box.sleeping = false
		box.linear_velocity.x = push_direction * BOX_PUSH_SPEED

		print("PUSH BOX: ", box.name)

func check_stomp_collisions(fall_speed_before_move: float) -> void:
	# 위로 올라가는 중이거나 정지 상태면 밟기 판정 없음
	if fall_speed_before_move <= 0.0:
		return

	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)

		if collision == null:
			continue

		var collider := collision.get_collider()

		if collider == null:
			continue

		if not collider.is_in_group("enemy"):
			continue

		if not collider.has_method("take_damage"):
			continue

		var normal := collision.get_normal()

		# 적의 윗면에 닿은 경우만 인정
		if normal.y > -0.5:
			continue

		# 플레이어가 실제로 적보다 위에 있는지도 한 번 더 확인
		if global_position.y >= collider.global_position.y:
			continue

		collider.take_damage(
			STOMP_DAMAGE,
			0,
			0.0
		)

		velocity.y = STOMP_BOUNCE_VELOCITY

		print("STOMP: ", collider.name)

		break;

func attack(attack_direction: Vector2) -> void:
	is_attacking = true
	attack_has_hit = false
	already_hit_enemies.clear()

	if attack_direction == Vector2.LEFT:
		facing_direction = -1
		animated_sprite.flip_h = true
		animated_sprite.play("attack1")
	elif attack_direction == Vector2.RIGHT:
		facing_direction = 1
		animated_sprite.flip_h = false
		animated_sprite.play("attack1")
	else:
		animated_sprite.play("attack1")

	update_attack_area_position(attack_direction)

	attack_area.monitoring = false
	attack_shape.disabled = false

	await get_tree().physics_frame

	for area in attack_area.get_overlapping_areas():
		var enemy = area.get_parent()

		if enemy == null:
			continue

		if already_hit_enemies.has(enemy):
			continue

		if enemy.has_method("take_damage"):
			var knockback_direction = sign(enemy.global_position.x - global_position.x)

			if knockback_direction == 0:
				knockback_direction = 1

			enemy.take_damage(ATTACK_DAMAGE, knockback_direction, 180.0)
			already_hit_enemies.append(enemy)

	await get_tree().create_timer(ATTACK_TIME).timeout

	attack_area.monitoring = false
	attack_shape.disabled = true
	is_attacking = false

func apply_attack_damage() -> void:
	attack_area.monitoring = true
	attack_shape.disabled = false

	await get_tree().physics_frame

	for area in attack_area.get_overlapping_areas():
		var enemy = area.get_parent()

		if enemy == null:
			continue

		if already_hit_enemies.has(enemy):
			continue

		if enemy.has_method("take_damage"):
			var knockback_direction = sign(enemy.global_position.x - global_position.x)

			if knockback_direction == 0:
				knockback_direction = facing_direction

			enemy.take_damage(ATTACK_DAMAGE, knockback_direction, 180.0)
			already_hit_enemies.append(enemy)

	attack_area.monitoring = false
	attack_shape.disabled = true

func update_attack_area_position(attack_direction: Vector2) -> void:
	var attack_distance = 28

	if attack_direction == Vector2.LEFT:
		attack_area.position = Vector2(-attack_distance, 0)
	elif attack_direction == Vector2.RIGHT:
		attack_area.position = Vector2(attack_distance, 0)
	elif attack_direction == Vector2.UP:
		attack_area.position = Vector2(0, -attack_distance)
	elif attack_direction == Vector2.DOWN:
		attack_area.position = Vector2(0, attack_distance)

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "attack1":
		is_attacking = false
		attack_has_hit = false
		attack_area.monitoring = false
		attack_shape.disabled = true
		animated_sprite.play("idle")

func take_damage(
	amount: int,
	knockback_direction: int = 0,
	knockback_power: float = 260.0,
	launch_power: float = 120.0
) -> void:
	if hp <= 0:
		return

	if is_invincible:
		return

	hp -= amount
	hp = max(hp, 0)
	player_hp_bar.value = hp

	print("Player HP: ", hp, "/", MAX_HP)

	if knockback_direction != 0:
		knockback_velocity = knockback_direction * 0.5 * knockback_power
		velocity.y = min(velocity.y, -launch_power)

	if hp <= 0:
		die()
		return

	start_invincibility()

func start_invincibility() -> void:
	is_invincible = true
	animated_sprite.modulate = Color(1.0, 0.5, 0.5, 1.0)

	await get_tree().create_timer(INVINCIBLE_TIME).timeout

	is_invincible = false
	animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func die() -> void:
	if is_dead:
		return

	is_dead = true
	hp = 0
	player_hp_bar.value = hp

	velocity = Vector2.ZERO
	knockback_velocity = 0.0

	print("Player died")

	await get_tree().create_timer(DEATH_RESTART_DELAY).timeout

	if not is_inside_tree():
		return

	get_tree().reload_current_scene()

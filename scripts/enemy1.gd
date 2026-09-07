extends CharacterBody2D

enum EnemyMode {
	PATROL,
	COMBAT,
	CINEMATIC_DEFEND
}

enum PatrolAction {
	MOVE_LEFT,
	MOVE_RIGHT,
	STOP,
	STOP_TURN
}

const SPEED: float = 85.0
const GRAVITY_MULTIPLIER: float = 1.0

const KNOCKBACK_FRICTION: float = 700.0

const ATTACK_DAMAGE: int = 1
const ATTACK_COOLDOWN: float = 0.8
const ATTACK_PAUSE_TIME: float = 0.25
const PLAYER_KNOCKBACK_POWER: float = 280.0

const MELEE_RANGE_X: float = 28.0
const MELEE_RANGE_Y: float = 28.0

const MELEE_RANGE: float = 35.0
const DASH_RANGE: float = 150.0

const DASH_SPEED: float = 200.0
const DASH_CHARGE_TIME: float = 0.25
const DASH_TIME: float = 0.22
const DASH_COOLDOWN: float = 1.4
const DASH_LAUNCH_POWER: float = 260.0

const DETECTION_RANGE_X: float = 220.0
const DETECTION_RANGE_Y: float = 100.0

const PATROL_SPEED: float = 35.0

const PATROL_ACTION_TIME_MIN: float = 0.7
const PATROL_ACTION_TIME_MAX: float = 2.0

@export var max_hp: int = 3

@export var start_in_patrol: bool = false

@export var patrol_left_distance: float = 80.0
@export var patrol_right_distance: float = 80.0

var current_hp: int
var direction: int = 1
var is_dead: bool = false
var is_attacking: bool = false
var is_dashing: bool = false
var can_attack: bool = true
var can_dash: bool = true
var dash_direction: int = 1
var dash_has_hit: bool = false
var hit_anim_id: int = 0
var knockback_velocity: float = 0.0

var target_player: Node = null
var player: Node = null

var enemy_mode: EnemyMode = EnemyMode.COMBAT

var patrol_origin_x: float = 0.0
var patrol_timer: float = 0.0

var patrol_action: PatrolAction = PatrolAction.STOP
var patrol_facing: int = 1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_damage_area: Area2D = $PlayerDamageArea
@onready var player_damage_shape: CollisionShape2D = $PlayerDamageArea/CollisionShape2D


func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemy")

	player = get_tree().get_first_node_in_group("player")

	patrol_origin_x = global_position.x

	if start_in_patrol:
		enemy_mode = EnemyMode.PATROL
		patrol_facing = direction
		choose_next_patrol_action()
	else:
		enemy_mode = EnemyMode.COMBAT
		animated_sprite.play("idle")

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

	# dash 중이면 빠르게 전진
	if is_dashing:
		velocity.x = dash_direction * DASH_SPEED
		move_and_slide()
		return

	# 일반 공격 준비/후딜 중에는 정지
	if is_attacking:
		velocity.x = 0.0
		move_and_slide()
		return

	match enemy_mode:
		EnemyMode.PATROL:
			process_patrol(delta)

		EnemyMode.COMBAT:
			decide_action()

		EnemyMode.CINEMATIC_DEFEND:
			velocity.x = 0.0

	move_and_slide()
	
	if enemy_mode == EnemyMode.PATROL:
		if (
			patrol_action == PatrolAction.MOVE_LEFT
			or patrol_action == PatrolAction.MOVE_RIGHT
		):
			if is_on_wall():
				start_patrol_turn(-patrol_facing)


func decide_action() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		velocity.x = 0.0
		return

	if not is_instance_valid(player):
		player = null
		velocity.x = 0.0
		return

	var diff: Vector2 = player.global_position - global_position
	var distance_x: float = abs(diff.x)
	var distance_y: float = abs(diff.y)

	# 인지 범위 밖이면 아무 행동 안 함
	if distance_x > DETECTION_RANGE_X or distance_y > DETECTION_RANGE_Y:
		velocity.x = 0.0

		if animated_sprite.sprite_frames.has_animation("idle"):
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")

		return

	# 방향 결정
	# 완전히 겹친 상태에서는 sign(0)이 0이 되므로 기존 direction 유지
	if abs(diff.x) > 2.0:
		direction = int(sign(diff.x))

	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

	# 1. 아주 가까우면 일반 근접 공격
	# 중요: distance_x가 0이어도 여기로 들어와야 함
	if distance_x <= MELEE_RANGE_X and distance_y <= MELEE_RANGE_Y and can_attack:
		target_player = player
		damage_player(target_player)
		return

	# 2. 중간 거리면 dash 공격
	if distance_x > MELEE_RANGE_X and distance_x <= DASH_RANGE and distance_y <= 45.0 and can_dash:
		target_player = player
		start_dash_attack(target_player)
		return

	# 3. 너무 가까운데 쿨타임 중이면 제자리 정지
	if distance_x <= MELEE_RANGE:
		velocity.x = 0.0
		return

	# 4. 인식 범위 안이지만 공격 거리 밖이면 걸어서 접근
	velocity.x = direction * SPEED

	if animated_sprite.sprite_frames.has_animation("idle"):
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")


func process_patrol(delta: float) -> void:
	var left_limit: float = patrol_origin_x - patrol_left_distance
	var right_limit: float = patrol_origin_x + patrol_right_distance

	patrol_timer -= delta

	# 현재 행동 시간이 끝나면 새로운 행동 랜덤 선택
	if patrol_timer <= 0.0:
		choose_next_patrol_action()

	match patrol_action:
		PatrolAction.MOVE_LEFT:
			# 왼쪽 Patrol 한계에 도달
			if global_position.x <= left_limit:
				global_position.x = left_limit
				start_patrol_turn(1)
				return

			patrol_facing = -1
			apply_patrol_facing()
			velocity.x = -PATROL_SPEED


		PatrolAction.MOVE_RIGHT:
			# 오른쪽 Patrol 한계에 도달
			if global_position.x >= right_limit:
				global_position.x = right_limit
				start_patrol_turn(-1)
				return

			patrol_facing = 1
			apply_patrol_facing()
			velocity.x = PATROL_SPEED


		PatrolAction.STOP:
			velocity.x = 0.0


		PatrolAction.STOP_TURN:
			velocity.x = 0.0


func choose_next_patrol_action() -> void:
	var left_limit: float = patrol_origin_x - patrol_left_distance
	var right_limit: float = patrol_origin_x + patrol_right_distance

	patrol_timer = randf_range(
		PATROL_ACTION_TIME_MIN,
		PATROL_ACTION_TIME_MAX
	)

	# 순찰 범위 가장자리에 있으면 랜덤 선택하지 않고 안쪽으로 돌아봄
	if global_position.x <= left_limit + 1.0:
		start_patrol_turn(1)
		return

	if global_position.x >= right_limit - 1.0:
		start_patrol_turn(-1)
		return

	# 4개 행동 중 완전 랜덤
	var choice: int = randi_range(0, 3)

	match choice:
		0:
			patrol_action = PatrolAction.MOVE_LEFT
			patrol_facing = -1
			apply_patrol_facing()

		1:
			patrol_action = PatrolAction.MOVE_RIGHT
			patrol_facing = 1
			apply_patrol_facing()

		2:
			# 그냥 현재 방향으로 서 있음
			patrol_action = PatrolAction.STOP

		3:
			# 서 있는 상태에서 반대 방향으로 돌아봄
			patrol_action = PatrolAction.STOP_TURN
			patrol_facing *= -1
			apply_patrol_facing()

	# walk sprite는 현재 깨져 있으므로 임시로 idle 사용
	animated_sprite.play("idle")


func start_patrol_turn(new_facing: int) -> void:
	patrol_action = PatrolAction.STOP_TURN
	patrol_facing = new_facing
	velocity.x = 0.0

	patrol_timer = randf_range(
		PATROL_ACTION_TIME_MIN,
		PATROL_ACTION_TIME_MAX
	)

	apply_patrol_facing()
	animated_sprite.play("idle")


func apply_patrol_facing() -> void:
	direction = patrol_facing

	if patrol_facing > 0:
		animated_sprite.flip_h = false
	else:
		animated_sprite.flip_h = true


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

	if animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")


func damage_player(player_body: Node) -> void:
	if is_dead:
		return
	
	if enemy_mode != EnemyMode.COMBAT:
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

	if animated_sprite.sprite_frames.has_animation("enemy1_attack"):
		animated_sprite.play("enemy1_attack")

	var knockback_direction: int = int(sign(player_body.global_position.x - global_position.x))

	if knockback_direction == 0:
		knockback_direction = direction

	player_body.take_damage(
		ATTACK_DAMAGE,
		knockback_direction,
		PLAYER_KNOCKBACK_POWER,
		120.0
	)

	if not is_inside_tree():
		return

	var tree := get_tree()
	if tree == null:
		return

	await tree.create_timer(ATTACK_PAUSE_TIME).timeout

	if not is_inside_tree():
		return

	is_attacking = false

	if animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")

	var remaining_cooldown: float = max(ATTACK_COOLDOWN - ATTACK_PAUSE_TIME, 0.0)
	await tree.create_timer(remaining_cooldown).timeout

	if not is_inside_tree():
		return

	can_attack = true


func start_dash_attack(player_body: Node) -> void:
	if is_dead:
		return
	
	if enemy_mode != EnemyMode.COMBAT:
		return

	if not can_dash:
		return

	if is_attacking or is_dashing:
		return

	if player_body == null:
		return

	if not is_instance_valid(player_body):
		return

	can_dash = false
	is_attacking = true
	velocity.x = 0.0
	dash_has_hit = false

	dash_direction = int(sign(player_body.global_position.x - global_position.x))
	if dash_direction == 0:
		dash_direction = direction

	direction = dash_direction

	if dash_direction > 0:
		animated_sprite.flip_h = false
	else:
		animated_sprite.flip_h = true

	if animated_sprite.sprite_frames.has_animation("enemy1_dash"):
		animated_sprite.play("enemy1_dash")

	if not is_inside_tree():
		return

	var tree := get_tree()
	if tree == null:
		return

	# 잠깐 멈췄다가 돌진
	await tree.create_timer(DASH_CHARGE_TIME).timeout

	if not is_inside_tree():
		return

	if is_dead:
		return

	is_attacking = false
	is_dashing = true

	await tree.create_timer(DASH_TIME).timeout

	if not is_inside_tree():
		return

	is_dashing = false
	velocity.x = 0.0

	if animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")

	await tree.create_timer(DASH_COOLDOWN).timeout

	if not is_inside_tree():
		return

	can_dash = true


func hit_player_with_dash(player_body: Node) -> void:
	if is_dead:
		return

	if not is_dashing:
		return

	if dash_has_hit:
		return

	if player_body == null:
		return

	if not is_instance_valid(player_body):
		return

	if not player_body.has_method("take_damage"):
		return

	dash_has_hit = true
	is_dashing = false
	velocity.x = 0.0

	var knockback_direction: int = int(sign(player_body.global_position.x - global_position.x))
	if knockback_direction == 0:
		knockback_direction = dash_direction

	player_body.take_damage(
		ATTACK_DAMAGE,
		knockback_direction,
		PLAYER_KNOCKBACK_POWER,
		DASH_LAUNCH_POWER
	)

	if animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")



func die() -> void:
	if is_dead:
		return

	is_dead = true
	print("Slime died")
	queue_free()

func _on_player_damage_area_body_entered(body: Node2D) -> void:
	if body == null:
		return
	
	if enemy_mode != EnemyMode.COMBAT:
		return

	if not is_instance_valid(body):
		return

	if body.is_in_group("player"):
		target_player = body

		if is_dashing:
			hit_player_with_dash(target_player)
		elif can_attack and not is_attacking:
			damage_player(target_player)


func _on_player_damage_area_body_exited(body: Node2D) -> void:
	if target_player != null and body == target_player:
		target_player = null


func set_patrol_mode() -> void:
	enemy_mode = EnemyMode.PATROL

	is_attacking = false
	is_dashing = false

	velocity.x = 0.0

	patrol_origin_x = global_position.x
	patrol_facing = direction

	choose_next_patrol_action()


func set_combat_mode() -> void:
	enemy_mode = EnemyMode.COMBAT
	velocity.x = 0.0

	if animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")

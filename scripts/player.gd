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

const UPPERCUT_DAMAGE: int = 1
const UPPERCUT_PLAYER_VELOCITY: float = -270.0

const AIR_ATTACK_DAMAGE: int = 1

const SLAM_WINDUP_TIME: float = 0.10
const SLAM_FALL_SPEED: float = 520.0

const SLAM_MEDIUM_DISTANCE: float = 100.0
const SLAM_STRONG_DISTANCE: float = 200.0

const SLAM_WEAK_DAMAGE: int = 1
const SLAM_MEDIUM_DAMAGE: int = 2
const SLAM_STRONG_DAMAGE: int = 3

const SLAM_SHAKE_DURATION_WEAK: float = 0.08
const SLAM_SHAKE_DURATION_MEDIUM: float = 0.12
const SLAM_SHAKE_DURATION_STRONG: float = 0.18

# Hit Stop
const HIT_STOP_TIME_SCALE: float = 0.05

const HIT_STOP_NORMAL: float = 0.035
const HIT_STOP_UPPERCUT: float = 0.060
const HIT_STOP_AIR_ATTACK: float = 0.050

const HIT_STOP_SLAM_WEAK: float = 0.045
const HIT_STOP_SLAM_MEDIUM: float = 0.070
const HIT_STOP_SLAM_STRONG: float = 0.095

var current_ladder: Area2D = null
var is_climbing: bool = false

enum AttackType {
	NONE,
	GROUND_NORMAL,
	UPPERCUT,
	SLAM,
	AIR_NORMAL
}

enum SlamImpactLevel {
	WEAK,
	MEDIUM,
	STRONG
}

var current_attack: AttackType = AttackType.NONE

var is_slamming: bool = false
var slam_windup_remaining: float = 0.0
var slam_start_y: float = 0.0
var last_slam_fall_distance: float = 0.0

var is_attacking: bool = false
var already_hit_enemies: Array = []
var facing_direction: int = 1
var attack_has_hit: bool = false
var is_dead: bool = false

var hp: int = MAX_HP
var is_invincible: bool = false
var knockback_velocity: float = 0.0
var hit_stop_id: int = 0


func play_hit_stop(duration: float) -> void:
	hit_stop_id += 1

	var this_hit_stop_id: int = hit_stop_id

	# 게임 전체를 거의 정지
	Engine.time_scale = HIT_STOP_TIME_SCALE

	# time_scale의 영향을 받지 않는 실제 시간 타이머
	await get_tree().create_timer(
		duration,
		true,
		false,
		true
	).timeout

	if not is_inside_tree():
		return

	# 새로운 히트스톱이 이미 발생했다면
	# 이전 타이머가 시간을 원상복구하지 못하게 함
	if this_hit_stop_id != hit_stop_id:
		return

	Engine.time_scale = 1.0


func _exit_tree() -> void:
	# 히트스톱 중 씬이 종료되어도
	# 다음 씬이 느려지는 문제 방지
	Engine.time_scale = 1.0

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
	if (
		Input.is_action_just_pressed("jump")
		and is_on_floor()
		and not is_attacking
		and not is_slamming
	):
		velocity.y = JUMP_VELOCITY
		
	# Attack
	if not is_attacking:
		if Input.is_action_just_pressed("attack_left"):
			facing_direction = -1

			if is_on_floor():
				request_attack(AttackType.GROUND_NORMAL, Vector2.LEFT)
			else:
				request_attack(AttackType.AIR_NORMAL, Vector2.LEFT)

		elif Input.is_action_just_pressed("attack_right"):
			facing_direction = 1

			if is_on_floor():
				request_attack(AttackType.GROUND_NORMAL, Vector2.RIGHT)
			else:
				request_attack(AttackType.AIR_NORMAL, Vector2.RIGHT)

		elif Input.is_action_just_pressed("attack_up"):
			if is_on_floor():
				request_attack(AttackType.UPPERCUT, Vector2.UP)

		elif Input.is_action_just_pressed("attack_down"):
			if not is_on_floor():
				request_attack(AttackType.SLAM, Vector2.DOWN)
	
	# 내려찍기 중에는 일반 이동/점프/공격 물리를 사용하지 않음
	if is_slamming:
		process_slam(delta)
		return
	
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


func request_attack(
	attack_type: AttackType,
	attack_direction: Vector2
) -> void:
	if is_dead:
		return

	if is_attacking:
		return

	if is_slamming:
		return

	current_attack = attack_type

	match current_attack:
		AttackType.GROUND_NORMAL:
			print("ATTACK: GROUND NORMAL")

		AttackType.UPPERCUT:
			print("ATTACK: UPPERCUT")

		AttackType.SLAM:
			print("ATTACK: SLAM")
			start_slam()
			return

		AttackType.AIR_NORMAL:
			print("ATTACK: AIR NORMAL")

	attack(attack_direction)


func start_slam() -> void:
	is_attacking = true
	is_slamming = true

	attack_has_hit = false
	already_hit_enemies.clear()

	# 내려찍기를 시작한 높이 저장
	slam_start_y = global_position.y
	last_slam_fall_distance = 0.0

	# 짧은 공중 정지 시간
	slam_windup_remaining = SLAM_WINDUP_TIME

	# 입력 당시 움직임을 잠깐 멈춤
	velocity = Vector2.ZERO

	# 아직 전용 스프라이트가 없으므로 기존 공격 사용
	animated_sprite.play("attack1")

	# 히트박스 위치는 플레이어 아래쪽
	update_attack_area_position(Vector2.DOWN)

	attack_area.monitoring = false
	attack_shape.disabled = true
	
	# 내려찍는 동안 Enemy 몸에 걸리지 않고 관통한다.
	# Enemy는 Physics Layer 3.
	set_collision_mask_value(3, false)


func process_slam(delta: float) -> void:
	# 1. 공격 직전 잠깐 공중에서 멈춤
	if slam_windup_remaining > 0.0:
		slam_windup_remaining -= delta

		velocity = Vector2.ZERO

		attack_area.monitoring = false
		attack_shape.disabled = true

		move_and_slide()
		return

	# 2. 실제 내려찍기 시작
	attack_area.monitoring = true
	attack_shape.disabled = false

	velocity.x = 0.0
	velocity.y = SLAM_FALL_SPEED

	move_and_slide()

	# 내려가는 동안 적 탐색
	check_slam_hits()

	# 3. 실제 지형 바닥에 닿았을 때 종료
	if is_on_floor():
		finish_slam()


func check_slam_hits() -> void:
	for area in attack_area.get_overlapping_areas():
		var enemy: Node = area.get_parent()

		if enemy == null:
			continue

		if already_hit_enemies.has(enemy):
			continue

		if not enemy.has_method("take_slam_damage"):
			continue

		var fall_distance: float = max(
			global_position.y - slam_start_y,
			0.0
		)

		var impact_level: SlamImpactLevel = get_slam_impact_level(
			fall_distance
		)

		var damage: int = get_slam_damage(
			impact_level
		)

		print(
			"SLAM HIT: ",
			enemy.name,
			" / distance=",
			fall_distance,
			" / level=",
			SlamImpactLevel.keys()[impact_level],
			" / damage=",
			damage
		)

		enemy.take_slam_damage(damage)

		already_hit_enemies.append(enemy)
		
		var slam_hit_stop: float = get_slam_hit_stop_time(
			impact_level
		)

		play_hit_stop(slam_hit_stop)


func get_slam_impact_level(
	fall_distance: float
) -> SlamImpactLevel:
	if fall_distance >= SLAM_STRONG_DISTANCE:
		return SlamImpactLevel.STRONG

	if fall_distance >= SLAM_MEDIUM_DISTANCE:
		return SlamImpactLevel.MEDIUM

	return SlamImpactLevel.WEAK


func get_slam_damage(
	impact_level: SlamImpactLevel
) -> int:
	match impact_level:
		SlamImpactLevel.STRONG:
			return SLAM_STRONG_DAMAGE

		SlamImpactLevel.MEDIUM:
			return SLAM_MEDIUM_DAMAGE

		_:
			return SLAM_WEAK_DAMAGE


func get_slam_effect_scale(
	impact_level: SlamImpactLevel
) -> float:
	match impact_level:
		SlamImpactLevel.STRONG:
			return 1.6

		SlamImpactLevel.MEDIUM:
			return 1.25

		_:
			return 1.0


func get_slam_hit_stop_time(
	impact_level: SlamImpactLevel
) -> float:
	match impact_level:
		SlamImpactLevel.STRONG:
			return HIT_STOP_SLAM_STRONG

		SlamImpactLevel.MEDIUM:
			return HIT_STOP_SLAM_MEDIUM

		_:
			return HIT_STOP_SLAM_WEAK


func get_slam_shake_strength(
	impact_level: SlamImpactLevel
) -> float:
	match impact_level:
		SlamImpactLevel.STRONG:
			return 8.0

		SlamImpactLevel.MEDIUM:
			return 5.0

		_:
			return 2.5


func get_slam_shake_duration(
	impact_level: SlamImpactLevel
) -> float:
	match impact_level:
		SlamImpactLevel.STRONG:
			return SLAM_SHAKE_DURATION_STRONG

		SlamImpactLevel.MEDIUM:
			return SLAM_SHAKE_DURATION_MEDIUM

		_:
			return SLAM_SHAKE_DURATION_WEAK


func play_camera_shake(
	strength: float,
	duration: float
) -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()

	if camera == null:
		return

	var original_offset: Vector2 = camera.offset

	var start_time: int = Time.get_ticks_msec()
	var duration_ms: int = int(duration * 1000.0)

	while Time.get_ticks_msec() - start_time < duration_ms:
		if not is_instance_valid(camera):
			return

		camera.offset = original_offset + Vector2(
			randf_range(-strength, strength),
			randf_range(-strength * 0.65, strength * 0.65)
		)

		await get_tree().process_frame

	if is_instance_valid(camera):
		camera.offset = original_offset


func finish_slam() -> void:
	if not is_slamming:
		return

	last_slam_fall_distance = max(
		global_position.y - slam_start_y,
		0.0
	)
	
	var impact_level: SlamImpactLevel = get_slam_impact_level(
		last_slam_fall_distance
	)
	
	var shake_strength: float = get_slam_shake_strength(
		impact_level
	)

	var shake_duration: float = get_slam_shake_duration(
		impact_level
	)

	play_camera_shake(
		shake_strength,
		shake_duration
	)

	print(
		"SLAM LAND / distance=",
		last_slam_fall_distance,
		" / level=",
		SlamImpactLevel.keys()[impact_level]
	)

	is_slamming = false
	is_attacking = false

	current_attack = AttackType.NONE
	attack_has_hit = false

	velocity = Vector2.ZERO

	attack_area.monitoring = false
	attack_shape.disabled = true
	
	# 일반 상태로 돌아왔으므로 Enemy와 몸 충돌 복구
	set_collision_mask_value(3, true)

	animated_sprite.play("idle")


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

	# 방향과 관계없이 반드시 실행
	update_attack_area_position(attack_direction)

	# 실제 데미지는 공격 애니메이션 타격 프레임에서 처리
	attack_area.monitoring = false
	attack_shape.disabled = true

	await get_tree().create_timer(ATTACK_TIME).timeout

	attack_area.monitoring = false
	attack_shape.disabled = true
	is_attacking = false
	current_attack = AttackType.NONE

func apply_attack_damage() -> void:
	# await 도중 current_attack이 바뀌는 상황을 막기 위해 저장
	var attack_type_at_hit: AttackType = current_attack

	attack_area.monitoring = true
	attack_shape.disabled = false

	# 히트박스가 실제 물리 판정에 반영될 때까지 1프레임 기다림
	await get_tree().physics_frame

	for area in attack_area.get_overlapping_areas():
		print("OVERLAP AREA: ", area.name)
		
		var enemy = area.get_parent()

		if enemy == null:
			continue

		if already_hit_enemies.has(enemy):
			continue

		var knockback_direction: int = int(sign(
			enemy.global_position.x - global_position.x
		))

		if knockback_direction == 0:
			knockback_direction = facing_direction

		# 어퍼컷
		if (
			attack_type_at_hit == AttackType.UPPERCUT
			and enemy.has_method("take_uppercut_damage")
		):
			enemy.take_uppercut_damage(
				UPPERCUT_DAMAGE,
				knockback_direction
			)

			already_hit_enemies.append(enemy)

			play_hit_stop(HIT_STOP_UPPERCUT)

			continue
		
		# 공중 일반 공격
		if (
			attack_type_at_hit == AttackType.AIR_NORMAL
			and enemy.has_method("take_air_attack_damage")
		):
			enemy.take_air_attack_damage(
				AIR_ATTACK_DAMAGE,
				knockback_direction
			)

			already_hit_enemies.append(enemy)

			play_hit_stop(HIT_STOP_AIR_ATTACK)

			continue

		# 일반 공격
		if enemy.has_method("take_damage"):
			enemy.take_damage(
				ATTACK_DAMAGE,
				knockback_direction,
				180.0
			)

			already_hit_enemies.append(enemy)

			play_hit_stop(HIT_STOP_NORMAL)

	attack_area.monitoring = false
	attack_shape.disabled = true

	# 어퍼컷은 적중 판정을 끝낸 다음 플레이어가 상승
	# 적을 못 맞혔어도 상승한다.
	if attack_type_at_hit == AttackType.UPPERCUT:
		velocity.y = UPPERCUT_PLAYER_VELOCITY

func update_attack_area_position(attack_direction: Vector2) -> void:
	var attack_distance: float = 28.0

	if attack_direction == Vector2.LEFT:
		attack_area.position = Vector2(-attack_distance, 0.0)

	elif attack_direction == Vector2.RIGHT:
		attack_area.position = Vector2(attack_distance, 0.0)

	elif attack_direction == Vector2.UP:
		# 어퍼컷은 머리 위가 아니라
		# 현재 바라보는 방향의 앞 + 약간 위
		attack_area.position = Vector2(
			18.0 * facing_direction,
			-10.0
		)

	elif attack_direction == Vector2.DOWN:
		attack_area.position = Vector2(
			0.0,
			attack_distance
		)

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "attack1":
		# 내려찍기는 바닥에 닿을 때까지 자체 상태 유지
		if is_slamming:
			return

		is_attacking = false
		attack_has_hit = false
		current_attack = AttackType.NONE

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

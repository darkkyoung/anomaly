extends CharacterBody2D

const SPEED: float = 50.0
const GRAVITY_MULTIPLIER: float = 1.0
const KNOCKBACK_FRICTION: float = 700.0

# Enemy2 중심 기준 원형 사격 반경
# 16px = 1블록으로 보면 약 20블록
const SHOOT_RADIUS: float = 320.0

# 이 거리보다 가까우면 사격하지 않고 도망
# 약 4.5블록
const RETREAT_RADIUS: float = 72.0

# 120도를 3구간으로 나눔
# -60 ~ -20 = 위쪽 공격
# -20 ~ +20 = 중앙 공격
# +20 ~ +60 = 아래쪽 공격
const AIM_UP_THRESHOLD_DEG: float = -20.0
const AIM_DOWN_THRESHOLD_DEG: float = 20.0

const SHOOT_COOLDOWN: float = 1.2
const SHOOT_PAUSE_TIME: float = 0.45

const AIM_LINE_WIDTH: float = 1.0
const AIM_LINE_ALPHA: float = 0.5

@export var max_hp: int = 3
@export var bullet_scene: PackedScene = preload("res://scenes/enemy2_bullet.tscn")

var current_hp: int
var direction: int = 1
var is_dead: bool = false
var is_attacking: bool = false
var can_shoot: bool = true
var hit_anim_id: int = 0
var knockback_velocity: float = 0.0

var player: Node = null
var aim_line: Line2D = null

# 조준을 시작한 순간의 정보를 저장
var locked_shot_direction: Vector2 = Vector2.RIGHT
var locked_target_local: Vector2 = Vector2.ZERO
var locked_muzzle_offset: Vector2 = Vector2.ZERO
var locked_attack_animation: StringName = &"enemy2_attack_mid"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_damage_area: Area2D = $PlayerDamageArea
@onready var player_damage_shape: CollisionShape2D = $PlayerDamageArea/CollisionShape2D


func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemy")

	player = get_tree().get_first_node_in_group("player")

	play_idle()

	# enemy2는 접촉 공격을 하지 않는 원거리 적이므로 비활성화
	if player_damage_area != null:
		player_damage_area.monitoring = false

	if player_damage_shape != null:
		player_damage_shape.disabled = true

	create_aim_line()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity += get_gravity() * GRAVITY_MULTIPLIER * delta

	if abs(knockback_velocity) > 1.0:
		velocity.x = knockback_velocity
		knockback_velocity = move_toward(
			knockback_velocity,
			0.0,
			KNOCKBACK_FRICTION * delta
		)
		move_and_slide()
		return

	# 사격 준비 중에는 제자리 정지
	if is_attacking:
		velocity.x = 0.0
		move_and_slide()
		return

	decide_ranged_action()

	move_and_slide()


func decide_ranged_action() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		velocity.x = 0.0
		play_idle()
		hide_aim_line()
		return

	if not is_instance_valid(player):
		player = null
		velocity.x = 0.0
		play_idle()
		hide_aim_line()
		return

	var diff: Vector2 = player.global_position - global_position
	var distance: float = diff.length()

	# 플레이어가 어느 쪽에 있는지 바라봄
	if abs(diff.x) > 2.0:
		direction = int(sign(diff.x))

	update_sprite_facing()

	# 1. 플레이어가 너무 가까우면 반대 방향으로 도망
	if distance <= RETREAT_RADIUS:
		velocity.x = -direction * SPEED
		play_idle()
		hide_aim_line()
		return

	# 여기부터는 기본적으로 절대 이동하지 않음
	velocity.x = 0.0

	# 2. 사격 반경 밖이면 그냥 제자리 대기
	if distance > SHOOT_RADIUS:
		play_idle()
		hide_aim_line()
		return

	# 3. 사격 반경 안이면 제자리에서 사격
	if can_shoot:
		shoot_player()

	return
	
func shoot_player() -> void:
	if is_dead:
		return

	if not can_shoot:
		return

	if bullet_scene == null:
		print("enemy2 bullet_scene is not assigned")
		return

	if player == null or not is_instance_valid(player):
		return

	# 현재 플레이어 위치를 기준으로 조준 방향 잠금
	if not lock_current_aim():
		play_idle()
		return

	can_shoot = false
	is_attacking = true
	velocity.x = 0.0

	update_sprite_facing()

	# 조준하는 동안 선택된 공격 모션의 1번 프레임에서 정지
	set_attack_pose_frame_zero(locked_attack_animation)

	# 빨간 조준선 표시
	show_aim_line()

	var tree := get_tree()
	if tree == null:
		return

	# 저격 예고 시간
	await tree.create_timer(SHOOT_PAUSE_TIME).timeout

	if not is_inside_tree() or is_dead:
		return

	# 4프레임 공격 애니메이션 시작
	animated_sprite.play(locked_attack_animation)

	# 2번째 프레임(index 1)이 될 때까지 기다림
	while animated_sprite.frame < 1:
		await animated_sprite.frame_changed

		if not is_inside_tree() or is_dead:
			return

	# 2번째 프레임 = 총구 섬광이 뜨는 순간
	hide_aim_line()
	fire_bullet()

	# 공격 애니메이션 끝날 때까지 대기
	await animated_sprite.animation_finished

	if not is_inside_tree() or is_dead:
		return

	is_attacking = false
	play_idle()

	# 다음 사격까지 쿨타임
	await tree.create_timer(SHOOT_COOLDOWN).timeout

	if not is_inside_tree():
		return

	can_shoot = true
	

func lock_current_aim() -> bool:
	if player == null or not is_instance_valid(player):
		return false

	var diff: Vector2 = player.global_position - global_position

	if abs(diff.x) > 4.0:
		direction = int(sign(diff.x))

	var aim_angle_deg := get_forward_aim_angle_deg(diff)

	locked_attack_animation = get_attack_animation_name(aim_angle_deg)

	# 자세별 총구 위치
	locked_muzzle_offset = get_muzzle_offset(locked_attack_animation)

	# Enemy2 기준 로컬 플레이어 위치
	locked_target_local = player.global_position - global_position

	var shot_vector: Vector2 = locked_target_local - locked_muzzle_offset

	if shot_vector.length_squared() <= 0.001:
		return false

	locked_shot_direction = shot_vector.normalized()

	return true


func get_forward_aim_angle_deg(diff: Vector2) -> float:
	# 좌우 어느 방향을 보고 있어도 자기 앞쪽을 +X로 취급
	var forward_diff := Vector2(abs(diff.x), diff.y)

	# Godot은 Y+가 아래쪽
	# 음수 = 위 / 양수 = 아래
	return rad_to_deg(atan2(forward_diff.y, forward_diff.x))


func get_attack_animation_name(aim_angle_deg: float) -> StringName:
	if aim_angle_deg < AIM_UP_THRESHOLD_DEG:
		return &"enemy2_attack_up"

	if aim_angle_deg > AIM_DOWN_THRESHOLD_DEG:
		return &"enemy2_attack_down"

	return &"enemy2_attack_mid"


func set_attack_pose_frame_zero(animation_name: StringName) -> void:
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		play_idle()
		return

	animated_sprite.play(animation_name)
	animated_sprite.pause()
	animated_sprite.frame = 0


func fire_bullet() -> void:
	if bullet_scene == null:
		return

	var bullet = bullet_scene.instantiate()

	var scene := get_tree().current_scene
	if scene == null:
		return

	scene.add_child(bullet)

	# 조준을 시작할 때 저장해둔 총구에서 생성
	bullet.global_position = global_position + locked_muzzle_offset

	if bullet.has_method("setup"):
		bullet.setup(locked_shot_direction, player)


func create_aim_line() -> void:
	aim_line = Line2D.new()
	aim_line.name = "AimLine"
	aim_line.width = AIM_LINE_WIDTH
	aim_line.default_color = Color(1.0, 0.0, 0.0, AIM_LINE_ALPHA)
	aim_line.z_index = 20
	aim_line.visible = false
	add_child(aim_line)


func show_aim_line() -> void:
	if aim_line == null:
		return

	aim_line.points = PackedVector2Array([
		locked_muzzle_offset,
		locked_target_local
	])

	aim_line.visible = true


func hide_aim_line() -> void:
	if aim_line == null:
		return

	aim_line.visible = false


func get_muzzle_offset(animation_name: StringName) -> Vector2:
	var sx: float = animated_sprite.scale.x
	var sy: float = animated_sprite.scale.y

	match animation_name:
		&"enemy2_attack_up":
			return Vector2(31.0 * direction * sx, -18.0 * sy)

		&"enemy2_attack_down":
			return Vector2(30.0 * direction * sx, 2.0 * sy)

		_:
			return Vector2(31.0 * direction * sx, -6.0 * sy)

func update_sprite_facing() -> void:
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

func take_damage(
	amount: int,
	knockback_direction: int = 0,
	knockback_power: float = 180.0
) -> void:
	if is_dead:
		return

	current_hp -= amount
	current_hp = max(current_hp, 0)

	print("Enemy2 HP: ", current_hp, "/", max_hp)

	if knockback_direction != 0:
		knockback_velocity = knockback_direction * knockback_power

	if current_hp <= 0:
		die()
		return

	play_hit_animation()


func play_hit_animation() -> void:
	hit_anim_id += 1
	var this_hit_id := hit_anim_id

	if animated_sprite.sprite_frames.has_animation("enemy2_hit"):
		animated_sprite.play("enemy2_hit")
	else:
		play_idle()

	if not is_inside_tree():
		return

	var tree := get_tree()
	if tree == null:
		return

	await tree.create_timer(0.25).timeout

	if is_dead:
		return

	if this_hit_id != hit_anim_id:
		return

	play_idle()


func play_idle() -> void:
	if animated_sprite.sprite_frames.has_animation("idle"):
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")


func die() -> void:
	if is_dead:
		return

	is_dead = true
	hide_aim_line()
	print("Enemy2 died")
	queue_free()

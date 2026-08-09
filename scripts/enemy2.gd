extends CharacterBody2D

const SPEED: float = 50.0
const GRAVITY_MULTIPLIER: float = 1.0
const KNOCKBACK_FRICTION: float = 700.0

const TOO_CLOSE_RANGE: float = 90.0
const SHOOT_MIN_RANGE: float = 110.0
const SHOOT_MAX_RANGE: float = 280.0

const DETECTION_RANGE_X: float = 420.0
const DETECTION_RANGE_Y: float = 130.0

const SHOOT_COOLDOWN: float = 1.2
const SHOOT_PAUSE_TIME: float = 0.45

const AIM_LINE_WIDTH: float = 2.0
const AIM_LINE_ALPHA: float = 0.85

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
	var distance_x: float = abs(diff.x)
	var distance_y: float = abs(diff.y)

	# 인지 범위 밖이면 아무 행동 안 함
	if distance_x > DETECTION_RANGE_X or distance_y > DETECTION_RANGE_Y:
		velocity.x = 0.0
		play_idle()
		hide_aim_line()
		return

	# 방향 결정
	if abs(diff.x) > 2.0:
		direction = int(sign(diff.x))

	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

	# 1. 플레이어가 너무 가까우면 뒤로 물러남
	if distance_x < TOO_CLOSE_RANGE:
		velocity.x = -direction * SPEED
		play_idle()
		hide_aim_line()
		return

	# 2. 적정 사거리 안이면 멈춰서 사격
	if distance_x >= SHOOT_MIN_RANGE and distance_x <= SHOOT_MAX_RANGE:
		velocity.x = 0.0

		if can_shoot:
			shoot_player()

		return

	# 3. 인식은 했지만 사격 거리보다 멀면 접근
	if distance_x > SHOOT_MAX_RANGE:
		velocity.x = direction * SPEED
		play_idle()
		hide_aim_line()
		return

	# 4. 완충 구간에서는 제자리 대기
	velocity.x = 0.0
	play_idle()
	hide_aim_line()


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

	can_shoot = false
	is_attacking = true
	velocity.x = 0.0

	var x_diff: float = player.global_position.x - global_position.x
	if abs(x_diff) > 4.0:
		direction = int(sign(x_diff))

	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

	if animated_sprite.sprite_frames.has_animation("enemy2_attack"):
		animated_sprite.play("enemy2_attack")
	else:
		play_idle()

	show_aim_line()

	if not is_inside_tree():
		return

	var tree := get_tree()
	if tree == null:
		return

	# 빨간 조준선 표시 시간
	await tree.create_timer(SHOOT_PAUSE_TIME).timeout

	if not is_inside_tree():
		return

	if is_dead:
		return

	hide_aim_line()
	fire_bullet()

	is_attacking = false
	play_idle()

	await tree.create_timer(SHOOT_COOLDOWN).timeout

	if not is_inside_tree():
		return

	can_shoot = true


func fire_bullet() -> void:
	if bullet_scene == null:
		return

	var bullet = bullet_scene.instantiate()

	var scene := get_tree().current_scene
	if scene == null:
		return

	scene.add_child(bullet)

	var muzzle_offset := get_muzzle_offset()
	bullet.global_position = global_position + muzzle_offset

	if bullet.has_method("setup"):
		bullet.setup(direction, player)


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

	var muzzle_offset := get_muzzle_offset()
	var end_point := Vector2(direction * SHOOT_MAX_RANGE, muzzle_offset.y)

	aim_line.points = PackedVector2Array([
		muzzle_offset,
		end_point
	])

	aim_line.visible = true


func hide_aim_line() -> void:
	if aim_line == null:
		return

	aim_line.visible = false


func get_muzzle_offset() -> Vector2:
	return Vector2(34.0 * direction, -8.0)


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

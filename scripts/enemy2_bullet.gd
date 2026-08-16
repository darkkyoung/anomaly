extends Area2D

const SPEED: float = 360.0
const DAMAGE: int = 1
const KNOCKBACK_POWER: float = 220.0
const LAUNCH_POWER: float = 80.0
const LIFE_TIME: float = 2.0

# 충돌 신호가 안 잡혀도 플레이어 근처를 지나가면 맞도록 보정하는 반경
const PLAYER_HIT_RADIUS: float = 18.0

var direction: int = 1
var target_player: Node2D = null
var has_hit: bool = false


func _ready() -> void:
	# 혹시 에디터에서 꺼져 있어도 코드에서 강제로 켬
	monitoring = true
	monitorable = true

	# 충돌 레이어/마스크가 꼬였을 가능성을 줄이기 위해 코드에서 강제 설정
	# Layer 4 = 적 탄환
	# Mask 전체 = 일단 다 감지하고, 코드에서 player/enemy/world를 구분
	collision_layer = 8
	collision_mask = 0xFFFFFFFF

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	var tree := get_tree()
	if tree == null:
		return

	await tree.create_timer(LIFE_TIME).timeout

	if is_inside_tree():
		queue_free()


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	global_position.x += direction * SPEED * delta

	check_player_by_distance()


func setup(new_direction: int, new_target_player: Node = null) -> void:
	direction = new_direction

	if new_target_player is Node2D:
		target_player = new_target_player

	if direction < 0:
		scale.x = -abs(scale.x)
	else:
		scale.x = abs(scale.x)


func check_player_by_distance() -> void:
	if has_hit:
		return

	if target_player == null or not is_instance_valid(target_player):
		var found_player := get_tree().get_first_node_in_group("player")
		if found_player is Node2D:
			target_player = found_player

	if target_player == null:
		return

	if not is_instance_valid(target_player):
		return

	var distance_to_player := global_position.distance_to(target_player.global_position)

	if distance_to_player <= PLAYER_HIT_RADIUS:
		damage_player(target_player)


func damage_player(body: Node) -> void:
	if has_hit:
		return

	if body == null:
		return

	if not is_instance_valid(body):
		return

	if body.is_in_group("player") and body.has_method("take_damage"):
		has_hit = true

		print("Enemy2 bullet hit player")

		body.take_damage(
			DAMAGE,
			direction,
			KNOCKBACK_POWER,
			LAUNCH_POWER
		)

		queue_free()


func _on_body_entered(body: Node) -> void:
	if has_hit:
		return

	if body == null:
		return

	if not is_instance_valid(body):
		return

	if body.is_in_group("player"):
		damage_player(body)
		return

	# 적에게는 맞지 않게 함
	if body.is_in_group("enemy"):
		return

	# 바닥/벽/타일맵에 닿으면 삭제
	queue_free()

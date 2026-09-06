extends Node2D

const AFTER_EXPLOSION_DELAY: float = 0.2
const PLAYER_FALL_DURATION: float = 0.55

@export var title_overlay: CanvasLayer
@export var start_button: Button

@export var player: CharacterBody2D
@export var player_camera: Camera2D
@export var intro_camera: Camera2D

@export var explosion_point: Marker2D
@export var player_appear_point: Marker2D
@export var player_landing_point: Marker2D

@export var intact_wall: Sprite2D
@export var broken_wall: Sprite2D
@export var wall_collision: CollisionShape2D


var cinematic_started: bool = false
var player_sprite: AnimatedSprite2D


func _ready() -> void:
	player_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D

	prepare_intro()


func prepare_intro() -> void:
	intro_camera.enabled = true
	player_camera.enabled = false

	# 등장 전에는 플레이어를 숨김
	player.visible = false

	# 시네마틱 중 직접 조작 금지
	player.set_physics_process(false)

	# 시네마틱 중 적에게 맞아 HP가 줄지 않도록
	player.is_invincible = true

	start_button.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	if cinematic_started:
		return

	cinematic_started = true
	start_button.disabled = true

	# 타이틀 전체 제거
	title_overlay.hide()

	print("INTRO START")

	# 타이틀이 사라진 뒤 잠깐 정적
	await get_tree().create_timer(0.5).timeout

	print("EXPLOSION")

	await explode_prison_wall()
	
	await get_tree().create_timer(AFTER_EXPLOSION_DELAY).timeout

	await play_player_entrance()

	print("PLAYER ENTRANCE FINISHED")
	
func explode_prison_wall() -> void:
	intact_wall.visible = false
	broken_wall.visible = true

	wall_collision.set_deferred("disabled", true)

	await shake_intro_camera(0.35, 7.0)

	print("WALL DESTROYED")

func shake_intro_camera(duration: float, strength: float) -> void:
	var original_offset: Vector2 = intro_camera.offset
	var elapsed: float = 0.0

	while elapsed < duration:
		intro_camera.offset = original_offset + Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)

		await get_tree().process_frame
		elapsed += get_process_delta_time()

	intro_camera.offset = original_offset
	
func play_player_entrance() -> void:
	# 플레이어가 화면에 처음 보이는 고점으로 이동
	player.global_position = player_appear_point.global_position

	# 이제 화면에 등장
	player.visible = true

	player_sprite.play("jump")

	print("PLAYER APPEARED")

	# 아래쪽 고정 착지 지점으로 낙하
	var tween: Tween = create_tween()

	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)

	tween.tween_property(
		player,
		"global_position",
		player_landing_point.global_position,
		PLAYER_FALL_DURATION
	)

	await tween.finished

	# 정확한 착지 위치 보정
	player.global_position = player_landing_point.global_position
	player.velocity = Vector2.ZERO

	player_sprite.play("idle")

	print("PLAYER LANDED")

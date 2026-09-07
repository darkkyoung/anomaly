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
@export var player_arc_point: Marker2D
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
	var start_position: Vector2 = player_appear_point.global_position
	var arc_position: Vector2 = player_arc_point.global_position
	var end_position: Vector2 = player_landing_point.global_position

	player.global_position = start_position
	player.visible = true
	player.velocity = Vector2.ZERO

	player_sprite.play("jump")

	print("PLAYER APPEARED")

	var tween: Tween = create_tween()

	tween.tween_method(
		Callable(self, "_update_player_arc").bind(
			start_position,
			arc_position,
			end_position
		),
		0.0,
		1.0,
		PLAYER_FALL_DURATION
	)

	await tween.finished

	player.global_position = end_position
	player.velocity = Vector2.ZERO

	player_sprite.play("idle")

	print("PLAYER LANDED")
	
func _update_player_arc(
	t: float,
	start_position: Vector2,
	arc_position: Vector2,
	end_position: Vector2
) -> void:
	var inverse_t: float = 1.0 - t

	player.global_position = (
		inverse_t * inverse_t * start_position
		+ 2.0 * inverse_t * t * arc_position
		+ t * t * end_position
	)

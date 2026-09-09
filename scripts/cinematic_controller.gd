extends Node2D

const START_TO_EXPLOSION_DELAY: float = 2.0
const AFTER_EXPLOSION_DELAY: float = 1.2
const PLAYER_FALL_DURATION: float = 0.55

@export var title_overlay: CanvasLayer
@export var start_button: Button

@export var dialogue_box: DialogueBox
@export var player_hp_bar: Control

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

@onready var explosion_fx: AnimatedSprite2D = $ExplosionPoint/ExplosionFX


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
	
	# 시네마틱 중 hp바 숨김
	player_hp_bar.visible = false
	
	broken_wall.z_index = 2

	start_button.pressed.connect(_on_start_pressed)
	
	explosion_fx.visible = false
	explosion_fx.stop()
	explosion_fx.frame = 0

	intact_wall.visible = true
	broken_wall.visible = false


func _on_start_pressed() -> void:
	if cinematic_started:
		return

	cinematic_started = true
	start_button.disabled = true

	# 타이틀 전체 제거
	title_overlay.hide()

	print("INTRO START")

	# 타이틀이 사라진 뒤 잠깐 정적
	await get_tree().create_timer(START_TO_EXPLOSION_DELAY).timeout

	print("EXPLOSION")

	await explode_prison_wall()
	
	await get_tree().create_timer(AFTER_EXPLOSION_DELAY).timeout

	await play_player_entrance()

	print("PLAYER ENTRANCE FINISHED")
	
	# 착지 직후 잠시 여운
	await get_tree().create_timer(0.4).timeout

	# 대화
	await play_intro_dialogue()

	print("DIALOGUE FINISHED")

	finish_cinematic()


func set_enemies_to_cinematic_defend() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")

	for enemy: Node in enemies:
		if enemy.has_method("set_cinematic_defend"):
			enemy.set_cinematic_defend(explosion_point.global_position)


func explode_prison_wall() -> void:
	# 폭발 순간 Enemy PATROL 중단
	set_enemies_to_cinematic_defend()

	# 폭발 이펙트 시작
	explosion_fx.visible = true
	explosion_fx.frame = 0
	explosion_fx.play("explode")

	# 폭발과 정확히 동시에 카메라 흔들림 시작
	await shake_intro_camera(0.35, 7.0)

	# 폭발이 어느 정도 진행된 뒤 벽이 무너짐
	intact_wall.visible = false
	broken_wall.visible = true
	wall_collision.set_deferred("disabled", true)

	# 나머지 폭발/연기 프레임이 끝날 때까지 기다림
	if explosion_fx.is_playing():
		await explosion_fx.animation_finished

	explosion_fx.visible = false

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
	# 플레이어가 벽을 넘어오는 순간
	# 파괴된 벽을 캐릭터들 뒤쪽으로 보냄
	broken_wall.z_index = -1
	
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


func play_intro_dialogue() -> void:
	var intro_lines: Array[String] = [
		"테스트 대사입니다."
	]

	dialogue_box.start_dialogue(
		intro_lines,
		"쵸로키"
	)

	await dialogue_box.dialogue_finished


func finish_cinematic() -> void:
	# 일반 게임 카메라
	intro_camera.enabled = false
	player_camera.enabled = true

	# Player 조작 허용
	player.set_physics_process(true)
	player.is_invincible = false

	# HUD 표시
	player_hp_bar.visible = true

	# Enemy PATROL/DEFEND → COMBAT
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")

	for enemy: Node in enemies:
		if enemy.has_method("set_combat_mode"):
			enemy.set_combat_mode()

	print("GAMEPLAY START")

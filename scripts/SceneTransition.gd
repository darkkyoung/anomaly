extends CanvasLayer

@onready var wipe_rect: ColorRect = $WipeRect

var is_transitioning := false
#전환속도
const WIPE_SPEED := 5000.0


func _ready():
	# 처음에는 화면 오른쪽 밖에 위치
	wipe_rect.position.x = get_viewport().get_visible_rect().size.x
	wipe_rect.size = get_viewport().get_visible_rect().size


func change_scene(
	scene_path: String,
	bgm: AudioStreamPlayer = null,
	black_screen_duration: float = 0.5
):

	if is_transitioning:
		return

	is_transitioning = true

	var screen_size = get_viewport().get_visible_rect().size

	wipe_rect.size = screen_size

	# 화면 오른쪽 밖에서 시작
	wipe_rect.position = Vector2(
		screen_size.x,
		0
	)

	# 이동 거리
	var wipe_distance = screen_size.x

	# 속도 기반으로 실제 시간 계산
	var actual_duration = wipe_distance / WIPE_SPEED


	# =========================
	# 1. 빠른 와이프
	# =========================

	var wipe_in = create_tween()

	wipe_in.parallel().tween_property(
		wipe_rect,
		"position:x",
		0.0,
		actual_duration
	)

	# 음악 페이드아웃
	if bgm:
		wipe_in.parallel().tween_property(
			bgm,
			"volume_db",
			-80.0,
			actual_duration
		)

	await wipe_in.finished

	if bgm:
		bgm.stop()


	# =========================
	# 2. 검은 화면 유지
	# =========================

	await get_tree().create_timer(
		black_screen_duration
	).timeout


	# =========================
	# 3. 씬 전환
	# =========================

	get_tree().change_scene_to_file(scene_path)

	await get_tree().process_frame


	# 새 해상도 대응
	screen_size = get_viewport().get_visible_rect().size
	wipe_rect.size = screen_size

	wipe_distance = screen_size.x
	actual_duration = wipe_distance / WIPE_SPEED


	# =========================
	# 4. 빠르게 화면 열기
	# =========================

	var wipe_out = create_tween()

	wipe_out.tween_property(
		wipe_rect,
		"position:x",
		-screen_size.x,
		actual_duration
	)

	await wipe_out.finished

	is_transitioning = false

#종료시 전환
func quit_game(duration: float = 1.0):

	if is_transitioning:
		return

	is_transitioning = true

	var screen_size = get_viewport().get_visible_rect().size

	wipe_rect.size = screen_size
	wipe_rect.position = Vector2(screen_size.x, 0)

	var tween = create_tween()

	tween.tween_property(
		wipe_rect,
		"position:x",
		0.0,
		duration
	)

	await tween.finished

	get_tree().quit()

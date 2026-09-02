extends CanvasLayer

@onready var fade_rect: ColorRect = $ColorRect

var is_transitioning := false


func change_scene(
	scene_path: String,
	bgm: AudioStreamPlayer = null,
	duration: float = 1.0
):

	if is_transitioning:
		return

	is_transitioning = true

	fade_rect.visible = true
	fade_rect.modulate.a = 0.0

	# 암전 + 음악 페이드아웃
	var tween = create_tween()

	tween.parallel().tween_property(
		fade_rect,
		"modulate:a",
		1.0,
		duration
	)

	if bgm:
		tween.parallel().tween_property(
			bgm,
			"volume_db",
			-80.0,
			duration
		)

	await tween.finished

	if bgm:
		bgm.stop()

	# 새로운 씬으로 이동
	await get_tree().change_scene_to_file(scene_path)

	# 새 씬에서 화면 밝아짐
	var fade_in_tween = create_tween()

	fade_in_tween.tween_property(
		fade_rect,
		"modulate:a",
		0.0,
		duration
	)

	await fade_in_tween.finished

	fade_rect.visible = false

	is_transitioning = false

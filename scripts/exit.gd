extends Area2D

@export var level_number: int = 1

var activated := false

func _on_body_entered(body: Node2D) -> void:
	if activated:
		return
	if body.is_in_group("player"):
		activated = true
		# 스테이지 클리어 처리
		Gamemanager.clear_level(level_number)
		# 스테이지 선택 맵으로 이동
		get_tree().change_scene_to_file("res://scenes/Stage1map.tscn")

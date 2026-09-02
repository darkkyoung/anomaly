extends Control


func _on_start_pressed() -> void:
	SceneTransition.change_scene("res://scenes/Stage1map.tscn",$BGM,1.0)


# 옵션
func _on_option_pressed() -> void:
	pass


# 나가기
func _on_quit_pressed() -> void:
	SceneTransition.quit_game(1.0)

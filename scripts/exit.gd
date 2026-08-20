extends Area2D

@export_file("*.tscn") var next_scene_path: String

var is_transitioning: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if is_transitioning:
		return

	if not body.is_in_group("player"):
		return

	if next_scene_path.is_empty():
		push_warning("Exit: next_scene_path가 지정되지 않았습니다.")
		return

	is_transitioning = true
	get_tree().change_scene_to_file(next_scene_path)

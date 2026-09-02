extends Node2D


@onready var levels = [
	$level_1_1,
	$level_1_2,
	$level_1_3,
	$level_1_4
]

func _ready():
	for i in range(levels.size()):
		update_level_display(levels[i], i + 1)

func _on_level_1_1_pressed():
	start_level(1)
func _on_level_1_2_pressed():
	start_level(2)
func _on_level_1_3_pressed():
	start_level(3)
func _on_level_1_4_pressed():
	start_level(4)


func start_level(level_number: int):
	# 해금되지 않은 스테이지
	if not Gamemanager.is_level_unlocked(level_number):
		return
	# 이미 클리어한 스테이지
	if Gamemanager.is_level_cleared(level_number):
		return
	get_tree().change_scene_to_file(
		"res://scenes/Level" + str(level_number) + ".tscn"
	)


func update_level_display(level_node: Node, level_number: int):
	var locked = level_node.get_node("locked")
	var clear = level_node.get_node("clear")
	var button: Button = level_node.get_node("Select")
	# 클리어한 스테이지
	if Gamemanager.is_level_cleared(level_number):
		locked.visible = false
		clear.visible = true
		button.disabled = true
	# 아직 해금되지 않은 스테이지
	elif not Gamemanager.is_level_unlocked(level_number):
		locked.visible = true
		clear.visible = false
		button.disabled = true
	# 해금됐지만 아직 클리어하지 않은 스테이지
	else:
		locked.visible = false
		clear.visible = false
		button.disabled = false

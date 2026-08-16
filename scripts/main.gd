extends Node2D

@onready var pause_menu = $"UI/pause_menu"
var paused = false

func _ready():
	#일시정지 메뉴 처음부터 안 보이게 설정
	pause_menu.visible = false

#일시정지 버튼 입력 -> 일시정지 수행
func _process(delta):
	if Input.is_action_just_pressed("pause"):
		#toggle_pause()
		pausefunc()
		

func pausefunc():
	if paused:
		pause_menu.hide()
		Engine.time_scale = 1
	else:
		pause_menu.show()
		Engine.time_scale = 0
	paused = !paused

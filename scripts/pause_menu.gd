extends Control

@onready var main = $"../.."

func _process(delta):
	pass

#계속하기
func _on_resume_pressed():
	main.pausefunc()
	#get_tree().paused = false
	#visible = false

#옵션
func _on_option_pressed():
	pass # Replace with function body.

#나가기
func _on_quit_pressed():
	get_tree().quit()

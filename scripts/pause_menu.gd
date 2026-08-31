extends Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if get_tree().paused:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	get_tree().paused = true
	show()


func resume_game() -> void:
	get_tree().paused = false
	hide()


func _on_resume_pressed() -> void:
	resume_game()


func _on_option_pressed() -> void:
	print("Option menu: not implemented yet")


func _on_quit_pressed() -> void:
	get_tree().quit()

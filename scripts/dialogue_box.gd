class_name DialogueBox
extends Control


signal dialogue_finished


@onready var portrait: TextureRect = $Panel/Portrait
@onready var speaker_label: Label = $Panel/SpeakerLabel
@onready var dialogue_label: Label = $Panel/DialogueLabel
@onready var next_button: Button = $Panel/NextButton


var lines: Array[String] = []
var current_line: int = 0
var dialogue_active: bool = false


func _ready() -> void:
	visible = false

	if not next_button.pressed.is_connected(_advance_dialogue):
		next_button.pressed.connect(_advance_dialogue)


func start_dialogue(
	new_lines: Array[String],
	speaker_name: String = "",
	portrait_texture: Texture2D = null
) -> void:
	if new_lines.is_empty():
		return

	lines = new_lines
	current_line = 0
	dialogue_active = true

	speaker_label.text = speaker_name
	speaker_label.visible = not speaker_name.is_empty()

	portrait.texture = portrait_texture
	portrait.visible = portrait_texture != null

	visible = true

	_show_current_line()


func _show_current_line() -> void:
	if current_line < 0 or current_line >= lines.size():
		return

	dialogue_label.text = lines[current_line]


func _advance_dialogue() -> void:
	if not dialogue_active:
		return

	current_line += 1

	if current_line >= lines.size():
		_finish_dialogue()
		return

	_show_current_line()


func _finish_dialogue() -> void:
	dialogue_active = false
	visible = false
	dialogue_finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not dialogue_active:
		return

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey

		if (
			key_event.pressed
			and not key_event.echo
			and (
				key_event.keycode == KEY_ENTER
				or key_event.keycode == KEY_KP_ENTER
			)
		):
			get_viewport().set_input_as_handled()
			_advance_dialogue()

extends ProgressBar

var health : Health

func _ready():
	health = get_tree().current_scene.get_node("Player/Health")

	max_value = health.max
	value = health.current

	health.on_change.connect(update_hp)

func update_hp(current : int, max_hp : int):
	max_value = max_hp
	value = current

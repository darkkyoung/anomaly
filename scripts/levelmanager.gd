extends Node2D

var next_world

@onready var current_world = $Level1
#@onready var trans_anime = $transition_anime

func _ready():
	current_world.connect("world_changed", self, "handle_world_change")

func handle_world_change(current_world_name: String):
	var next_world_name: String
	match current_world_name:
		"Level1":
			next_world_name = "Level2"
		"Level2":
			next_world_name = "Level1"
			return
	next_world = load("res://" + next_wolrd_name + ".tscn").instance()
	next_world.z

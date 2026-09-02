extends Node

var unlocked_level := 1
var cleared_levels: Array[int] = []


func clear_level(level_number: int):
	if level_number not in cleared_levels:
		cleared_levels.append(level_number)

	if level_number >= unlocked_level:
		unlocked_level = level_number + 1


func is_level_unlocked(level_number: int) -> bool:
	return level_number <= unlocked_level


func is_level_cleared(level_number: int) -> bool:
	return level_number in cleared_levels

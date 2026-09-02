# 캐릭터, 몬스터, 보스 체력 공용 스크립트
class_name Health
extends Node

signal on_change (current : int, max : int)
signal on_take_damage ()
signal on_die ()

enum PostDeath {DestroyNode, RestartScean}
var current : int
var invincible : bool = false

# 무적시간, float = (무적시간)
@export var invincible_time : float = 0.5
#체력값, int = (체력값)
@export var max : int = 10
@export var post_death_action : PostDeath
@export var drop_on_death : PackedScene


func _ready():
	current = max

# 데미지 받음
func take_damage(amount : int):
	if invincible:
		return
	invincible = true
	current -= amount
	if current < 0:
		current = 0
	# 남은 체력 표시
	print("HP : ", current, " / ", max)
	on_change.emit(current, max)
	on_take_damage.emit()
	if current <= 0:
		die()
		return
	await get_tree().create_timer(invincible_time).timeout
	invincible = false


# 체력 0, 사망 이벤트
func die ():
	on_die.emit()
	
	# 사망시 루팅 드랍
	if drop_on_death != null:
		var drop = drop_on_death.initiate()
		get_node("/root/").add_child(drop)
		drop.position = get_parent().position
		
	# 파괴됨(몬스터) or 재시작(주 캐릭터 전용)
	if post_death_action == PostDeath.DestroyNode:
		get_parent().queue_free()
	elif post_death_action == PostDeath.RestartScean:
		get_tree().reload_current_scene()

# 체력 회복
func heal (amount : int):
	current += amount
	if current > max:
		current = max
	on_change.emit(current, max)

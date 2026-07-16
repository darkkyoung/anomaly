extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D

@onready var attack_area = $AttackArea
@onready var attack_shape = $AttackArea/CollisionShape2D

const ATTACK_DAMAGE = 1
const ATTACK_TIME = 0.12

var is_attacking: bool = false
var already_hit_enemies: Array = []

const SPEED = 150.0
const JUMP_VELOCITY = -300.0

func _ready() -> void:
	attack_area.monitoring = false
	attack_shape.disabled = true	

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# Attack
	if not is_attacking:
		if Input.is_action_just_pressed("attack_left"):
			attack(Vector2.LEFT)
		elif Input.is_action_just_pressed("attack_right"):
			attack(Vector2.RIGHT)
		elif Input.is_action_just_pressed("attack_up"):
			attack(Vector2.UP)
		elif Input.is_action_just_pressed("attack_down"):
			attack(Vector2.DOWN)

	# Get the input direction: -1, 0, 1
	var direction := Input.get_axis("move_left", "move_right")
	
	# Flip the sprite
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true
		
	# Play Animation
	if is_on_floor():
		if direction == 0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")
	else:
		animated_sprite.play("jump")
	
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func attack(attack_direction: Vector2) -> void:
	is_attacking = true
	already_hit_enemies.clear()

	update_attack_area_position(attack_direction)

	attack_area.monitoring = true
	attack_shape.disabled = false

	await get_tree().physics_frame

	for area in attack_area.get_overlapping_areas():
		var enemy = area.get_parent()

		if enemy == null:
			continue

		if already_hit_enemies.has(enemy):
			continue

		if enemy.has_method("take_damage"):
			var knockback_direction = sign(enemy.global_position.x - global_position.x)

			if knockback_direction == 0:
				knockback_direction = 1

			enemy.take_damage(ATTACK_DAMAGE, knockback_direction, 180.0)
			already_hit_enemies.append(enemy)

	await get_tree().create_timer(ATTACK_TIME).timeout

	attack_area.monitoring = false
	attack_shape.disabled = true
	is_attacking = false

func update_attack_area_position(attack_direction: Vector2) -> void:
	var attack_distance = 28

	if attack_direction == Vector2.LEFT:
		attack_area.position = Vector2(-attack_distance, 0)
	elif attack_direction == Vector2.RIGHT:
		attack_area.position = Vector2(attack_distance, 0)
	elif attack_direction == Vector2.UP:
		attack_area.position = Vector2(0, -attack_distance)
	elif attack_direction == Vector2.DOWN:
		attack_area.position = Vector2(0, attack_distance)

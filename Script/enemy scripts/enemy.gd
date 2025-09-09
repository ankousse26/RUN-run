extends CharacterBody2D

@export var speed: float = 120.0
@export var damage: int = 20
@export var attack_cooldown: float = 1.5
@export var min_distance_to_player: float = 25.0
@export var separation_force: float = 100.0
@export var light_fear_distance: float = 200.0
@export var retreat_speed_multiplier: float = 1.5
@export var patrol_speed: float = 80.0
@export var suspicion_duration: float = 3.0

# Health and damage system
@export var max_health: int = 100
@export var current_health: int = 100

# References
@onready var detection_area = $"DetectionRange"
@onready var animated_sprite = $AnimatedSprite2D

# Variables
var player: CharacterBody2D
var is_chasing: bool = false
var can_attack: bool = true
var has_collided_with_player: bool = false
var separation_velocity: Vector2 = Vector2.ZERO
var in_player_light: bool = false
var last_known_player_position: Vector2 = Vector2.ZERO
var suspicion_timer: float = 0.0
var is_suspicious: bool = false
var patrol_direction: Vector2 = Vector2.RIGHT
var patrol_timer: float = 0.0
var retreat_cooldown: float = 0.0

# Slow effect variables
var is_slowed: bool = false
var original_speed: float
var original_patrol_speed: float
var slow_effect_timer: float = 0.0

func _ready():
	add_to_group("enemy")
	print("Enemy ready: ", name)
	
	# Store original speeds for slow effect
	original_speed = speed
	original_patrol_speed = patrol_speed
	current_health = max_health
	
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
		detection_area.monitoring = true
		print("Detection area connected: ", detection_area.name)
		
		# Check collision layers
		print("Enemy detection area collision mask: ", detection_area.collision_mask)
		print("Enemy detection area collision layer: ", detection_area.collision_layer)
	else:
		print("ERROR: Detection area not found! Looking for: DetectionRange")
		print("Available children:")
		for child in get_children():
			print("  - ", child.name, " (", child.get_class(), ")")
	
	# Check enemy collision setup
	print("Enemy collision layer: ", collision_layer)
	print("Enemy collision mask: ", collision_mask)
	
	# Set initial patrol direction
	patrol_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _physics_process(delta):
	# Handle slow effect timer
	if is_slowed:
		slow_effect_timer -= delta
		if slow_effect_timer <= 0:
			remove_slow_effect()
	
	# Update timers
	if retreat_cooldown > 0:
		retreat_cooldown -= delta
	
	if is_suspicious:
		suspicion_timer -= delta
		if suspicion_timer <= 0:
			is_suspicious = false
			print("Enemy giving up search")
	
	# Check if player has flashlight on (anywhere near enemy)
	var player_flashlight_on = false
	if player and player.has_method("get_flashlight_state"):
		player_flashlight_on = player.get_flashlight_state()
	
	# PRIORITY 1: Retreat if flashlight is ON (anywhere) or if directly in light
	if (player_flashlight_on and player and global_position.distance_to(player.global_position) < 300) or (in_player_light and retreat_cooldown <= 0):
		handle_smart_light_retreat(delta)
	# PRIORITY 2: Chase behavior - only if flashlight is OFF
	elif is_chasing and player and not player_flashlight_on:
		handle_chase_behavior_fixed(delta)
	# PRIORITY 3: Suspicious behavior - only if flashlight is OFF
	elif is_suspicious and not player_flashlight_on:
		handle_suspicious_behavior(delta)
	# PRIORITY 4: Patrol behavior
	else:
		handle_patrol_behavior(delta)
	
	# DAMAGE CHECK - only if flashlight is OFF
	if not player_flashlight_on:
		check_collision_with_player_fixed()
	
	move_and_slide()
	
	# Update animation based on movement
	update_animation()

func handle_smart_light_retreat(delta):
	if not player:
		return
	
	print("ENEMY RETREATING FROM FLASHLIGHT!")
	
	# Calculate retreat direction (away from player)
	var retreat_direction = (global_position - player.global_position).normalized()
	
	# If too close to calculate direction, use random direction
	if retreat_direction.length() < 0.1:
		retreat_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	# Apply retreat velocity at increased speed
	velocity = retreat_direction * speed * retreat_speed_multiplier
	
	# Set cooldown to prevent flickering
	retreat_cooldown = 0.2

func handle_chase_behavior_fixed(delta):
	if not player:
		print("ERROR: Player reference lost during chase!")
		is_chasing = false
		return
	
	print("CHASING PLAYER - Distance: ", global_position.distance_to(player.global_position))
	
	# Simple direct chase - move toward player
	var direction_to_player = (player.global_position - global_position).normalized()
	velocity = direction_to_player * speed
	
	# Reset suspicion when actively chasing
	is_suspicious = false
	suspicion_timer = suspicion_duration

func handle_suspicious_behavior(delta):
	# Search last known player position
	var direction_to_last_pos = (last_known_player_position - global_position).normalized()
	var distance_to_last_pos = global_position.distance_to(last_known_player_position)
	
	if distance_to_last_pos > 20:
		velocity = direction_to_last_pos * patrol_speed * 0.7
		print("Enemy searching last known position")
	else:
		# Arrived at last position, patrol around area
		handle_patrol_behavior(delta)
		is_suspicious = false

func handle_patrol_behavior(delta):
	# Simple patrol behavior
	patrol_timer -= delta
	
	# Change direction occasionally
	if patrol_timer <= 0:
		patrol_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		patrol_timer = randf_range(2.0, 4.0)
	
	velocity = patrol_direction * patrol_speed
	
	# Occasionally stop
	if randf() < 0.02:
		velocity = Vector2.ZERO
		patrol_timer = randf_range(0.5, 1.5)

func check_collision_with_player_fixed():
	if not player or not can_attack:
		return
	
	# Simple collision check
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider and collider.is_in_group("player"):
			print("COLLISION DETECTED WITH PLAYER!")
			
			# Attack immediately if not in light
			if not in_player_light and not has_collided_with_player:
				has_collided_with_player = true
				attack_player_simple()
				
				# Reset collision flag after short delay
				get_tree().create_timer(0.5).timeout.connect(func():
					has_collided_with_player = false
				)
			return
	
	# Reset collision flag when not touching
	has_collided_with_player = false

func attack_player_simple():
	if not player or not can_attack or in_player_light:
		print("Attack blocked - player:", player != null, " can_attack:", can_attack, " in_light:", in_player_light)
		return
		
	print("ATTACKING PLAYER FOR ", damage, " DAMAGE!")
	
	# Deal damage to player
	if player.has_method("get_damaged_by_enemy"):
		player.get_damaged_by_enemy(damage, global_position)
		print("Damage dealt via get_damaged_by_enemy")
	elif player.has_method("take_damage"):
		player.take_damage(damage, global_position)
		print("Damage dealt via take_damage")
	else:
		print("ERROR: Player has no damage methods!")
	
	# PUSHBACK SYSTEM - prevents sticking like gum
	push_back_from_player()
	
	# Attack cooldown
	can_attack = false
	get_tree().create_timer(attack_cooldown).timeout.connect(func(): 
		can_attack = true
		print("Enemy can attack again!")
	)
	
	# Visual effect
	if animated_sprite:
		animated_sprite.modulate = Color.RED * 1.5
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)

func push_back_from_player():
	if not player:
		return
	
	# Calculate pushback direction (away from player)
	var pushback_direction = (global_position - player.global_position).normalized()
	
	# If too close to calculate direction, use random direction
	if pushback_direction.length() < 0.1:
		pushback_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	# Apply strong pushback force
	var pushback_force = pushback_direction * 180.0
	velocity = pushback_force
	
	# Temporarily reduce speed to let pushback take effect
	var current_speed = speed
	speed = speed * 0.3
	
	# Restore normal speed after pushback
	get_tree().create_timer(0.6).timeout.connect(func():
		speed = current_speed
		print("Enemy pushback complete - normal speed restored")
	)
	
	print("Enemy pushed back from player after attack!")

# DAMAGE AND SLOW SYSTEM
func take_damage(damage_amount: int):
	current_health -= damage_amount
	print("Enemy took ", damage_amount, " damage! Health: ", current_health, "/", max_health)
	
	# Visual damage effect
	if animated_sprite:
		animated_sprite.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)
	
	# Check if dead
	if current_health <= 0:
		die()

func apply_slow_effect(slow_percentage: float, duration: float):
	if is_slowed:
		# If already slowed, extend the duration
		slow_effect_timer = max(slow_effect_timer, duration)
		return
	
	print("Enemy slowed by ", slow_percentage * 100, "% for ", duration, " seconds!")
	
	is_slowed = true
	slow_effect_timer = duration
	
	# Apply slow to all speed variables
	speed = original_speed * (1.0 - slow_percentage)
	patrol_speed = original_patrol_speed * (1.0 - slow_percentage)
	
	# Visual slow effect
	if animated_sprite:
		animated_sprite.modulate = Color.BLUE * 1.2
		animated_sprite.speed_scale = 0.5

func remove_slow_effect():
	if not is_slowed:
		return
		
	print("Slow effect ended - enemy speed restored!")
	
	is_slowed = false
	
	# Restore original speeds
	speed = original_speed
	patrol_speed = original_patrol_speed
	
	# Restore visual effects
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE
		animated_sprite.speed_scale = 1.0

func die():
	print("Enemy died!")
	queue_free()

func handle_player_push(collision):
	if not player:
		return
		
	var player_velocity = player.velocity
	
	if player_velocity.length() > 50:
		var push_direction = player_velocity.normalized()
		var push_strength = min(player_velocity.length() * 0.8, 150.0)
		
		velocity += push_direction * push_strength
		print("Player pushing enemy! Force: ", push_strength)
		
		if animated_sprite:
			animated_sprite.modulate = Color.YELLOW * 1.2
			var tween = create_tween()
			tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)

func push_away_from_player():
	if player:
		var push_direction = (global_position - player.global_position).normalized()
		
		if push_direction.length() < 0.1:
			push_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		
		var push_force = push_direction * 200.0
		velocity = push_force
		
		var current_speed = speed
		speed = 0
		
		get_tree().create_timer(0.8).timeout.connect(func():
			speed = current_speed
			print("Enemy movement restored after separation")
		)
		
		print("Enemy pushed back very strongly after attack")

func attack_player():
	attack_player_simple()

func attack_effect():
	if animated_sprite:
		animated_sprite.modulate = Color.RED * 1.3
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)

func update_animation():
	if not animated_sprite:
		return
	
	# Choose animation based on state and movement
	if in_player_light:
		# Frightened animation when in light
		if animated_sprite.sprite_frames.has_animation("frightened"):
			if animated_sprite.animation != "frightened":
				animated_sprite.play("frightened")
		elif velocity.length() > 10:
			# Fallback to walk animation
			if animated_sprite.sprite_frames.has_animation("walk"):
				animated_sprite.play("walk")
	elif is_chasing and velocity.length() > 10:
		# Chase animation
		if animated_sprite.sprite_frames.has_animation("chase"):
			animated_sprite.play("chase")
		elif animated_sprite.sprite_frames.has_animation("walk"):
			animated_sprite.play("walk")
	elif velocity.length() > 10:
		# Walk animation for patrol
		if animated_sprite.sprite_frames.has_animation("walk"):
			animated_sprite.play("walk")
	else:
		# Idle animation
		if animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")

# Light detection functions
func enter_light():
	print("ENEMY ENTERED LIGHT!")
	if not in_player_light:
		in_player_light = true
		velocity = Vector2.ZERO
		print("Enemy entered player's light - RETREATING!")

func exit_light():
	print("ENEMY EXITED LIGHT!")
	in_player_light = false
	retreat_cooldown = 0.0
	print("Enemy left player's light")

# Detection signals
func _on_detection_area_body_entered(body):
	print("DETECTION AREA ENTERED - Body: ", body.name if body else "NULL")
	print("Body groups: ", body.get_groups() if body else "NONE")
	print("Is in player group: ", body.is_in_group("player") if body else false)
	
	if body and body.is_in_group("player"):
		player = body
		is_chasing = true
		is_suspicious = false
		print("PLAYER DETECTED - STARTING CHASE!")
		print("Player reference set to: ", player.name)
	else:
		print("Detection triggered but not by player")

func _on_detection_area_body_exited(body):
	print("DETECTION AREA EXITED - Body: ", body.name if body else "NULL")
	
	if body and body.is_in_group("player") and body == player:
		is_chasing = false
		print("PLAYER LEFT DETECTION - STOPPING CHASE!")
		
		# Keep player reference for suspicion behavior
		if player:
			last_known_player_position = player.global_position
			is_suspicious = true
			suspicion_timer = suspicion_duration

# Debug function
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		print("=== ENEMY DEBUG INFO ===")
		print("Enemy name: ", name)
		print("Enemy position: ", global_position)
		print("Player found: ", player != null)
		if player:
			print("Player name: ", player.name)
			print("Player position: ", player.global_position)
			print("Distance to player: ", global_position.distance_to(player.global_position))
		print("Is chasing: ", is_chasing)
		print("In player light: ", in_player_light)
		print("Can attack: ", can_attack)
		print("Has collided: ", has_collided_with_player)
		print("Current velocity: ", velocity)
		print("Speed setting: ", speed)
		print("Health: ", current_health, "/", max_health)
		print("Is slowed: ", is_slowed)
		print("Groups: ", get_groups())
		
		if detection_area:
			print("Detection area monitoring: ", detection_area.monitoring)
			print("Detection collision mask: ", detection_area.collision_mask)
			var bodies = detection_area.get_overlapping_bodies()
			print("Bodies in detection area: ", bodies.size())
			for body in bodies:
				print("  - ", body.name, " Groups: ", body.get_groups())
		else:
			print("ERROR: No detection area found!")
		
		# Test if player methods exist
		if player:
			print("Player has get_damaged_by_enemy: ", player.has_method("get_damaged_by_enemy"))
			print("Player has take_damage: ", player.has_method("take_damage"))

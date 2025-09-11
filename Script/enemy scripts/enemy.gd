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

# Slow effect variables
var is_slowed: bool = false
var original_speed: float
var original_patrol_speed: float
var slow_effect_timer: float = 0.0

# POISON VARIABLES
var is_poisoned: bool = false
var poison_damage_per_tick: int = 0
var poison_tick_interval: float = 1.0
var poison_duration: float = 0.0
var poison_timer: float = 0.0
var poison_tick_timer: float = 0.0

# Health and damage system
@export var max_health: int = 100
@export var current_health: int = 100

# Death system
var is_dead: bool = false

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

# SAFE AREA LIGHT VARIABLES - NEW
var in_safe_area_light: bool = false
var fleeing_from_safe_area: bool = false
var safe_area_position: Vector2 = Vector2.ZERO
var attacks_disabled: bool = false
var safe_area_flee_speed: float = 200.0  # Faster flee speed for safe areas

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
	# If dead, don't process anything - STAY COMPLETELY STILL
	if is_dead:
		return
	
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
	
	# PRIORITY 1: Flee from safe area lights (HIGHEST PRIORITY)
	if fleeing_from_safe_area:
		handle_safe_area_flee(delta)
	# PRIORITY 2: Retreat if flashlight is ON (anywhere) or if directly in player light
	elif (player_flashlight_on and player and global_position.distance_to(player.global_position) < 300) or (in_player_light and retreat_cooldown <= 0):
		handle_smart_light_retreat(delta)
	# PRIORITY 3: Chase behavior - only if flashlight is OFF
	elif is_chasing and player and not player_flashlight_on:
		handle_chase_behavior_fixed(delta)
	# PRIORITY 4: Suspicious behavior - only if flashlight is OFF
	elif is_suspicious and not player_flashlight_on:
		handle_suspicious_behavior(delta)
	# PRIORITY 5: Patrol behavior
	else:
		handle_patrol_behavior(delta)
	
	# DAMAGE CHECK - only if flashlight is OFF and not fleeing from safe area
	if not player_flashlight_on and not fleeing_from_safe_area:
		check_collision_with_player_fixed()
	
	move_and_slide()
	
	# Update animation based on movement
	update_animation()

func handle_safe_area_flee(delta):
	"""Handle fleeing from safe area lights - HIGHEST PRIORITY"""
	print(name, " fleeing from safe area at ", safe_area_position)
	
	# Calculate flee direction (away from safe area)
	var flee_direction = (global_position - safe_area_position).normalized()
	
	# If too close to calculate direction, use random direction
	if flee_direction.length() < 0.1:
		flee_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	# Apply flee velocity at high speed
	velocity = flee_direction * safe_area_flee_speed
	
	# Add some randomness to prevent clustering
	var random_offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
	velocity += random_offset
	
	# Visual indicator - turn yellow when fleeing
	if animated_sprite:
		animated_sprite.modulate = Color.YELLOW

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
	if not player or not can_attack or attacks_disabled:
		return
	
	# Simple collision check
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider and collider.is_in_group("player"):
			print("COLLISION DETECTED WITH PLAYER!")
			
			# Attack immediately if not in light and attacks not disabled
			if not in_player_light and not in_safe_area_light and not has_collided_with_player:
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
	if not player or not can_attack or in_player_light or in_safe_area_light or attacks_disabled:
		print("Attack blocked - player:", player != null, " can_attack:", can_attack, " in_player_light:", in_player_light, " in_safe_area:", in_safe_area_light, " attacks_disabled:", attacks_disabled)
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

func take_damage(damage_amount: int, damage_source_position: Vector2 = Vector2.ZERO):
	current_health -= damage_amount
	print("Enemy took ", damage_amount, " damage! Health: ", current_health, "/", max_health)
	
	# Check if enemy will die from this damage
	var will_die = current_health <= 0
	
	# Visual damage effect - but ONLY if enemy won't die
	if animated_sprite and not will_die:
		animated_sprite.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)
	
	# Apply pushback if damage source position is provided (trap damage)
	if damage_source_position != Vector2.ZERO and not will_die:
		apply_trap_pushback(damage_source_position)
	
	# Check if dead
	if will_die:
		die()

func apply_trap_pushback(trap_position: Vector2):
	print("Enemy receiving pushback from trap at: ", trap_position)
	
	# Calculate pushback direction (away from trap)
	var pushback_direction = (global_position - trap_position).normalized()
	
	# If too close to calculate direction, use random direction
	if pushback_direction.length() < 0.1:
		pushback_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		print("Using random pushback direction")
	
	# Apply strong pushback force (stronger than normal pushback)
	var pushback_force = pushback_direction * 250.0
	velocity = pushback_force
	
	# Temporarily reduce speed to let pushback take effect
	var current_speed = speed
	var current_patrol_speed = patrol_speed
	speed = speed * 0.2  # Even slower to let trap pushback be more dramatic
	patrol_speed = patrol_speed * 0.2
	
	# Restore normal speed after pushback
	get_tree().create_timer(0.8).timeout.connect(func():
		speed = current_speed
		patrol_speed = current_patrol_speed
		print("Enemy speed restored after trap pushback")
	)
	
	# Visual effect for trap pushback
	if animated_sprite:
		animated_sprite.modulate = Color.YELLOW * 1.4
		var scale_tween = create_tween()
		scale_tween.parallel().tween_property(animated_sprite, "scale", Vector2(1.2, 1.2), 0.1)
		scale_tween.tween_property(animated_sprite, "scale", Vector2(1.0, 1.0), 0.4)
	
	print("Enemy pushed back from trap with force: ", pushback_force.length())

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
	if is_dead:
		return  # Already dead, don't run again
	
	print("Enemy died!")
	is_dead = true
	
	# IMMEDIATELY stop ALL movement and effects
	velocity = Vector2.ZERO
	
	# Kill all active tweens that might still be affecting the enemy
	var tweens = get_tree().get_processed_tweens()
	for tween in tweens:
		if tween.is_valid():
			tween.kill()
	
	# Reset all speed values to prevent any restoration timers from affecting us
	speed = 0.0
	patrol_speed = 0.0
	
	# Disable collision so dead body doesn't interfere with gameplay
	collision_layer = 0
	collision_mask = 0
	
	# Disable detection area
	if detection_area:
		detection_area.monitoring = false
		detection_area.monitorable = false
	
	# Remove from enemy group so it won't be targeted
	remove_from_group("enemy")
	add_to_group("dead_enemy")  # Add to dead group if needed for cleanup later
	
	# Reset states
	is_chasing = false
	is_suspicious = false
	can_attack = false
	in_player_light = false
	in_safe_area_light = false
	fleeing_from_safe_area = false
	is_slowed = false
	
	# Clear any ongoing effect timers
	slow_effect_timer = 0.0
	retreat_cooldown = 0.0
	
	# FORCE PLAY DEATH ANIMATION
	if animated_sprite:
		# Stop any current animation first
		animated_sprite.stop()
		
		# Check if death animation exists and play it
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("dead"):
			animated_sprite.play("dead")
			print("Playing death animation: dead")
		else:
			print("Available animations: ", animated_sprite.sprite_frames.get_animation_names() if animated_sprite.sprite_frames else "No sprite frames")
			print("WARNING: No 'dead' animation found!")
		
		# Add death visual effect after a short delay (FIXED TWEEN SYNTAX)
		var death_tween = create_tween()
		death_tween.tween_interval(1.0)  # Wait 1 second for death animation to play
		death_tween.tween_property(animated_sprite, "modulate", Color.GRAY * 0.8, 1.0)
	
	print("Enemy body will remain on the ground - all movement stopped")

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
	
	# If dead, don't change animation (keep death animation)
	if is_dead:
		return
	
	# Choose animation based on state and movement
	if fleeing_from_safe_area:
		# Special animation for fleeing from safe area
		if animated_sprite.sprite_frames.has_animation("flee"):
			if animated_sprite.animation != "flee":
				animated_sprite.play("flee")
		elif animated_sprite.sprite_frames.has_animation("run"):
			if animated_sprite.animation != "run":
				animated_sprite.play("run")
		elif velocity.length() > 10:
			if animated_sprite.sprite_frames.has_animation("walk"):
				animated_sprite.play("walk")
	elif in_player_light:
		# Frightened animation when in player light
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

# SAFE AREA LIGHT METHODS - Called by safe area script
func enter_light():
	"""Called when enemy enters the safe area light"""
	print(name, " ENTERED SAFE AREA LIGHT - FLEEING!")
	
	in_safe_area_light = true
	fleeing_from_safe_area = true
	
	# Find the nearest safe area to flee from
	find_nearest_safe_area()
	
	# Visual indicator
	if animated_sprite:
		animated_sprite.modulate = Color.YELLOW

func exit_light():
	"""Called when enemy exits the safe area light"""
	print(name, " EXITED SAFE AREA LIGHT - resuming normal behavior")
	
	in_safe_area_light = false
	fleeing_from_safe_area = false
	
	# Restore normal appearance
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE

func find_nearest_safe_area():
	"""Find the nearest safe area to flee from"""
	var safe_areas = get_tree().get_nodes_in_group("safe_areas")
	if safe_areas.is_empty():
		print("Warning: No safe areas found for fleeing")
		return
	
	var nearest_distance = INF
	for safe_area in safe_areas:
		var distance = global_position.distance_to(safe_area.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			safe_area_position = safe_area.global_position
	
	print(name, " fleeing from safe area at: ", safe_area_position)

func disable_attacks():
	"""Disable enemy attacks (called when player is in safe area)"""
	attacks_disabled = true
	print(name, " attacks DISABLED - player in safe area")

func enable_attacks():
	"""Re-enable enemy attacks (called when player leaves safe area)"""
	attacks_disabled = false
	print(name, " attacks ENABLED - player vulnerable")

# Player light detection functions (for flashlight)
func enter_player_light():
	print("ENEMY ENTERED PLAYER LIGHT!")
	if not in_player_light:
		in_player_light = true
		print("Enemy entered player's flashlight - RETREATING!")

func exit_player_light():
	print("ENEMY EXITED PLAYER LIGHT!")
	in_player_light = false
	retreat_cooldown = 0.0
	print("Enemy left player's flashlight")

# Detection signals
func _on_detection_area_body_entered(body):
	print("DETECTION AREA ENTERED - Body: ", body.name if body else "NULL")
	print("Body groups: ", body.get_groups() if body else "NONE")
	print("Is in player group: ", body.is_in_group("player") if body else false)
	
	if body and body.is_in_group("player"):
		player = body
		# Only chase if not fleeing from safe area
		if not fleeing_from_safe_area:
			is_chasing = true
			is_suspicious = false
		print("PLAYER DETECTED - Enemy response: chase=", is_chasing, " flee=", fleeing_from_safe_area)
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
		print("In safe area light: ", in_safe_area_light)
		print("Fleeing from safe area: ", fleeing_from_safe_area)
		print("Attacks disabled: ", attacks_disabled)
		print("Safe area position: ", safe_area_position)
		print("Can attack: ", can_attack)
		print("Has collided: ", has_collided_with_player)
		print("Current velocity: ", velocity)
		print("Speed setting: ", speed)
		print("Health: ", current_health, "/", max_health)
		print("Is slowed: ", is_slowed)
		print("Is poisoned: ", is_poisoned)
		if is_poisoned:
			print("  Poison damage per tick: ", poison_damage_per_tick)
			print("  Poison time remaining: ", poison_timer)
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

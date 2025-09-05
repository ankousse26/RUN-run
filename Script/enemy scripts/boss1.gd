extends CharacterBody2D

# BOSS STATS - Much more powerful than regular enemies!
@export var max_health: int = 150  # Boss has lots of health!
@export var speed: float = 90.0    # Slower but more methodical
@export var charge_speed: float = 250.0  # Super fast when charging!
@export var damage: int = 35       # Hits HARD!
@export var heavy_damage: int = 50 # Special attack damage
@export var attack_cooldown: float = 2.0
@export var charge_attack_cooldown: float = 8.0
@export var slam_attack_cooldown: float = 12.0
@export var detection_range: float = 400.0  # Sees you from far away!
@export var light_resistance: float = 0.3   # Less afraid of light!

# References
@onready var detection_area = $"DetectionRange"
@onready var animated_sprite = $AnimatedSprite2D
@onready var health_bar = $HealthBar  # Optional health bar
@onready var charge_warning = $ChargeWarning  # Visual warning for charge attack

# Boss State Variables
var current_health: int
var player: CharacterBody2D
var boss_phase: int = 1  # Phase 1, 2, or 3 (gets more aggressive)
var is_chasing: bool = false
var can_attack: bool = true
var can_charge_attack: bool = true
var can_slam_attack: bool = true
var in_player_light: bool = false
var light_fear_timer: float = 0.0

# Attack States
enum BossState {
	PATROL,
	CHASE,
	CHARGING,
	SLAM_ATTACK,
	STUNNED,
	ENRAGED
}

var current_state: BossState = BossState.PATROL
var state_timer: float = 0.0
var charge_target: Vector2
var is_charging: bool = false
var slam_preparation_time: float = 2.0
var stun_duration: float = 1.5

# Movement
var patrol_direction: Vector2 = Vector2.RIGHT
var patrol_timer: float = 0.0
var original_position: Vector2

func _ready():
	add_to_group("enemy")
	add_to_group("boss")  # Special boss group
	print("🔥 BOSS ENEMY SPAWNED! 🔥")
	
	# Initialize health
	current_health = max_health
	original_position = global_position
	
	# Setup detection area
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
		detection_area.monitoring = true
		print("Boss detection area ready!")
	
	# Setup health bar if it exists
	if health_bar:
		update_health_bar()
	
	# Boss entrance effect!
	play_spawn_effect()
	
	# Set initial patrol
	patrol_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _physics_process(delta):
	# Update state timer
	state_timer -= delta
	
	# Update boss phase based on health
	update_boss_phase()
	
	# Handle light fear (bosses are less afraid!)
	if in_player_light:
		light_fear_timer += delta
	else:
		light_fear_timer = 0.0
	
	# Main boss behavior based on current state
	match current_state:
		BossState.PATROL:
			handle_patrol(delta)
		BossState.CHASE:
			handle_chase(delta)
		BossState.CHARGING:
			handle_charge_attack(delta)
		BossState.SLAM_ATTACK:
			handle_slam_attack(delta)
		BossState.STUNNED:
			handle_stunned(delta)
		BossState.ENRAGED:
			handle_enraged_mode(delta)
	
	# Check for player collision and damage
	check_collision_with_player()
	
	move_and_slide()
	update_animation()

# BOSS PHASES - Gets more dangerous as health decreases!
func update_boss_phase():
	var health_percentage = float(current_health) / float(max_health)
	
	if health_percentage > 0.66:
		boss_phase = 1  # Calm phase
	elif health_percentage > 0.33:
		boss_phase = 2  # Aggressive phase
	else:
		boss_phase = 3  # ENRAGED PHASE!
		if current_state != BossState.ENRAGED and randf() < 0.1:
			enter_enraged_mode()

func handle_patrol(delta):
	# Boss patrols around its original position
	patrol_timer -= delta
	
	if patrol_timer <= 0:
		# Change direction every few seconds
		patrol_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		patrol_timer = randf_range(3.0, 6.0)
	
	# Don't wander too far from spawn point
	var distance_from_spawn = global_position.distance_to(original_position)
	if distance_from_spawn > 200:
		patrol_direction = (original_position - global_position).normalized()
	
	velocity = patrol_direction * (speed * 0.6)  # Slow patrol

func handle_chase(delta):
	if not player:
		current_state = BossState.PATROL
		return
	
	print("🎯 BOSS CHASING PLAYER!")
	
	# Boss decides which attack to use based on distance and cooldowns
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# CHARGE ATTACK - if far away and can charge
	if distance_to_player > 150 and can_charge_attack and boss_phase >= 2:
		start_charge_attack()
		return
	
	# SLAM ATTACK - if close and can slam
	if distance_to_player < 100 and can_slam_attack and boss_phase >= 2:
		start_slam_attack()
		return
	
	# Regular chase - but avoid light if afraid
	var chase_direction = (player.global_position - global_position).normalized()
	
	# Boss is less afraid of light but still avoids it sometimes
	if in_player_light and light_fear_timer < light_resistance:
		# Mix retreat with chase (boss fights the light!)
		var retreat_direction = (global_position - player.global_position).normalized()
		chase_direction = chase_direction.lerp(retreat_direction, 0.3)
	
	velocity = chase_direction * speed * get_phase_speed_multiplier()

func start_charge_attack():
	print("⚡ BOSS PREPARING CHARGE ATTACK! ⚡")
	current_state = BossState.CHARGING
	state_timer = 1.5  # Preparation time
	can_charge_attack = false
	
	# Set charge target to player's current position
	if player:
		charge_target = player.global_position
	
	# Visual warning effect
	show_charge_warning()
	
	# Screen shake warning
	shake_screen(0.5, 3.0)
	
	# Start charge attack cooldown
	get_tree().create_timer(charge_attack_cooldown).timeout.connect(func(): 
		can_charge_attack = true
		print("Boss can charge again!")
	)

func handle_charge_attack(delta):
	if state_timer > 0:
		# Preparation phase - slow down and show warning
		velocity = velocity.lerp(Vector2.ZERO, delta * 3.0)
		
		# Flash red during preparation
		if animated_sprite:
			animated_sprite.modulate = Color.YELLOW * 1.5
		
		print("Boss charging up... ", state_timer)
	else:
		# CHARGE! Super fast movement toward target
		print("💥 BOSS CHARGING! 💥")
		var charge_direction = (charge_target - global_position).normalized()
		velocity = charge_direction * charge_speed
		
		# Check if reached target or hit wall
		var distance_to_target = global_position.distance_to(charge_target)
		if distance_to_target < 30 or is_on_wall():
			# End charge attack
			print("Charge attack complete!")
			current_state = BossState.STUNNED  # Brief stun after missing
			state_timer = stun_duration * 0.5
			velocity = Vector2.ZERO
			
			# Return to normal color
			if animated_sprite:
				animated_sprite.modulate = Color.WHITE

func start_slam_attack():
	print("🔨 BOSS PREPARING SLAM ATTACK! 🔨")
	current_state = BossState.SLAM_ATTACK
	state_timer = slam_preparation_time
	can_slam_attack = false
	velocity = Vector2.ZERO  # Stop moving during slam prep
	
	# Visual effect - boss grows bigger
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "scale", Vector2(1.3, 1.3), slam_preparation_time)
	
	# Start slam cooldown
	get_tree().create_timer(slam_attack_cooldown).timeout.connect(func(): 
		can_slam_attack = true
		print("Boss can slam again!")
	)

func handle_slam_attack(delta):
	if state_timer > 0:
		# Preparation - flash and shake
		if animated_sprite:
			animated_sprite.modulate = Color.RED * (1.0 + sin(state_timer * 20) * 0.3)
		
		# Shake screen during preparation
		shake_screen(0.2, 1.0)
	else:
		# SLAM!
		execute_slam_attack()
		current_state = BossState.CHASE  # Return to chase
		
		# Reset sprite
		if animated_sprite:
			animated_sprite.modulate = Color.WHITE
			var tween = create_tween()
			tween.tween_property(animated_sprite, "scale", Vector2(1.0, 1.0), 0.3)

func execute_slam_attack():
	print("💥 BOSS SLAM ATTACK! 💥")
	
	# Massive screen shake
	shake_screen(1.0, 8.0)
	
	# Damage all players in a large radius
	var slam_radius = 120.0
	if player and global_position.distance_to(player.global_position) < slam_radius:
		print("Player hit by slam attack!")
		damage_player(heavy_damage, "slam")
	
	# Create visual effect
	create_slam_shockwave()

func handle_stunned(delta):
	# Boss is briefly vulnerable after certain attacks
	velocity = Vector2.ZERO
	
	if animated_sprite:
		animated_sprite.modulate = Color.CYAN * 0.7
	
	if state_timer <= 0:
		current_state = BossState.CHASE
		if animated_sprite:
			animated_sprite.modulate = Color.WHITE

func enter_enraged_mode():
	print("🔥 BOSS ENTERS ENRAGED MODE! 🔥")
	current_state = BossState.ENRAGED
	state_timer = 8.0  # Stay enraged for 8 seconds
	
	# Visual effect
	if animated_sprite:
		animated_sprite.modulate = Color.RED * 1.8
	
	# Massive screen shake
	shake_screen(2.0, 15.0)

func handle_enraged_mode(delta):
	# Boss moves faster and attacks more frequently!
	if not player:
		current_state = BossState.PATROL
		return
	
	# Super aggressive chase
	var chase_direction = (player.global_position - global_position).normalized()
	velocity = chase_direction * speed * 1.8  # Much faster!
	
	# Ignore light fear completely
	light_fear_timer = 0
	
	# Attack very frequently
	if can_attack and global_position.distance_to(player.global_position) < 80:
		attack_player_enraged()
	
	# Exit enraged mode
	if state_timer <= 0:
		current_state = BossState.CHASE
		if animated_sprite:
			animated_sprite.modulate = Color.WHITE
		print("Boss calming down from enrage...")

func get_phase_speed_multiplier() -> float:
	match boss_phase:
		1: return 1.0      # Normal speed
		2: return 1.3      # 30% faster
		3: return 1.6      # 60% faster!
		_: return 1.0

func check_collision_with_player():
	if not player or not can_attack:
		return
	
	# Check for collision with player
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider and collider.is_in_group("player"):
			print("💥 BOSS HIT PLAYER! 💥")
			attack_player_normal()
			return

func attack_player_normal():
	if not can_attack or (in_player_light and light_fear_timer < light_resistance * 2):
		return
	
	print("🗡️ BOSS NORMAL ATTACK! 🗡️")
	damage_player(damage, "normal")
	
	# Attack cooldown
	can_attack = false
	get_tree().create_timer(attack_cooldown).timeout.connect(func(): 
		can_attack = true
	)

func attack_player_enraged():
	print("🔥 BOSS ENRAGED ATTACK! 🔥")
	damage_player(damage + 15, "enraged")
	
	# Shorter cooldown when enraged
	can_attack = false
	get_tree().create_timer(attack_cooldown * 0.5).timeout.connect(func(): 
		can_attack = true
	)

func damage_player(damage_amount: int, attack_type: String):
	if not player:
		return
	
	# Deal damage to player
	if player.has_method("get_damaged_by_enemy"):
		player.get_damaged_by_enemy(damage_amount, global_position)
	elif player.has_method("take_damage"):
		player.take_damage(damage_amount, global_position)
	
	# Visual effect based on attack type
	if animated_sprite:
		var flash_color = Color.RED
		match attack_type:
			"slam": flash_color = Color.PURPLE
			"enraged": flash_color = Color.ORANGE
			"charge": flash_color = Color.YELLOW
		
		animated_sprite.modulate = flash_color * 2.0
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.4)
	
	# Screen shake based on attack power
	var shake_power = damage_amount / 10.0
	shake_screen(0.3, shake_power)

func take_damage(damage_amount: int, from_position: Vector2 = Vector2.ZERO):
	print("🩸 BOSS TAKES ", damage_amount, " DAMAGE! 🩸")
	current_health -= damage_amount
	
	# Update health bar
	update_health_bar()
	
	# Flash white when hit
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE * 2.0
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)
	
	# Check if boss is defeated
	if current_health <= 0:
		boss_defeated()
	else:
		# Boss gets angry when hit!
		if randf() < 0.3:  # 30% chance to enrage when hit
			enter_enraged_mode()

func boss_defeated():
	print("💀 BOSS DEFEATED! 💀")
	
	# Epic death animation
	if animated_sprite:
		var death_tween = create_tween()
		death_tween.set_parallel(true)
		
		# Flash colors rapidly
		for i in range(10):
			death_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1).set_delay(i * 0.1)
			death_tween.tween_property(animated_sprite, "modulate", Color.RED, 0.1).set_delay(i * 0.1 + 0.05)
		
		# Grow then shrink
		death_tween.tween_property(animated_sprite, "scale", Vector2(2.0, 2.0), 1.0)
		death_tween.tween_property(animated_sprite, "scale", Vector2(0, 0), 0.5).set_delay(1.0)
		death_tween.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(1.0)
	
	# Massive final screen shake
	shake_screen(2.0, 20.0)
	
	# Create explosion effect
	create_death_explosion()
	
	# Remove boss after animation
	get_tree().create_timer(2.0).timeout.connect(queue_free)

# VISUAL EFFECTS

func play_spawn_effect():
	print("👹 BOSS SPAWNING WITH EPIC EFFECT! 👹")
	if animated_sprite:
		animated_sprite.modulate = Color.TRANSPARENT
		animated_sprite.scale = Vector2(0, 0)
		
		var spawn_tween = create_tween()
		spawn_tween.set_parallel(true)
		spawn_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 1.0)
		spawn_tween.tween_property(animated_sprite, "scale", Vector2(1, 1), 1.0).set_trans(Tween.TRANS_BACK)
	
	shake_screen(1.5, 10.0)

func show_charge_warning():
	if charge_warning:
		charge_warning.visible = true
		var warning_tween = create_tween()
		warning_tween.set_loops(3)
		warning_tween.tween_property(charge_warning, "modulate:a", 1.0, 0.2)
		warning_tween.tween_property(charge_warning, "modulate:a", 0.0, 0.2)
		
		get_tree().create_timer(1.5).timeout.connect(func(): 
			if charge_warning:
				charge_warning.visible = false
		)

func create_slam_shockwave():
	# Create visual shockwave effect
	var shockwave = ColorRect.new()
	get_parent().add_child(shockwave)
	shockwave.color = Color.YELLOW * 0.5
	shockwave.global_position = global_position - Vector2(60, 60)
	shockwave.size = Vector2(120, 120)
	
	var shockwave_tween = create_tween()
	shockwave_tween.set_parallel(true)
	shockwave_tween.tween_property(shockwave, "size", Vector2(300, 300), 0.5)
	shockwave_tween.tween_property(shockwave, "global_position", global_position - Vector2(150, 150), 0.5)
	shockwave_tween.tween_property(shockwave, "modulate:a", 0.0, 0.5)
	
	get_tree().create_timer(0.5).timeout.connect(shockwave.queue_free)

func create_death_explosion():
	# Create multiple explosion particles
	for i in range(8):
		var explosion = CPUParticles2D.new()
		get_parent().add_child(explosion)
		explosion.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		explosion.emitting = true
		explosion.amount = 20
		explosion.lifetime = 2.0
		explosion.one_shot = true
		explosion.initial_velocity_min = 50
		explosion.initial_velocity_max = 150
		explosion.spread = 360
		explosion.color = Color.ORANGE
		explosion.scale_amount_min = 0.5
		explosion.scale_amount_max = 2.0
		
		get_tree().create_timer(3.0).timeout.connect(explosion.queue_free)

func shake_screen(duration: float, strength: float):
	# This function should be called on the camera or game manager
	# For now, we'll just print it - you can connect this to your camera system
	print("📳 SCREEN SHAKE: Duration=", duration, " Strength=", strength)

func update_health_bar():
	if health_bar:
		var health_percentage = float(current_health) / float(max_health)
		health_bar.value = health_percentage * 100
		
		# Change color based on health
		if health_percentage > 0.6:
			health_bar.modulate = Color.GREEN
		elif health_percentage > 0.3:
			health_bar.modulate = Color.YELLOW
		else:
			health_bar.modulate = Color.RED

func update_animation():
	if not animated_sprite:
		return
	
	# Choose animation based on current state using YOUR available animations!
	match current_state:
		BossState.PATROL:
			if velocity.length() > 10:
				play_animation("RUN")  # Use your RUN animation for patrol movement
			else:
				play_animation("IDEL")  # Use your IDEL animation (or rename to IDLE)
		BossState.CHASE:
			play_animation("RUN")  # RUN animation works great for chasing!
		BossState.CHARGING:
			# For charging, we can use IDLE during prep, then RUN during charge
			if state_timer > 0:  # Preparation phase
				play_animation("IDEL")
			else:  # Actually charging
				play_animation("RUN")
		BossState.SLAM_ATTACK:
			play_animation("IDEL")  # Stop moving during slam prep
		BossState.STUNNED:
			play_animation("IDEL")  # Idle when stunned
		BossState.ENRAGED:
			play_animation("RUN")  # Fast running when enraged!

func play_animation(animation_name: String):
	if animated_sprite and animated_sprite.sprite_frames.has_animation(animation_name):
		if animated_sprite.animation != animation_name:
			animated_sprite.play(animation_name)
	else:
		print("⚠️ Animation not found: ", animation_name)

# Light detection (boss is more resistant to light!)
func enter_light():
	print("💡 Boss entered light - but boss is resistant!")
	in_player_light = true

func exit_light():
	print("🌙 Boss exited light")
	in_player_light = false
	light_fear_timer = 0.0

# Detection signals
func _on_detection_area_body_entered(body):
	print("👁️ BOSS DETECTS: ", body.name if body else "NULL")
	
	if body and body.is_in_group("player"):
		player = body
		is_chasing = true
		current_state = BossState.CHASE
		print("🎯 BOSS LOCKED ONTO PLAYER!")

func _on_detection_area_body_exited(body):
	print("👁️ BOSS LOST SIGHT OF: ", body.name if body else "NULL")
	
	if body and body.is_in_group("player") and body == player:
		is_chasing = false
		print("🌙 Player escaped boss detection")
		
		# Boss doesn't give up easily - keeps chasing for a while
		get_tree().create_timer(5.0).timeout.connect(func():
			if not is_chasing:
				current_state = BossState.PATROL
				print("Boss giving up chase...")
		)

# Debug function
func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC key
		print("=== 👹 BOSS DEBUG INFO 👹 ===")
		print("Boss Health: ", current_health, "/", max_health)
		print("Boss Phase: ", boss_phase)
		print("Current State: ", BossState.keys()[current_state])
		print("Is Chasing: ", is_chasing)
		print("In Light: ", in_player_light)
		print("Light Fear Timer: ", light_fear_timer)
		print("Can Attack: ", can_attack)
		print("Can Charge: ", can_charge_attack)
		print("Can Slam: ", can_slam_attack)

extends Node2D

# Laser trap settings - adjust these in the inspector
@export var damage_amount: int = 25
@export var attack_cooldown: float = 2.0      # Time between laser attacks
@export var trap_activation_delay: float = 0.5  # Small delay before first laser shot

# References
@onready var detect_area = $Detect
@onready var animated_sprite = $AnimatedSprite2D
@onready var laser_beam = $LaserBeam
@onready var laser_particles = $LaserParticles
@onready var charge_particles = $ChargeParticles

# Variables
var enemies_in_range = {}  # Track enemies and their attack timers
var is_trap_active: bool = false
var idle_timer: float = 0.0  # Timer for switching back to idle
var idle_delay: float = 2.0  # Wait 2 seconds before going back to idle

func _ready():
	print("Laser trap initialized: ", name)
	
	# Connect signals
	if detect_area:
		detect_area.body_entered.connect(_on_body_entered)
		detect_area.body_exited.connect(_on_body_exited)
		detect_area.monitoring = true
		print("Laser detection area connected successfully")
		
		# Debug collision setup
		print("Laser detection collision mask: ", detect_area.collision_mask)
		print("Laser detection collision layer: ", detect_area.collision_layer)
	else:
		print("ERROR: detect_area not found in laser trap!")
	
	# Start with idle animation
	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
		else:
			print("Warning: No 'idle' animation found for laser trap")
	else:
		print("ERROR: AnimatedSprite2D not found in laser trap!")
	
	# Initialize laser beam if it exists
	if laser_beam:
		laser_beam.visible = false
		print("Laser beam initialized")
	
	# Initialize particle systems if they exist
	if charge_particles:
		charge_particles.emitting = false
		print("Charge particles initialized")
	
	if laser_particles:
		laser_particles.emitting = false
		print("Laser particles initialized")

func _physics_process(delta):
	# Handle continuous laser attacks for enemies in range
	var enemies_to_remove = []
	
	for enemy in enemies_in_range.keys():
		if is_instance_valid(enemy) and is_enemy_alive(enemy):
			enemies_in_range[enemy] -= delta
			
			# Time to laser this enemy again
			if enemies_in_range[enemy] <= 0:
				fire_laser_at_enemy(enemy)
				enemies_in_range[enemy] = attack_cooldown
		else:
			# Mark enemy for removal (dead or invalid)
			enemies_to_remove.append(enemy)
			if is_instance_valid(enemy):
				print("Enemy died, removing from laser trap: ", enemy.name)
			else:
				print("Removed invalid enemy reference from laser trap")
	
	# Remove dead/invalid enemies from tracking
	for enemy in enemies_to_remove:
		enemies_in_range.erase(enemy)
	
	# Handle idle timer logic
	var has_enemies = enemies_in_range.size() > 0
	
	if has_enemies:
		# Reset idle timer when enemies are present
		idle_timer = 0.0
		if not is_trap_active:
			is_trap_active = true
			update_trap_animation()
	else:
		# No enemies - start counting down to idle
		if is_trap_active:
			idle_timer += delta
			if idle_timer >= idle_delay:
				is_trap_active = false
				update_trap_animation()
				print("Laser trap going back to idle after ", idle_delay, " seconds")

func _on_body_entered(body):
	print("Body entered laser trap range: ", body.name if body else "NULL")
	print("Body groups: ", body.get_groups() if body else "NONE")
	
	if body and body.is_in_group("enemy") and is_enemy_alive(body):
		print("Living enemy entered laser range: ", body.name)
		
		# Add enemy to tracking with initial delay
		enemies_in_range[body] = trap_activation_delay
		
		# Update animation immediately
		update_trap_animation()
		
		# Visual activation effect
		create_activation_effect()
		
		print("Enemy added to laser range. Total enemies in range: ", enemies_in_range.size())
	elif body and body.is_in_group("enemy"):
		print("Dead enemy entered laser range (ignored): ", body.name)
	else:
		print("Non-enemy body entered laser range (ignored)")

func _on_body_exited(body):
	print("Body exited laser trap range: ", body.name if body else "NULL")
	
	if body and body.is_in_group("enemy"):
		print("Enemy left laser range: ", body.name)
		
		# Remove from tracking
		if body in enemies_in_range:
			enemies_in_range.erase(body)
			print("Enemy removed from laser range. Remaining enemies: ", enemies_in_range.size())
		
		# Don't update animation immediately - let the timer handle it

func is_enemy_alive(enemy) -> bool:
	"""Check if an enemy is still alive and should be targeted"""
	if not is_instance_valid(enemy):
		return false
	
	# Check common death indicators
	# Method 1: Check if enemy has health and it's > 0
	if enemy.has_method("get_health"):
		return enemy.get_health() > 0
	elif "health" in enemy:
		return enemy.health > 0
	elif "current_health" in enemy:
		return enemy.current_health > 0
	
	# Method 2: Check for is_dead property/method
	if enemy.has_method("is_alive"):
		return enemy.is_alive()
	elif enemy.has_method("is_dead"):
		return not enemy.is_dead()
	elif "is_dead" in enemy:
		return not enemy.is_dead
	elif "dead" in enemy:
		return not enemy.dead
	
	# Method 3: Check if enemy is in "dead" group
	if enemy.is_in_group("dead"):
		return false
	
	# Method 4: Check if enemy is being freed
	if enemy.is_queued_for_deletion():
		return false
	
	# If no death indicators found, assume alive
	return true

func fire_laser_at_enemy(enemy):
	if not is_instance_valid(enemy):
		print("Tried to laser invalid enemy - removing from range")
		return
	
	if not is_enemy_alive(enemy):
		print("Enemy is dead, stopping laser attack: ", enemy.name)
		return
	
	print("Laser trap firing at enemy: ", enemy.name)
	

	
	# Create laser beam to target
	create_laser_beam_to_target(enemy.global_position)
	

	
	# Deal damage (this automatically handles pushback)
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage_amount, global_position)
		print("Laser dealt ", damage_amount, " damage to ", enemy.name)
	else:
		print("ERROR: Enemy has no take_damage method!")
	
	# Visual effects
	create_laser_effect()

func update_trap_animation():
	if not animated_sprite:
		return
	
	if is_trap_active:
		# Laser is active - play attack animation
		if animated_sprite.sprite_frames.has_animation("attack"):
			if animated_sprite.animation != "attack":
				animated_sprite.play("attack")
				print("Laser trap activated - playing attack animation")
		else:
			print("Warning: No 'attack' animation found for laser trap")
	else:
		# Laser is inactive - play idle animation
		if animated_sprite.sprite_frames.has_animation("idle"):
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
				print("Laser trap deactivated - playing idle animation")

func create_activation_effect():
	if not animated_sprite:
		return
	
	# Red glow when laser activates
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.RED * 1.4, 0.1)
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)

func create_laser_effect():
	if not animated_sprite:
		return
	
	# Bright flash when firing laser
	var tween = create_tween()
	tween.parallel().tween_property(animated_sprite, "modulate", Color.WHITE * 1.8, 0.1)
	tween.parallel().tween_property(animated_sprite, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)
	tween.parallel().tween_property(animated_sprite, "scale", Vector2(1.0, 1.0), 0.2)

# SIMPLE VISUAL EFFECT FUNCTIONS

func create_laser_beam_to_target(target_position: Vector2):
	"""Creates a simple laser beam from trap to target"""
	if not laser_beam:
		return
	
	# Set beam points from trap center to target
	laser_beam.clear_points()
	laser_beam.add_point(Vector2.ZERO)  # Start at trap center
	laser_beam.add_point(to_local(target_position))  # End at target
	
	# Simple beam appearance
	laser_beam.visible = true
	laser_beam.width = 3.0
	laser_beam.default_color = Color.RED
	
	# Hide beam quickly
	get_tree().create_timer(0.1).timeout.connect(func(): 
		if laser_beam:
			laser_beam.visible = false
	)

# Debug function
func _input(event):
	if event.is_action_pressed("ui_select"):  # Space key for debug
		print("=== LASER TRAP DEBUG INFO ===")
		print("Laser name: ", name)
		print("Laser position: ", global_position)
		print("Is active: ", is_trap_active)
		print("Idle timer: ", idle_timer, "/", idle_delay)
		print("Enemies in range: ", enemies_in_range.size())
		print("Damage amount: ", damage_amount)
		print("Attack cooldown: ", attack_cooldown)
		
		for enemy in enemies_in_range.keys():
			if is_instance_valid(enemy):
				print("  - Enemy: ", enemy.name, " | Next laser in: ", enemies_in_range[enemy], "s")
			else:
				print("  - Invalid enemy reference found")
		
		if detect_area:
			print("Detection area monitoring: ", detect_area.monitoring)
			print("Detection collision mask: ", detect_area.collision_mask)
			var bodies = detect_area.get_overlapping_bodies()
			print("Bodies currently overlapping: ", bodies.size())
			for body in bodies:
				print("  - ", body.name, " | Groups: ", body.get_groups())
		else:
			print("ERROR: No detection area found!")
		
		if animated_sprite:
			print("Current animation: ", animated_sprite.animation)
			print("Available animations: ", animated_sprite.sprite_frames.get_animation_names() if animated_sprite.sprite_frames else "No sprite frames")
		else:
			print("ERROR: No animated sprite found!")

# Optional: Add a method to manually trigger the laser (useful for testing)
func trigger_laser_effect(target_body):
	if target_body and target_body.is_in_group("enemy"):
		fire_laser_at_enemy(target_body)
		print("Manually triggered laser effect on: ", target_body.name)

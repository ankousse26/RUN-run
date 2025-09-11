extends Node2D

# Tornado trap settings - adjust these in the inspector
@export var damage_amount: int = 20
@export var knockback_force: float = 300.0    # Force to push enemies away
@export var knockback_duration: float = 0.5   # How long the knockback lasts
@export var damage_cooldown: float = 1.5      # Time between damage/knockback while in tornado
@export var trap_activation_delay: float = 0.3  # Small delay before first damage/knockback

# References
@onready var detect_area = $Area2D
@onready var animated_sprite = $AnimatedSprite2D

# Variables
var enemies_in_trap = {}  # Track enemies and their damage timers
var is_trap_active: bool = false

func _ready():
	print("Tornado trap initialized: ", name)
	
	# Connect signals
	if detect_area:
		detect_area.body_entered.connect(_on_body_entered)
		detect_area.body_exited.connect(_on_body_exited)
		detect_area.monitoring = true
		print("Tornado detection area connected successfully")
		
		# Debug collision setup
		print("Tornado detection collision mask: ", detect_area.collision_mask)
		print("Tornado detection collision layer: ", detect_area.collision_layer)
	else:
		print("ERROR: detect_area not found in tornado trap!")
	
	# Start with idle animation
	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
		else:
			print("Warning: No 'idle' animation found for tornado trap")
	else:
		print("ERROR: AnimatedSprite2D not found in tornado trap!")

func _physics_process(delta):
	# Handle continuous damage and knockback for enemies in the tornado
	for enemy in enemies_in_trap.keys():
		if is_instance_valid(enemy):
			enemies_in_trap[enemy] -= delta
			
			# Time to damage and knockback this enemy again
			if enemies_in_trap[enemy] <= 0:
				damage_and_knockback_enemy(enemy)
				enemies_in_trap[enemy] = damage_cooldown
		else:
			# Remove invalid enemy references
			enemies_in_trap.erase(enemy)
			print("Removed invalid enemy reference from tornado")
	
	# Check if trap should be active
	var should_be_active = enemies_in_trap.size() > 0
	if should_be_active != is_trap_active:
		is_trap_active = should_be_active
		update_trap_animation()

func _on_body_entered(body):
	print("Body entered tornado trap: ", body.name if body else "NULL")
	print("Body groups: ", body.get_groups() if body else "NONE")
	
	if body and body.is_in_group("enemy"):
		print("Enemy caught in tornado: ", body.name)
		
		# Add enemy to tracking with initial delay
		enemies_in_trap[body] = trap_activation_delay
		
		# Update animation immediately
		update_trap_animation()
		
		# Visual activation effect
		create_activation_effect()
		
		print("Enemy added to tornado. Total enemies in tornado: ", enemies_in_trap.size())
	else:
		print("Non-enemy body entered tornado (ignored)")

func _on_body_exited(body):
	print("Body exited tornado trap: ", body.name if body else "NULL")
	
	if body and body.is_in_group("enemy"):
		print("Enemy escaped tornado: ", body.name)
		
		# Remove from tracking
		if body in enemies_in_trap:
			enemies_in_trap.erase(body)
			print("Enemy removed from tornado. Remaining enemies: ", enemies_in_trap.size())
		
		# Don't update animation immediately - let the timer handle it

func damage_and_knockback_enemy(enemy):
	if not is_instance_valid(enemy):
		print("Tried to damage invalid enemy - removing from tornado")
		return
	
	print("Tornado attacking enemy: ", enemy.name)
	
	# Deal damage
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage_amount)
		print("Tornado dealt ", damage_amount, " damage to ", enemy.name)
	else:
		print("ERROR: Enemy has no take_damage method!")
	
	# Apply knockback effect
	apply_knockback_to_enemy(enemy)
	
	# Visual effects
	create_damage_effect()

func apply_knockback_to_enemy(enemy):
	if not is_instance_valid(enemy):
		return
	
	# Calculate direction away from tornado center
	var knockback_direction = (enemy.global_position - global_position).normalized()
	
	# Apply knockback force
	if enemy.has_method("apply_knockback"):
		# If enemy has a dedicated knockback method
		enemy.apply_knockback(knockback_direction * knockback_force, knockback_duration)
		print("Tornado knocked back ", enemy.name, " with force ", knockback_force)
	elif enemy.has_method("set_velocity") or "velocity" in enemy:
		# If enemy has velocity property (common in CharacterBody2D)
		if enemy.has_method("set_velocity"):
			enemy.set_velocity(knockback_direction * knockback_force)
		else:
			enemy.velocity = knockback_direction * knockback_force
		print("Tornado pushed ", enemy.name, " away with velocity knockback")
	elif enemy.has_method("apply_impulse"):
		# For RigidBody2D enemies
		enemy.apply_impulse(knockback_direction * knockback_force)
		print("Tornado applied impulse to ", enemy.name)
	else:
		# Fallback: try to move the enemy directly
		var knockback_distance = knockback_force * 0.1  # Convert force to distance
		var target_position = enemy.global_position + (knockback_direction * knockback_distance)
		
		# Create a tween to push the enemy
		var tween = create_tween()
		tween.tween_property(enemy, "global_position", target_position, knockback_duration)
		
		print("Tornado pushed ", enemy.name, " using position tween fallback")

func update_trap_animation():
	if not animated_sprite:
		return
	
	if is_trap_active:
		# Tornado is active - play attack animation
		if animated_sprite.sprite_frames.has_animation("attack"):
			if animated_sprite.animation != "attack":
				animated_sprite.play("attack")
				print("Tornado activated - playing attack animation")
		else:
			print("Warning: No 'attack' animation found for tornado trap")
	else:
		# Tornado is inactive - play idle animation
		if animated_sprite.sprite_frames.has_animation("idle"):
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
				print("Tornado deactivated - playing idle animation")

func create_activation_effect():
	if not animated_sprite:
		return
	
	# Swirling effect when tornado activates
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.CYAN * 1.4, 0.1)
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)

func create_damage_effect():
	if not animated_sprite:
		return
	
	# Wind/force effect when dealing damage
	var tween = create_tween()
	tween.parallel().tween_property(animated_sprite, "modulate", Color.WHITE * 1.6, 0.1)
	tween.parallel().tween_property(animated_sprite, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)
	tween.parallel().tween_property(animated_sprite, "scale", Vector2(1.0, 1.0), 0.2)

# Debug function
func _input(event):
	if event.is_action_pressed("ui_select"):  # Space key for debug
		print("=== TORNADO TRAP DEBUG INFO ===")
		print("Tornado name: ", name)
		print("Tornado position: ", global_position)
		print("Is active: ", is_trap_active)
		print("Enemies in tornado: ", enemies_in_trap.size())
		print("Damage amount: ", damage_amount)
		print("Knockback force: ", knockback_force)
		print("Knockback duration: ", knockback_duration)
		
		for enemy in enemies_in_trap.keys():
			if is_instance_valid(enemy):
				print("  - Enemy: ", enemy.name, " | Next attack in: ", enemies_in_trap[enemy], "s")
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

# Optional: Add a method to manually trigger the tornado effect (useful for testing)
func trigger_tornado_effect(target_body):
	if target_body and target_body.is_in_group("enemy"):
		damage_and_knockback_enemy(target_body)
		print("Manually triggered tornado effect on: ", target_body.name)

# Optional: Method to create a wind particle effect around enemies
func create_wind_particles_around_enemy(enemy):
	# This is where you could add particle effects
	# For now, just a placeholder
	print("Creating wind particles around: ", enemy.name if enemy else "unknown")

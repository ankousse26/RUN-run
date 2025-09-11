extends Node2D

# Trap settings - adjust these in the inspector
@export var damage_amount: int = 15
@export var slow_percentage: float = 0.6  # 60% speed reduction
@export var slow_duration: float = 4.0    # 4 seconds of slow effect
@export var damage_cooldown: float = 1.0  # Time between damage ticks while on trap
@export var trap_activation_delay: float = 0.2  # Small delay before first damage

# References
@onready var detect_area = $detect_area
@onready var animated_sprite = $AnimatedSprite2D

# Variables
var enemies_in_trap = {}  # Track enemies and their damage timers
var is_trap_active: bool = false

func _ready():
	print("Spike trap initialized: ", name)
	
	# Connect signals
	if detect_area:
		detect_area.body_entered.connect(_on_body_entered)
		detect_area.body_exited.connect(_on_body_exited)
		detect_area.monitoring = true
		print("Trap detection area connected successfully")
		
		# Debug collision setup
		print("Trap detection collision mask: ", detect_area.collision_mask)
		print("Trap detection collision layer: ", detect_area.collision_layer)
	else:
		print("ERROR: detect_area not found in spike trap!")
	
	# Start with idle animation
	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
		else:
			print("Warning: No 'idle' animation found for spike trap")
	else:
		print("ERROR: AnimatedSprite2D not found in spike trap!")

func _physics_process(delta):
	# Handle continuous damage for enemies on the trap
	for enemy in enemies_in_trap.keys():
		if is_instance_valid(enemy):
			enemies_in_trap[enemy] -= delta
			
			# Time to damage this enemy again
			if enemies_in_trap[enemy] <= 0:
				damage_and_slow_enemy(enemy)
				enemies_in_trap[enemy] = damage_cooldown
		else:
			# Remove invalid enemy references
			enemies_in_trap.erase(enemy)
			print("Removed invalid enemy reference from trap")
	
	# Check if trap should be active
	var should_be_active = enemies_in_trap.size() > 0
	if should_be_active != is_trap_active:
		is_trap_active = should_be_active
		update_trap_animation()

func _on_body_entered(body):
	print("Body entered spike trap: ", body.name if body else "NULL")
	print("Body groups: ", body.get_groups() if body else "NONE")
	
	if body and body.is_in_group("enemy"):
		print("Enemy stepped on spike trap: ", body.name)
		
		# Add enemy to tracking with initial delay
		enemies_in_trap[body] = trap_activation_delay
		
		# Update animation immediately
		update_trap_animation()
		
		# Visual activation effect
		create_activation_effect()
		
		print("Enemy added to trap. Total enemies on trap: ", enemies_in_trap.size())
	else:
		print("Non-enemy body entered trap (ignored)")

func _on_body_exited(body):
	print("Body exited spike trap: ", body.name if body else "NULL")
	
	if body and body.is_in_group("enemy"):
		print("Enemy left spike trap: ", body.name)
		
		# Remove from tracking
		if body in enemies_in_trap:
			enemies_in_trap.erase(body)
			print("Enemy removed from trap. Remaining enemies: ", enemies_in_trap.size())
		
		# Update animation
		update_trap_animation()

func damage_and_slow_enemy(enemy):
	if not is_instance_valid(enemy):
		print("Tried to damage invalid enemy - removing from trap")
		return
	
	print("Spike trap attacking enemy: ", enemy.name)
	
	# Deal damage
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage_amount)
		print("Spike trap dealt ", damage_amount, " damage to ", enemy.name)
	else:
		print("ERROR: Enemy has no take_damage method!")
	
	# Apply slow effect
	if enemy.has_method("apply_slow_effect"):
		enemy.apply_slow_effect(slow_percentage, slow_duration)
		print("Spike trap slowed ", enemy.name, " by ", slow_percentage * 100, "% for ", slow_duration, " seconds")
	else:
		print("ERROR: Enemy has no apply_slow_effect method!")
	
	# Visual effects
	create_damage_effect()

func update_trap_animation():
	if not animated_sprite:
		return
	
	if is_trap_active:
		# Trap is active - play attack animation
		if animated_sprite.sprite_frames.has_animation("attack"):
			if animated_sprite.animation != "attack":
				animated_sprite.play("attack")
				print("Spike trap activated - playing attack animation")
		else:
			print("Warning: No 'attack' animation found for spike trap")
	else:
		# Trap is inactive - play idle animation
		if animated_sprite.sprite_frames.has_animation("idle"):
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
				print("Spike trap deactivated - playing idle animation")

func create_activation_effect():
	if not animated_sprite:
		return
	
	# Quick flash when trap activates
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.YELLOW * 1.3, 0.1)
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)

func create_damage_effect():
	if not animated_sprite:
		return
	
	# Red flash when dealing damage
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.RED * 1.5, 0.1)
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)

# Debug function
func _input(event):
	if event.is_action_pressed("ui_select"):  # Space key for debug
		print("=== SPIKE TRAP DEBUG INFO ===")
		print("Trap name: ", name)
		print("Trap position: ", global_position)
		print("Is active: ", is_trap_active)
		print("Enemies on trap: ", enemies_in_trap.size())
		print("Damage amount: ", damage_amount)
		print("Slow percentage: ", slow_percentage)
		print("Slow duration: ", slow_duration)
		
		for enemy in enemies_in_trap.keys():
			if is_instance_valid(enemy):
				print("  - Enemy: ", enemy.name, " | Next damage in: ", enemies_in_trap[enemy], "s")
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

# Optional: Add a method to manually trigger the trap (useful for testing)
func trigger_trap_effect(target_body):
	if target_body and target_body.is_in_group("enemy"):
		damage_and_slow_enemy(target_body)
		print("Manually triggered trap effect on: ", target_body.name)

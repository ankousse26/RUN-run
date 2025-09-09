extends Node2D

# Poison trap settings - adjust these in the inspector
@export var poison_damage_per_tick: int = 5     # Damage every second
@export var poison_duration: float = 30.0       # 30 seconds of poison
@export var slow_percentage: float = 0.5        # 50% speed reduction
@export var activation_cooldown: float = 2.0    # Prevent multiple poison applications

# References
@onready var area_2d = $Area2D
@onready var animated_sprite = $AnimatedSprite2D

# Variables
var enemies_on_cooldown = {}  # Track enemies that recently got poisoned
var is_trap_active: bool = false

func _ready():
	print("Poison trap initialized: ", name)
	
	# Connect signals
	if area_2d:
		area_2d.body_entered.connect(_on_area_2d_body_entered)
		area_2d.body_exited.connect(_on_area_2d_body_exited)
		area_2d.monitoring = true
		print("Poison trap detection area connected successfully")
		
		# Debug collision setup
		print("Poison trap collision mask: ", area_2d.collision_mask)
		print("Poison trap collision layer: ", area_2d.collision_layer)
	else:
		print("ERROR: Area2D not found in poison trap!")
	
	# Start with idle state
	if animated_sprite:
		# Check if trap animation exists, otherwise don't play anything
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("trap"):
			print("Poison trap ready - trap animation found")
		else:
			print("Warning: No 'trap' animation found for poison trap")
	else:
		print("ERROR: AnimatedSprite2D not found in poison trap!")

func _physics_process(delta):
	# Update cooldown timers for enemies
	for enemy in enemies_on_cooldown.keys():
		if is_instance_valid(enemy):
			enemies_on_cooldown[enemy] -= delta
			if enemies_on_cooldown[enemy] <= 0:
				enemies_on_cooldown.erase(enemy)
				print("Enemy cooldown expired: ", enemy.name)
		else:
			# Remove invalid enemy references
			enemies_on_cooldown.erase(enemy)

func _on_area_2d_body_entered(body):
	print("Body entered poison trap: ", body.name if body else "NULL")
	print("Body groups: ", body.get_groups() if body else "NONE")
	
	if body and body.is_in_group("enemy"):
		print("Enemy stepped on poison trap: ", body.name)
		
		# Check if enemy is on cooldown
		if body in enemies_on_cooldown:
			print("Enemy is on cooldown - poison not applied")
			return
		
		# Apply poison effect
		apply_poison_to_enemy(body)
		
		# Put enemy on cooldown
		enemies_on_cooldown[body] = activation_cooldown
		
		# Activate trap visually
		activate_trap()
		
		print("Poison applied to enemy: ", body.name)
	else:
		print("Non-enemy body entered poison trap (ignored)")

func _on_area_2d_body_exited(body):
	print("Body exited poison trap: ", body.name if body else "NULL")
	
	if body and body.is_in_group("enemy"):
		print("Enemy left poison trap: ", body.name, " (poison effect continues)")
		
		# Note: Poison effect continues even after leaving the trap!
		# This is the key difference from the spike trap

func apply_poison_to_enemy(enemy):
	if not is_instance_valid(enemy):
		print("Tried to poison invalid enemy")
		return
	
	print("Applying poison to enemy: ", enemy.name)
	print("Poison details: ", poison_damage_per_tick, " damage/sec for ", poison_duration, " seconds")
	print("Slow effect: ", slow_percentage * 100, "% speed reduction")
	
	# Apply poison effect with slow
	if enemy.has_method("apply_poison_effect"):
		enemy.apply_poison_effect(poison_damage_per_tick, poison_duration, slow_percentage)
		print("Poison successfully applied to ", enemy.name)
	else:
		print("ERROR: Enemy has no apply_poison_effect method!")
	
	# Visual effects
	create_poison_effect()

func activate_trap():
	is_trap_active = true
	
	# Play trap animation
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("trap"):
			animated_sprite.play("trap")
			print("Playing poison trap animation")
		else:
			print("No trap animation - creating visual effect instead")
			create_activation_visual()
	
	# Auto-deactivate after a short time
	get_tree().create_timer(2.0).timeout.connect(func():
		deactivate_trap()
	)

func deactivate_trap():
	is_trap_active = false
	
	# Stop animation
	if animated_sprite:
		animated_sprite.stop()
		print("Poison trap animation stopped")

func create_poison_effect():
	if not animated_sprite:
		return
	
	# Green poison cloud effect
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.GREEN * 1.5, 0.2)
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)

func create_activation_visual():
	if not animated_sprite:
		return
	
	# Pulsing green effect if no animation is available
	animated_sprite.modulate = Color.GREEN
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(animated_sprite, "modulate", Color.GREEN * 1.5, 0.3)
	tween.tween_property(animated_sprite, "modulate", Color.GREEN * 0.7, 0.3)
	tween.tween_callback(func(): animated_sprite.modulate = Color.WHITE)

# Debug function
func _input(event):
	if event.is_action_pressed("ui_accept"):  # Enter key for poison trap debug
		print("=== POISON TRAP DEBUG INFO ===")
		print("Trap name: ", name)
		print("Trap position: ", global_position)
		print("Is active: ", is_trap_active)
		print("Poison damage per tick: ", poison_damage_per_tick)
		print("Poison duration: ", poison_duration)
		print("Slow percentage: ", slow_percentage)
		print("Activation cooldown: ", activation_cooldown)
		print("Enemies on cooldown: ", enemies_on_cooldown.size())
		
		for enemy in enemies_on_cooldown.keys():
			if is_instance_valid(enemy):
				print("  - Enemy: ", enemy.name, " | Cooldown remaining: ", enemies_on_cooldown[enemy], "s")
			else:
				print("  - Invalid enemy reference found")
		
		if area_2d:
			print("Detection area monitoring: ", area_2d.monitoring)
			print("Detection collision mask: ", area_2d.collision_mask)
			var bodies = area_2d.get_overlapping_bodies()
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

# Optional: Manual trigger for testing
func trigger_poison_effect(target_body):
	if target_body and target_body.is_in_group("enemy"):
		if target_body not in enemies_on_cooldown:
			apply_poison_to_enemy(target_body)
			enemies_on_cooldown[target_body] = activation_cooldown
			print("Manually triggered poison effect on: ", target_body.name)
		else:
			print("Enemy is on cooldown - cannot apply poison")

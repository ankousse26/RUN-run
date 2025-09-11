extends Node2D

# Safe Area Lights Trap - Enemy Repelling Only
# This creates a safe zone where enemies flee and can't attack the player

# Export variables - adjust these in the inspector
@export var light_radius: float = 200.0        # How far the light reaches
@export var light_intensity: float = 2.0       # How bright the light is
@export var detection_radius: float = 220.0    # Slightly larger than light for detection
@export var light_color: Color = Color.WHITE   # Color of the safe area light
@export var enable_flicker: bool = false       # Add atmospheric flickering

# Node references
@onready var light_source = $PointLight2D
@onready var detection_area = $Detect
@onready var animated_sprite = $AnimatedSprite2D

# State variables
var enemies_in_light: Array = []
var player_in_safe_area: bool = false
var player_reference = null
var is_active: bool = true

# Signals for safe area events
signal player_entered_safe_area(player)
signal player_exited_safe_area(player)
signal safe_area_status_changed(is_safe: bool)
signal enemy_entered_light(enemy)
signal enemy_exited_light(enemy)

func _ready():
	print("Safe area lights trap initialized: ", name)
	
	# Add this safe area to the safe_areas group
	add_to_group("safe_areas")
	
	# Setup components
	setup_light_source()
	setup_detection_area()
	setup_animations()
	
	# Enable flickering effect if requested
	if enable_flicker:
		create_flicker_effect()
	
	print("Safe area lights trap is now active!")

func setup_light_source():
	"""Setup the permanent light that creates the safe area"""
	if not light_source:
		print("ERROR: PointLight2D not found! Please add a PointLight2D node named 'PointLight2D'")
		return
	
	# Configure the light to be always on
	light_source.enabled = true
	light_source.energy = light_intensity
	light_source.color = light_color
	light_source.texture_scale = light_radius / 100.0
	
	# Create light texture if missing
	if not light_source.texture:
		var gradient = Gradient.new()
		gradient.add_point(0.0, Color.WHITE)
		gradient.add_point(1.0, Color.TRANSPARENT)
		
		var gradient_texture = GradientTexture2D.new()
		gradient_texture.gradient = gradient
		gradient_texture.fill = GradientTexture2D.FILL_RADIAL
		gradient_texture.width = 256
		gradient_texture.height = 256
		
		light_source.texture = gradient_texture
	
	print("Safe area light configured - Always on protection created")

func setup_detection_area():
	"""Setup the area that detects when entities enter/exit the safe zone"""
	if not detection_area:
		print("ERROR: Area2D not found! Please add an Area2D node named 'Detect'")
		return
	
	# Connect signals
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	detection_area.monitoring = true
	detection_area.monitorable = true
	
	# Clear existing collision shapes
	for child in detection_area.get_children():
		if child is CollisionShape2D:
			child.queue_free()
	
	# Create new collision shape for detection
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = detection_radius
	collision_shape.shape = shape
	detection_area.add_child(collision_shape)
	
	print("Safe area detection setup complete - radius: ", detection_radius)

func setup_animations():
	"""Setup sprite animations"""
	if not animated_sprite:
		print("Warning: No AnimatedSprite2D found. Visual feedback will be limited.")
		return
	
	# Start with idle animation
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")
	else:
		print("Warning: No 'idle' animation found for safe area")

func _on_body_entered(body):
	if not body:
		return
		
	print("Body entered safe area: ", body.name)
	
	# Check if it's the player
	if body.is_in_group("player") or body.name.to_lower().contains("player"):
		handle_player_entered(body)
	
	# Handle enemies
	elif body.is_in_group("enemy"):
		handle_enemy_entered(body)
	
	# Handle bosses
	elif body.is_in_group("boss"):
		handle_boss_entered(body)

func _on_body_exited(body):
	if not body:
		return
		
	print("Body exited safe area: ", body.name)
	
	# Check if it's the player leaving
	if body == player_reference:
		handle_player_exited(body)
	
	# Handle enemies/bosses leaving
	elif body.is_in_group("enemy") or body.is_in_group("boss"):
		handle_enemy_exited(body)

func handle_player_entered(player):
	"""Handle player entering the safe area"""
	print("🛡️ PLAYER entered safe area - PROTECTION ACTIVATED!")
	
	player_in_safe_area = true
	player_reference = player
	
	# Emit signals
	player_entered_safe_area.emit(player)
	safe_area_status_changed.emit(true)
	
	# Update player's safe status
	if player.has_method("enter_safe_area"):
		player.enter_safe_area()
	
	# Disable attacks from all enemies currently in the area
	for enemy in enemies_in_light:
		if is_instance_valid(enemy) and enemy.has_method("disable_attacks"):
			enemy.disable_attacks()
			print("Disabled attacks for enemy: ", enemy.name)
	
	update_safe_area_status()
	print("Player is now PROTECTED from all attacks!")

func handle_player_exited(player):
	"""Handle player leaving the safe area"""
	print("⚠️ PLAYER left safe area - PROTECTION LOST!")
	
	player_in_safe_area = false
	player_reference = null
	
	# Emit signals
	player_exited_safe_area.emit(player)
	safe_area_status_changed.emit(false)
	
	# Update player's safe status
	if player.has_method("exit_safe_area"):
		player.exit_safe_area()
	
	# Re-enable enemy attacks since player left
	for enemy in enemies_in_light:
		if is_instance_valid(enemy) and enemy.has_method("enable_attacks"):
			enemy.enable_attacks()
			print("Re-enabled attacks for enemy: ", enemy.name)
	
	update_safe_area_status()
	print("Player is now VULNERABLE to attacks!")

func handle_enemy_entered(enemy):
	"""Handle enemy entering the safe area"""
	print("👹 Enemy entered safe area: ", enemy.name)
	
	# Add to tracking list
	if enemy not in enemies_in_light:
		enemies_in_light.append(enemy)
	
	# Emit signal
	enemy_entered_light.emit(enemy)
	
	# Make enemy flee from safe area - THIS IS THE KEY CALL
	if enemy.has_method("enter_light"):
		enemy.enter_light()
		print("✅ Called enter_light() on enemy: ", enemy.name)
	else:
		print("❌ ERROR: Enemy ", enemy.name, " has no enter_light() method!")
		# List available methods for debugging
		if enemy.has_method("get_method_list"):
			var methods = enemy.get_method_list()
			print("Available methods on enemy: ", methods)
	
	# Disable attacks if player is in safe area
	if player_in_safe_area and enemy.has_method("disable_attacks"):
		enemy.disable_attacks()
		print("Enemy attacks disabled - player is protected")
	
	update_safe_area_status()

func handle_boss_entered(boss):
	"""Handle boss entering the safe area"""
	print("👑 BOSS entered safe area: ", boss.name)
	
	# Add to tracking list
	if boss not in enemies_in_light:
		enemies_in_light.append(boss)
	
	# Emit signal
	enemy_entered_light.emit(boss)
	
	# Make boss flee or become less aggressive
	if boss.has_method("enter_light"):
		boss.enter_light()
		print("✅ Called enter_light() on boss: ", boss.name)
	else:
		print("❌ ERROR: Boss ", boss.name, " has no enter_light() method!")
	
	# Disable boss attacks if player is in safe area
	if player_in_safe_area and boss.has_method("disable_attacks"):
		boss.disable_attacks()
		print("Boss attacks disabled - player is protected")
	
	update_safe_area_status()

func handle_enemy_exited(enemy):
	"""Handle enemy/boss leaving the safe area"""
	print("👹 Hostile entity left safe area: ", enemy.name)
	
	# Remove from tracking
	if enemy in enemies_in_light:
		enemies_in_light.erase(enemy)
	
	# Emit signal
	enemy_exited_light.emit(enemy)
	
	# Tell entity it's no longer in light
	if enemy.has_method("exit_light"):
		enemy.exit_light()
		print("✅ Called exit_light() on enemy: ", enemy.name)
	else:
		print("❌ ERROR: Enemy ", enemy.name, " has no exit_light() method!")
	
	# Re-enable attacks only if player is NOT in safe area
	if not player_in_safe_area and enemy.has_method("enable_attacks"):
		enemy.enable_attacks()
		print("Enemy attacks re-enabled - no player in safe area")
	
	update_safe_area_status()

func update_safe_area_status():
	"""Update animations and effects based on current safe area status"""
	if not animated_sprite:
		return
	
	var target_animation = "idle"
	var status_message = ""
	
	if player_in_safe_area and enemies_in_light.size() > 0:
		# Player safe + enemies being repelled = maximum protection
		target_animation = "active"
		status_message = "ACTIVELY protecting player from " + str(enemies_in_light.size()) + " threats"
	elif player_in_safe_area:
		# Player safe, no immediate threats = peaceful protection
		target_animation = "protected"
		if not animated_sprite.sprite_frames.has_animation("protected"):
			target_animation = "idle"
		status_message = "Player safely protected (no immediate threats)"
	elif enemies_in_light.size() > 0:
		# No player, but repelling enemies
		target_animation = "repelling"
		if not animated_sprite.sprite_frames.has_animation("repelling"):
			target_animation = "active"
		status_message = "Repelling " + str(enemies_in_light.size()) + " hostile entities"
	else:
		# Normal idle state
		target_animation = "idle"
		status_message = "Safe area idle - awaiting entities"
	
	# Play the animation if different
	if animated_sprite.sprite_frames.has_animation(target_animation):
		if animated_sprite.animation != target_animation:
			animated_sprite.play(target_animation)
	
	print("Safe area status: ", status_message)

func _physics_process(delta):
	"""Clean up invalid references and maintain safe area"""
	# Clean up invalid enemy references
	var enemies_to_remove = []
	
	for enemy in enemies_in_light:
		if not is_instance_valid(enemy):
			enemies_to_remove.append(enemy)
	
	for enemy in enemies_to_remove:
		enemies_in_light.erase(enemy)
		print("Removed invalid enemy reference from safe area")
	
	# Check if player reference is still valid
	if player_reference and not is_instance_valid(player_reference):
		print("Player reference became invalid - clearing safe area status")
		player_reference = null
		player_in_safe_area = false
		safe_area_status_changed.emit(false)

# Public API methods
func is_player_safe() -> bool:
	"""Returns true if player is currently protected in the safe area"""
	return player_in_safe_area and is_active

func get_safe_area_info() -> Dictionary:
	"""Returns comprehensive information about the safe area status"""
	# Build enemy names array properly in GDScript
	var enemy_names = []
	for enemy in enemies_in_light:
		if is_instance_valid(enemy):
			enemy_names.append(enemy.name)
	
	return {
		"player_safe": player_in_safe_area,
		"player_name": player_reference.name if player_reference else "None",
		"enemies_in_area": enemies_in_light.size(),
		"enemy_names": enemy_names,
		"is_active": is_active,
		"trap_position": global_position,
		"safe_radius": detection_radius,
		"light_radius": light_radius
	}

func get_enemies_in_safe_area() -> Array:
	"""Get list of enemies currently in the safe area"""
	return enemies_in_light.filter(func(enemy): return is_instance_valid(enemy))

# Safe area control methods
func activate_safe_area():
	"""Turn on the safe area - restores full protection"""
	is_active = true
	
	if light_source:
		light_source.enabled = true
	if detection_area:
		detection_area.monitoring = true
	
	print("✅ Safe area ACTIVATED - Protection restored")

func deactivate_safe_area():
	"""Turn off the safe area - WARNING: Player becomes vulnerable!"""
	is_active = false
	
	if light_source:
		light_source.enabled = false
	if detection_area:
		detection_area.monitoring = false
	
	# Clear player protection
	if player_in_safe_area:
		player_in_safe_area = false
		safe_area_status_changed.emit(false)
		if player_reference and player_reference.has_method("exit_safe_area"):
			player_reference.exit_safe_area()
	
	# Re-enable all enemy attacks
	for enemy in enemies_in_light:
		if is_instance_valid(enemy):
			if enemy.has_method("exit_light"):
				enemy.exit_light()
			if enemy.has_method("enable_attacks"):
				enemy.enable_attacks()
	
	enemies_in_light.clear()
	print("❌ Safe area DEACTIVATED - Player is now VULNERABLE!")

func toggle_safe_area():
	"""Toggle the safe area on/off"""
	if is_active:
		deactivate_safe_area()
	else:
		activate_safe_area()

func set_light_properties(radius: float, intensity: float, color: Color = Color.WHITE):
	"""Change the light properties during gameplay"""
	light_radius = radius
	light_intensity = intensity
	light_color = color
	
	if light_source:
		light_source.energy = intensity
		light_source.color = color
		light_source.texture_scale = radius / 100.0
	
	# Update detection radius to be slightly larger than light
	detection_radius = radius + 20.0
	setup_detection_area()
	
	print("Light properties updated - Radius: ", radius, " Intensity: ", intensity)

# Atmospheric effects
func create_flicker_effect():
	"""Creates a subtle flickering effect for atmosphere"""
	if not light_source:
		return
	
	var flicker_tween = create_tween()
	flicker_tween.set_loops()
	
	# Subtle energy variation for atmosphere
	flicker_tween.tween_property(light_source, "energy", light_intensity * 0.85, randf_range(1.0, 2.0))
	flicker_tween.tween_property(light_source, "energy", light_intensity * 1.15, randf_range(0.5, 1.5))
	flicker_tween.tween_property(light_source, "energy", light_intensity, randf_range(0.3, 1.0))

# Debug and testing
func _input(event):
	if event.is_action_pressed("ui_select"):  # Space key for debug info
		print_debug_info()

func print_debug_info():
	"""Print comprehensive debug information"""
	print("\n=== SAFE AREA DEBUG INFO ===")
	print("Safe area name: ", name)
	print("Position: ", global_position)
	print("Active: ", is_active)
	print("Light radius: ", light_radius)
	print("Detection radius: ", detection_radius)
	print("Light intensity: ", light_intensity)
	print("Light color: ", light_color)
	print("Flicker enabled: ", enable_flicker)
	
	print("\n--- PLAYER STATUS ---")
	print("Player in safe area: ", player_in_safe_area)
	print("Player reference: ", player_reference.name if player_reference else "None")
	if player_reference:
		print("Player position: ", player_reference.global_position)
		print("Distance to safe area: ", global_position.distance_to(player_reference.global_position))
	
	print("\n--- ENEMIES STATUS ---")
	print("Enemies in light: ", enemies_in_light.size())
	for i in range(enemies_in_light.size()):
		var enemy = enemies_in_light[i]
		if is_instance_valid(enemy):
			print("  ", i+1, ". ", enemy.name, " at ", enemy.global_position)
			print("    - Has enter_light(): ", enemy.has_method("enter_light"))
			print("    - Has exit_light(): ", enemy.has_method("exit_light"))
			print("    - Has disable_attacks(): ", enemy.has_method("disable_attacks"))
			print("    - Has enable_attacks(): ", enemy.has_method("enable_attacks"))
		else:
			print("  ", i+1, ". INVALID REFERENCE")
	
	print("\n--- DETECTION AREA ---")
	if detection_area:
		print("Monitoring: ", detection_area.monitoring)
		print("Monitorable: ", detection_area.monitorable)
		var overlapping = detection_area.get_overlapping_bodies()
		print("Currently overlapping: ", overlapping.size())
		for body in overlapping:
			print("  - ", body.name, " | Groups: ", body.get_groups())
			if body.is_in_group("enemy"):
				print("    Methods: enter_light=", body.has_method("enter_light"), " exit_light=", body.has_method("exit_light"))
	else:
		print("ERROR: No detection area found!")
	
	print("\n--- LIGHT SOURCE ---")
	if light_source:
		print("Light enabled: ", light_source.enabled)
		print("Light energy: ", light_source.energy)
		print("Light color: ", light_source.color)
		print("Texture scale: ", light_source.texture_scale)
	else:
		print("ERROR: No light source found!")
	
	print("===========================\n")

# Helper method for other scripts to check if a position is safe
func is_position_safe(pos: Vector2) -> bool:
	"""Check if a given position is within the safe area"""
	return is_active and global_position.distance_to(pos) <= detection_radius

# Method to get the safe area center for AI pathfinding
func get_safe_center() -> Vector2:
	"""Get the center position of the safe area"""
	return global_position

# Method to get safe area radius for AI
func get_safe_radius() -> float:
	"""Get the safe area radius"""
	return detection_radius if is_active else 0.0

# Test method to manually trigger enemy fleeing (for debugging)
func force_all_enemies_to_flee():
	"""Debug method - force all overlapping enemies to flee"""
	print("FORCING ALL ENEMIES TO FLEE!")
	
	if not detection_area:
		print("No detection area!")
		return
	
	var bodies = detection_area.get_overlapping_bodies()
	print("Found ", bodies.size(), " overlapping bodies")
	
	for body in bodies:
		if body.is_in_group("enemy"):
			print("Forcing enemy to flee: ", body.name)
			if body.has_method("enter_light"):
				body.enter_light()
				print("✅ Called enter_light() on ", body.name)
			else:
				print("❌ No enter_light() method on ", body.name)

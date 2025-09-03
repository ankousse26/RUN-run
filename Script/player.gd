extends CharacterBody2D

# Movement settings
@export var speed: float = 300.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0

# Push/Pull settings
@export var push_pull_force: float = 600.0
@export var push_pull_speed: float = 150.0  # Slower speed when pushing/pulling
@export var interaction_distance: float = 80.0  # How close to be to detect and select box
@export var push_distance: float = 35.0  # How close to be to actually push/pull the box

# Key collection system
@export var keys_needed_to_escape: int = 1
var collected_keys: Array[String] = []
@onready var key_ui = $UI/KeyCounter

# Health settings
@export var max_health: int = 100
@export var current_health: int = 100
@export var invincible_time: float = 1.0

# Knockback settings
@export var knockback_force: float = 300.0
@export var knockback_duration: float = 0.3

# UI Settings
@export var health_bar_max_width: float = 100.0

# Flashlight system
@export var flashlight_enabled: bool = true
@export var max_battery: float = 100.0
@export var battery_drain_rate: float = 15.0
@export var flashlight_detection_range: float = 200.0

# Flashlight references
@onready var flashlight_light = $PointLight2D
@onready var flashlight_area = $FlashlightDetectionArea
@onready var battery_ui = $UI/BatteryBar
@onready var battery_label = $UI/BatteryLabel

# Flashlight variables
var current_battery: float = 100.0
var flashlight_on: bool = false
var enemies_in_light: Array = []

# References
@onready var animated_sprite = $AnimatedSprite2D
@onready var health_ui = $UI/HealthBar
@onready var health_label = $UI/HealthLabel
@onready var character_portrait = $UI/AnimatedSprite2D
@onready var ui_background = $UI/UIBackground

# Camera reference for shake effects
@onready var camera_controller = get_viewport().get_camera_2d()

# Variables
var is_moving: bool = false
var is_invincible: bool = false
var is_dead: bool = false
var is_dying: bool = false
var is_knocked_back: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var can_exit: bool = false

# Push/Pull variables
var is_push_pull_mode: bool = false
var target_box: RigidBody2D = null
var is_pushing: bool = false
var is_pulling: bool = false

# Signals
signal health_changed(new_health)
signal player_died

func _ready():
	add_to_group("player")
	print("Player ready with manual push/pull system!")
	
	# Initialize health
	current_health = max_health
	update_health_ui()
	
	# Initialize flashlight
	current_battery = max_battery
	setup_flashlight()
	update_battery_ui()
	
	# Get camera reference for manual shake control (optional)
	if not camera_controller:
		camera_controller = get_tree().get_first_node_in_group("camera")
	
	if camera_controller:
		print("Player found camera controller: ", camera_controller.name)
	
	check_ui_elements()
	
	# Debug pushable objects after everything loads
	call_deferred("debug_pushable_objects")

func debug_pushable_objects():
	await get_tree().process_frame  # Wait one frame for everything to initialize
	var pushable_objects = get_tree().get_nodes_in_group("pushable")
	print("=== PUSHABLE OBJECTS DEBUG ===")
	print("Total pushable objects: ", pushable_objects.size())
	for obj in pushable_objects:
		print("- ", obj.name, " at position: ", obj.global_position)
		var distance = global_position.distance_to(obj.global_position)
		print("  Distance from player: ", distance)

func check_ui_elements():
	print("=== UI Elements Check ===")
	print("Health UI found: ", health_ui != null)
	print("Health Label found: ", health_label != null) 
	print("Character Portrait found: ", character_portrait != null)
	print("UI Background found: ", ui_background != null)
	print("Key UI found: ", key_ui != null)
	print("Flashlight Light found: ", flashlight_light != null)
	print("Flashlight Area found: ", flashlight_area != null)
	print("Battery UI found: ", battery_ui != null)
	print("Battery Label found: ", battery_label != null)

func setup_flashlight():
	# Setup flashlight area signals
	if flashlight_area:
		flashlight_area.body_entered.connect(_on_flashlight_area_entered)
		flashlight_area.body_exited.connect(_on_flashlight_area_exited)
		flashlight_area.monitoring = true
		flashlight_area.monitorable = true
	
	# Configure PointLight2D for Godot 4
	if flashlight_light:
		flashlight_light.enabled = false
		flashlight_light.energy = 3.0
		flashlight_light.texture_scale = 2.0
		flashlight_light.color = Color.WHITE
		
		# Create light texture if missing
		if not flashlight_light.texture:
			var gradient = Gradient.new()
			gradient.add_point(0.0, Color.WHITE)
			gradient.add_point(1.0, Color.TRANSPARENT)
			
			var gradient_texture = GradientTexture2D.new()
			gradient_texture.gradient = gradient
			gradient_texture.fill = GradientTexture2D.FILL_RADIAL
			gradient_texture.width = 256
			gradient_texture.height = 256
			flashlight_light.texture = gradient_texture
	
	# Setup detection area shape
	setup_flashlight_detection_shape()
	
	# Initialize flashlight state
	set_flashlight(false)

func setup_flashlight_detection_shape():
	if not flashlight_area:
		return
	
	# Clear existing shapes
	for child in flashlight_area.get_children():
		if child is CollisionShape2D:
			child.queue_free()
	
	# Create new collision shape
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = flashlight_detection_range
	collision_shape.shape = shape
	flashlight_area.add_child(collision_shape)

func _physics_process(delta):
	if is_dead or is_dying:
		return
		
	handle_input(delta)
	handle_push_pull_system()
	handle_animation()
	move_and_slide()
	
	# Handle flashlight battery
	handle_flashlight(delta)
	
	# Update flashlight direction to face mouse
	if flashlight_on and flashlight_light:
		update_flashlight_direction()

func _input(event):
	# Exit with Space key
	if Input.is_action_just_pressed("EXIT"):
		attempt_exit()
	
	# Collect with E key
	if Input.is_action_just_pressed("COLLECT"):
		pass
	
	# Toggle flashlight with F key
	if event is InputEventKey and event.keycode == KEY_F and event.pressed and not event.echo and not is_dead and not is_dying:
		toggle_flashlight()
	
	# Push/Pull mode with B key - IMPROVED FEATURE
	if event is InputEventKey and event.keycode == KEY_B and not is_dead and not is_dying:
		if event.pressed and not event.echo:
			start_push_pull_mode()
		elif not event.pressed:
			stop_push_pull_mode()
	
	# Debug keys
	if event is InputEventKey && event.keycode == KEY_1 && event.pressed && !event.echo:
		debug_take_damage()
	
	if event is InputEventKey && event.keycode == KEY_2 && event.pressed && !event.echo:
		debug_heal()
	
	# Debug camera shake with key 3
	if event is InputEventKey && event.keycode == KEY_3 && event.pressed && !event.echo:
		if camera_controller and camera_controller.has_method("debug_shake"):
			camera_controller.debug_shake()
			print("Debug: Camera shake triggered")

func start_push_pull_mode():
	# Find nearest box
	target_box = find_nearest_box()
	
	if target_box:
		is_push_pull_mode = true
		var distance = global_position.distance_to(target_box.global_position)
		print("Push/Pull mode activated - Target: ", target_box.name)
		print("Distance to box: ", int(distance), " (need to be within ", push_distance, " to actually move it)")
		print("Use WASD to push/pull the box when close enough")
		
		# Visual feedback - make box slightly bright
		if target_box.has_node("Sprite2D"):
			var sprite = target_box.get_node("Sprite2D")
			sprite.modulate = Color(1.2, 1.2, 1.0)  # Slight yellow tint
		# Try ColorRect if Sprite2D doesn't exist
		elif target_box.has_node("ColorRect"):
			var sprite = target_box.get_node("ColorRect")
			sprite.modulate = Color(1.2, 1.2, 1.0)
		# Try RenderingServer for visual feedback if no sprite found
		elif target_box.has_method("set_modulate"):
			target_box.modulate = Color(1.2, 1.2, 1.0)
	else:
		print("No box nearby to push/pull (within ", interaction_distance, " units)")
		# Show all pushable objects for debugging
		var all_pushable = get_tree().get_nodes_in_group("pushable")
		print("All pushable objects in scene: ", all_pushable.size())
		for obj in all_pushable:
			if obj is RigidBody2D:
				var dist = global_position.distance_to(obj.global_position)
				print("  - ", obj.name, " at distance: ", dist)

func stop_push_pull_mode():
	if is_push_pull_mode:
		is_push_pull_mode = false
		is_pushing = false
		is_pulling = false
		
		# Remove visual feedback
		if target_box:
			if target_box.has_node("Sprite2D"):
				var sprite = target_box.get_node("Sprite2D")
				sprite.modulate = Color.WHITE
			elif target_box.has_node("ColorRect"):
				var sprite = target_box.get_node("ColorRect")
				sprite.modulate = Color.WHITE
			elif target_box.has_method("set_modulate"):
				target_box.modulate = Color.WHITE
		
		target_box = null
		print("Push/Pull mode deactivated")

func find_nearest_box() -> RigidBody2D:
	var nearest_box: RigidBody2D = null
	var nearest_distance: float = interaction_distance
	
	# Get all bodies in the pushable group
	var boxes = get_tree().get_nodes_in_group("pushable")
	print("Found ", boxes.size(), " pushable objects in scene")
	
	for box in boxes:
		if box is RigidBody2D:
			var distance = global_position.distance_to(box.global_position)
			print("Box '", box.name, "' distance: ", distance)
			
			if distance <= interaction_distance:
				if nearest_box == null or distance < nearest_distance:
					nearest_distance = distance
					nearest_box = box
					print("Set as nearest box: ", box.name)
	
	if nearest_box:
		print("Selected nearest box: ", nearest_box.name, " at distance: ", nearest_distance)
	else:
		print("No pushable boxes found within range of ", interaction_distance)
	
	return nearest_box

func handle_push_pull_system():
	is_pushing = false
	is_pulling = false
	
	if not is_push_pull_mode or not target_box:
		return
	
	# Check if box is still in selection range
	var distance_to_box = global_position.distance_to(target_box.global_position)
	if distance_to_box > interaction_distance * 1.5:  # Exit push/pull mode if too far
		print("Box too far away - exiting push/pull mode")
		stop_push_pull_mode()
		return
	
	# Get input direction
	var input_direction = Vector2.ZERO
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left"):
		input_direction.x -= 1
	if Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right"):
		input_direction.x += 1
	if Input.is_action_pressed("move_up") or Input.is_action_pressed("ui_up"):
		input_direction.y -= 1
	if Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down"):
		input_direction.y += 1
	
	if input_direction.length() > 0:
		input_direction = input_direction.normalized()
		
		# ONLY apply force if player is close enough to actually push/pull
		if distance_to_box <= push_distance:
			# Apply force to the box using apply_central_force (continuous force, not impulse)
			var force_to_apply = input_direction * push_pull_force
			target_box.apply_central_force(force_to_apply)
			
			# Determine if we're conceptually pushing or pulling for animation/feedback
			var direction_to_box = (target_box.global_position - global_position).normalized()
			var dot_product = input_direction.dot(direction_to_box)
			
			if dot_product > 0.1:  # Moving toward box direction
				is_pulling = true
				print("PULLING box ", get_direction_name(input_direction))
			else:  # Moving in other directions
				is_pushing = true
				print("PUSHING box ", get_direction_name(input_direction))
		else:
			# Player is in push/pull mode but too far to actually move the box
			print("Too far from box to push/pull (", int(distance_to_box), "/", push_distance, ") - get closer!")

func get_direction_name(direction: Vector2) -> String:
	if abs(direction.x) > abs(direction.y):
		return "RIGHT" if direction.x > 0 else "LEFT"
	else:
		return "DOWN" if direction.y > 0 else "UP"

func handle_input(delta):
	var input_dir = Vector2.ZERO
	
	# Don't allow input during knockback
	if not is_knocked_back:
		if Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left"):
			input_dir.x -= 1
		if Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right"):
			input_dir.x += 1
		if Input.is_action_pressed("move_up") or Input.is_action_pressed("ui_up"):
			input_dir.y -= 1
		if Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down"):
			input_dir.y += 1
	
	# Handle knockback with smooth decay
	if is_knocked_back:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, friction * 2 * delta)
		is_moving = false
	else:
		# Normal movement
		if input_dir.length() > 0:
			input_dir = input_dir.normalized()
			
			# Use slower speed in push/pull mode
			var movement_speed = speed
			if is_push_pull_mode:
				movement_speed = push_pull_speed
			
			velocity = velocity.move_toward(input_dir * movement_speed, acceleration * delta)
			is_moving = true
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			is_moving = velocity.length() > 5.0

func toggle_flashlight():
	if not flashlight_enabled:
		print("Flashlight disabled!")
		return
		
	if current_battery <= 0:
		print("Battery empty! Cannot use flashlight")
		return
	
	set_flashlight(not flashlight_on)
	handle_animation()
	print("Flashlight toggled! State: ", "ON" if flashlight_on else "OFF")

func set_flashlight(state: bool):
	flashlight_on = state and current_battery > 0
	
	# Update light visibility
	if flashlight_light:
		flashlight_light.enabled = flashlight_on
	
	# Update detection area
	if flashlight_area:
		flashlight_area.monitoring = flashlight_on
	
	print("Flashlight: ", "ON" if flashlight_on else "OFF")

func handle_flashlight(delta):
	if flashlight_on and current_battery > 0:
		# Drain battery
		current_battery -= battery_drain_rate * delta
		current_battery = max(current_battery, 0)
		
		# Turn off if battery depleted
		if current_battery <= 0:
			set_flashlight(false)
			print("Battery depleted! Flashlight turned off")
			handle_animation()
	
	# Update UI
	update_battery_ui()

func update_flashlight_direction():
	if flashlight_light:
		# Point flashlight toward mouse cursor
		var mouse_pos = get_global_mouse_position()
		var direction = (mouse_pos - global_position).normalized()
		var angle = direction.angle()
		
		flashlight_light.rotation = angle
		if flashlight_area:
			flashlight_area.rotation = angle

func update_battery_ui():
	# Update battery bar
	if battery_ui:
		var battery_percentage = current_battery / max_battery
		battery_ui.size.x = 150 * battery_percentage
		
		# Color based on battery level
		if battery_percentage > 0.5:
			battery_ui.color = Color.GREEN
		elif battery_percentage > 0.2:
			battery_ui.color = Color.YELLOW
		else:
			battery_ui.color = Color.RED
	
	# Update battery text
	if battery_label:
		var battery_percent = int((current_battery / max_battery) * 100)
		battery_label.text = "Battery: " + str(battery_percent) + "%"

# Flashlight area detection
func _on_flashlight_area_entered(body):
	if body.is_in_group("enemy") and body not in enemies_in_light:
		enemies_in_light.append(body)
		if body.has_method("enter_light"):
			body.enter_light()

func _on_flashlight_area_exited(body):
	if body.is_in_group("enemy") and body in enemies_in_light:
		enemies_in_light.erase(body)
		if body.has_method("exit_light"):
			body.exit_light()

func add_battery(amount: float):
	current_battery = min(current_battery + amount, max_battery)
	print("Battery recharged: ", amount, "% - Total: ", current_battery)
	update_battery_ui()

func get_battery_percentage() -> float:
	return current_battery / max_battery

func get_flashlight_state() -> bool:
	return flashlight_on and current_battery > 0

func handle_animation():
	if not animated_sprite or is_dying:
		return
	
	if not animated_sprite.sprite_frames:
		return
		
	if is_moving:
		# Choose animation based on state
		var walk_anim = "Walk"
		
		# Priority 1: Walk LIGHT when flashlight is on
		if flashlight_on and animated_sprite.sprite_frames.has_animation("Walk LIGHT"):
			walk_anim = "Walk LIGHT"
		# Priority 2: Regular walk
		elif animated_sprite.sprite_frames.has_animation("Walk"):
			walk_anim = "Walk"
		
		# Play the animation
		if animated_sprite.sprite_frames.has_animation(walk_anim):
			if animated_sprite.animation != walk_anim:
				animated_sprite.play(walk_anim)
	else:
		# Idle animation
		if animated_sprite.sprite_frames.has_animation("Idel"):
			if animated_sprite.animation != "Idel":
				animated_sprite.play("Idel")
		elif animated_sprite.sprite_frames.has_animation("idle"):
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")

# Keep all your existing functions (health, combat, etc.)
func attempt_exit():
	if can_exit and can_escape():
		print("Player escaped successfully!")
		trigger_escape()
	elif can_exit and not can_escape():
		var needed = keys_needed_to_escape - collected_keys.size()
		print("Need ", needed, " more keys to escape!")
	else:
		print("No exit nearby")

func trigger_escape():
	print("Victory! Player has escaped!")
	get_tree().create_timer(1.0).timeout.connect(func():
		print("Restarting...")
		get_tree().reload_current_scene()
	)

func collect_key(key_id: String):
	if key_id in collected_keys:
		return
		
	collected_keys.append(key_id)
	print("Collected key: ", key_id, " (", collected_keys.size(), "/", keys_needed_to_escape, ")")
	update_key_ui()
	check_escape_condition()

func update_key_ui():
	if key_ui:
		key_ui.text = "Keys: " + str(collected_keys.size()) + "/" + str(keys_needed_to_escape)

func check_escape_condition():
	if collected_keys.size() >= keys_needed_to_escape:
		print("All keys collected! Exit is now available!")

func can_escape() -> bool:
	return collected_keys.size() >= keys_needed_to_escape

func take_damage(amount: int, attacker_position: Vector2 = Vector2.ZERO):
	if is_invincible or is_dead or is_dying:
		return
		
	current_health -= amount
	current_health = max(current_health, 0)
	
	print("Player took ", amount, " damage! Health: ", current_health, "/", max_health)
	
	# Exit push/pull mode when taking damage
	if is_push_pull_mode:
		stop_push_pull_mode()
	
	health_changed.emit(current_health)
	update_health_ui()
	apply_knockback(attacker_position)
	hurt_effect()
	
	# Manual camera shake based on damage amount (optional since camera auto-connects to health_changed signal)
	if camera_controller and camera_controller.has_method("shake_camera"):
		if amount >= 30:
			camera_controller.strong_shake()
		elif amount >= 20:
			camera_controller.medium_shake()
		else:
			camera_controller.light_shake()
	
	if current_health <= 0:
		die()
	else:
		become_invincible()

func apply_knockback(attacker_position: Vector2):
	var knockback_direction: Vector2
	if attacker_position != Vector2.ZERO:
		knockback_direction = (global_position - attacker_position).normalized()
	else:
		knockback_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	knockback_velocity = knockback_direction * knockback_force
	is_knocked_back = true
	get_tree().create_timer(knockback_duration).timeout.connect(stop_knockback)

func stop_knockback():
	is_knocked_back = false
	knockback_velocity = Vector2.ZERO

func become_invincible():
	is_invincible = true
	
	if animated_sprite:
		var blink_duration = 0.1
		var total_blinks = int(invincible_time / blink_duration)
		
		for i in range(total_blinks):
			if not is_dead and not is_dying:
				animated_sprite.modulate.a = 0.3
				await get_tree().create_timer(blink_duration / 2).timeout
				
				if not is_dead and not is_dying:
					animated_sprite.modulate.a = 1.0
					await get_tree().create_timer(blink_duration / 2).timeout
	
	if animated_sprite and not is_dead and not is_dying:
		animated_sprite.modulate.a = 1.0
	
	is_invincible = false

func hurt_effect():
	if animated_sprite:
		animated_sprite.modulate = Color.RED
		var flash_tween = create_tween()
		flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)

func update_health_ui():
	if health_ui:
		var health_percentage = float(current_health) / float(max_health)
		health_ui.size.x = health_bar_max_width * health_percentage
		health_ui.color = Color(1, 0, 0, 1.0)
	
	if health_label:
		health_label.text = str(current_health) + "/" + str(max_health)

func update_character_portrait():
	if not character_portrait or not character_portrait.sprite_frames:
		return
	
	if is_invincible or is_dying:  # Show crying during dying state too
		if character_portrait.sprite_frames.has_animation("crying"):
			if character_portrait.animation != "crying":
				character_portrait.play("crying")
				print("Playing crying animation on UI portrait")
	else:
		if character_portrait.sprite_frames.has_animation("normal"):
			if character_portrait.animation != "normal":
				character_portrait.play("normal")

func heal(amount: int):
	if is_dead or is_dying:
		return
		
	current_health += amount
	current_health = min(current_health, max_health)
	health_changed.emit(current_health)
	update_health_ui()

func die():
	if is_dead or is_dying:
		return
		
	print("Player dying - starting death sequence")
	is_dying = true
	velocity = Vector2.ZERO
	set_flashlight(false)
	stop_push_pull_mode()
	
	# Play death animation on player sprite
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("death"):
			animated_sprite.play("death")
			print("Playing death animation on player sprite")
		elif animated_sprite.sprite_frames.has_animation("Death"):
			animated_sprite.play("Death")
			print("Playing Death animation on player sprite")
		elif animated_sprite.sprite_frames.has_animation("dead"):
			animated_sprite.play("dead")
			print("Playing dead animation on player sprite")
		else:
			print("No death animation found in player sprite")
	
	# Update character portrait to crying animation
	update_character_portrait()
	
	# Trigger death camera shake
	if camera_controller and camera_controller.has_method("explosion_shake"):
		camera_controller.explosion_shake()
	
	# Wait longer to ensure animations have time to play
	get_tree().create_timer(3.0).timeout.connect(_on_death_animation_finished)

func _on_death_animation_finished():
	if not is_dying:
		return
	
	print("Death animation finished - transitioning to game over")
	is_dead = true
	is_dying = false
	player_died.emit()
	
	# Wait a bit more to show the final state
	await get_tree().create_timer(2.0).timeout
	restart_game()

func restart_game():
	print("Restarting game...")
	get_tree().reload_current_scene()

func get_damaged_by_enemy(damage: int, enemy_position: Vector2 = Vector2.ZERO):
	take_damage(damage, enemy_position)

func set_can_exit(value: bool):
	can_exit = value

# Utility methods for triggering special effects
func trigger_explosion_shake():
	if camera_controller and camera_controller.has_method("strong_shake"):
		camera_controller.strong_shake()  # Uses 2.5 intensity - gentle feedback

# Debug functions
func debug_take_damage():
	var fake_attacker_pos = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
	take_damage(15, fake_attacker_pos)
	print("Debug: Took 15 damage")

func debug_heal():
	heal(20)
	print("Debug: Healed 20 HP")

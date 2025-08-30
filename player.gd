extends CharacterBody2D

# Movement settings
@export var speed: float = 300.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0

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
@export var flashlight_cone_angle: float = 60.0  # Degrees

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

# Variables
var is_moving: bool = false
var is_invincible: bool = false
var is_dead: bool = false
var is_dying: bool = false
var is_knocked_back: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var can_exit: bool = false

# Signals
signal health_changed(new_health)
signal player_died

func _ready():
	add_to_group("player")
	print("Player ready!")
	
	# Initialize health
	current_health = max_health
	update_health_ui()
	
	# Initialize flashlight
	current_battery = max_battery
	setup_flashlight()
	update_battery_ui()
	
	# Debug check UI elements
	check_ui_elements()

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
	
	# Configure PointLight2D - FIXED FOR GODOT 4
	if flashlight_light:
		flashlight_light.enabled = false
		flashlight_light.energy = 3.0
		flashlight_light.texture_scale = 2.0  # FIXED: Godot 4 uses texture_scale instead of range
		flashlight_light.color = Color.WHITE
		flashlight_light.position = Vector2(0, -10)
		
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
			print("Created flashlight texture")
	
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
	handle_animation()
	move_and_slide()
	
	# Handle flashlight battery
	handle_flashlight(delta)
	
	# Update flashlight direction to face mouse
	if flashlight_on and flashlight_light:
		update_flashlight_direction()

func _input(event):
	# Exit with B key (Space)
	if Input.is_action_just_pressed("EXIT"):
		attempt_exit()
	
	# Collect with E key
	if Input.is_action_just_pressed("COLLECT"):
		# This can be used for item collection if needed
		pass
	
	# Toggle flashlight with F key
	if event is InputEventKey and event.keycode == KEY_F and event.pressed and not event.echo and not is_dead and not is_dying:
		toggle_flashlight()
		print("F key pressed - toggling flashlight")
	
	# Debug keys (using number keys to avoid conflicts)
	if event is InputEventKey && event.keycode == KEY_1 && event.pressed && !event.echo:
		debug_take_damage()
	
	if event is InputEventKey && event.keycode == KEY_2 && event.pressed && !event.echo:
		debug_heal()

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
			print("Enemy entered light: ", body.name)

func _on_flashlight_area_exited(body):
	if body.is_in_group("enemy") and body in enemies_in_light:
		enemies_in_light.erase(body)
		if body.has_method("exit_light"):
			body.exit_light()
			print("Enemy exited light: ", body.name)

func add_battery(amount: float):
	current_battery = min(current_battery + amount, max_battery)
	print("Battery recharged: ", amount, "% - Total: ", current_battery)
	update_battery_ui()

func get_battery_percentage() -> float:
	return current_battery / max_battery

func get_flashlight_state() -> bool:
	return flashlight_on and current_battery > 0

func get_flashlight_direction() -> Vector2:
	if flashlight_light:
		return Vector2(cos(flashlight_light.rotation), sin(flashlight_light.rotation))
	return Vector2.RIGHT

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
			velocity = velocity.move_toward(input_dir * speed, acceleration * delta)
			is_moving = true
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			is_moving = velocity.length() > 5.0

# FIXED: Animation logic now checks flashlight state for Walk LIGHT
func handle_animation():
	if not animated_sprite or is_dying:
		return
	
	if not animated_sprite.sprite_frames:
		return
		
	if is_moving:
		# FIXED: Check flashlight state for Walk LIGHT animation
		if flashlight_on and animated_sprite.sprite_frames.has_animation("Walk LIGHT"):
			if animated_sprite.animation != "Walk LIGHT":
				animated_sprite.play("Walk LIGHT")
				print("Playing Walk LIGHT animation!")
		elif animated_sprite.sprite_frames.has_animation("Walk"):
			if animated_sprite.animation != "Walk":
				animated_sprite.play("Walk")
	else:
		# Idle animation (unchanged)
		if animated_sprite.sprite_frames.has_animation("Idel"):
			if animated_sprite.animation != "Idel":
				animated_sprite.play("Idel")
		elif animated_sprite.sprite_frames.has_animation("idle"):
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")

func update_health_ui():
	# Update health bar with proper sizing
	if health_ui:
		var health_percentage = float(current_health) / float(max_health)
		health_ui.size.x = health_bar_max_width * health_percentage
		
		# Red color with varying intensity
		var red_intensity = lerp(0.7, 1.0, health_percentage)
		health_ui.color = Color(red_intensity, 0, 0, 1.0)
		
		print("Health bar updated: ", health_percentage * 100, "% - Width: ", health_ui.size.x)
	else:
		print("ERROR: Health UI not found!")
	
	# Update health text
	if health_label:
		health_label.text = str(current_health) + "/" + str(max_health)
		
		# Change text color when critical
		var health_percentage = float(current_health) / float(max_health)
		if health_percentage <= 0.25:
			health_label.add_theme_color_override("font_color", Color.RED)
		else:
			health_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		print("ERROR: Health Label not found!")
	
	# Update character portrait animation
	update_character_portrait()

func update_character_portrait():
	if not character_portrait:
		print("ERROR: No character portrait found!")
		return
		
	if not character_portrait.sprite_frames:
		print("ERROR: No sprite frames on character portrait!")
		return
	
	var available_anims = character_portrait.sprite_frames.get_animation_names()
	
	print("Health: ", current_health, "/", max_health)
	print("Is invincible: ", is_invincible)
	
	# Animation logic: crying during invincibility, normal when safe
	if is_invincible:
		# Show crying animation during invincibility (recently damaged)
		if character_portrait.sprite_frames.has_animation("crying"):
			if character_portrait.animation != "crying":
				print("Switching to crying animation - player recently damaged")
				character_portrait.play("crying")
		else:
			print("ERROR: 'crying' animation not found!")
			print("Available animations: ", available_anims)
	else:
		# Show normal animation when not invincible (safe period)
		if character_portrait.sprite_frames.has_animation("normal"):
			if character_portrait.animation != "normal":
				print("Switching to normal animation - player recovered")
				character_portrait.play("normal") 
		else:
			print("ERROR: 'normal' animation not found!")
			print("Available animations: ", available_anims)

# Key Collection System
func collect_key(key_id: String):
	if key_id in collected_keys:
		return  # Already have this key
		
	collected_keys.append(key_id)
	print("Collected key: ", key_id, " (", collected_keys.size(), "/", keys_needed_to_escape, ")")
	
	# Update UI
	update_key_ui()
	
	# Check if can escape
	check_escape_condition()

func update_key_ui():
	if key_ui:
		key_ui.text = "Keys: " + str(collected_keys.size()) + "/" + str(keys_needed_to_escape)

func check_escape_condition():
	if collected_keys.size() >= keys_needed_to_escape:
		print("All keys collected! Exit is now available!")
		# Notify exit door or enable escape
		var exit_doors = get_tree().get_nodes_in_group("exit_door")
		for door in exit_doors:
			if door.has_method("enable_exit"):
				door.enable_exit()

func can_escape() -> bool:
	return collected_keys.size() >= keys_needed_to_escape

# Combat System
func take_damage(amount: int, attacker_position: Vector2 = Vector2.ZERO):
	if is_invincible or is_dead or is_dying:
		print("Damage blocked - invincible:", is_invincible, " dead:", is_dead, " dying:", is_dying)
		return
		
	current_health -= amount
	current_health = max(current_health, 0)
	
	print("Player took ", amount, " damage! Health: ", current_health, "/", max_health)
	
	health_changed.emit(current_health)
	update_health_ui()
	
	# Apply knockback to prevent collision glitches
	apply_knockback(attacker_position)
	
	# UI shake effect
	ui_shake_effect()
	
	hurt_effect()
	
	if current_health <= 0:
		die()
	else:
		become_invincible()

func apply_knockback(attacker_position: Vector2):
	if attacker_position != Vector2.ZERO:
		# Calculate knockback direction (away from attacker)
		var knockback_direction = (global_position - attacker_position).normalized()
		
		# If no valid direction, use a random direction
		if knockback_direction.length() < 0.1:
			knockback_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		
		knockback_velocity = knockback_direction * knockback_force
		is_knocked_back = true
		
		print("Knockback applied! Direction: ", knockback_direction)
		
		# Stop knockback after duration
		get_tree().create_timer(knockback_duration).timeout.connect(stop_knockback)
	else:
		# No attacker position provided, use random knockback
		var random_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		knockback_velocity = random_direction * knockback_force
		is_knocked_back = true
		
		print("Random knockback applied!")
		get_tree().create_timer(knockback_duration).timeout.connect(stop_knockback)

func stop_knockback():
	is_knocked_back = false
	knockback_velocity = Vector2.ZERO
	print("Knockback ended")

func become_invincible():
	is_invincible = true
	print("Player is now invincible for ", invincible_time, " seconds")
	
	# Blinking effect during invincibility
	if animated_sprite:
		var blink_duration = 0.1
		var total_blinks = int(invincible_time / blink_duration)
		
		for i in range(total_blinks):
			if not is_dead and not is_dying:
				# Fade out
				animated_sprite.modulate.a = 0.3
				await get_tree().create_timer(blink_duration / 2).timeout
				
				if not is_dead and not is_dying:
					# Fade in
					animated_sprite.modulate.a = 1.0
					await get_tree().create_timer(blink_duration / 2).timeout
	
	# Ensure sprite is fully visible when invincibility ends
	if animated_sprite and not is_dead and not is_dying:
		animated_sprite.modulate.a = 1.0
	
	is_invincible = false
	print("Player is no longer invincible")

func hurt_effect():
	# Play hurt animation if available
	if animated_sprite and animated_sprite.sprite_frames.has_animation("hurt"):
		animated_sprite.play("hurt")
		get_tree().create_timer(0.5).timeout.connect(handle_animation)
	
	# Initial damage flash (red)
	if animated_sprite:
		animated_sprite.modulate = Color.RED
		var flash_tween = create_tween()
		flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)
		flash_tween.tween_callback(extra_damage_blink)

func extra_damage_blink():
	# Additional quick blink when first taking damage
	if animated_sprite and not is_invincible:
		animated_sprite.modulate.a = 0.5
		var blink_tween = create_tween()
		blink_tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.15)

func ui_shake_effect():
	# Shake the entire UI background for impact
	if ui_background:
		var original_pos = ui_background.position
		var shake_duration = 0.3
		var shake_intensity = 3.0
		
		for i in range(6):
			var shake_offset = Vector2(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)
			ui_background.position = original_pos + shake_offset
			await get_tree().create_timer(shake_duration / 12.0).timeout
			ui_background.position = original_pos
			await get_tree().create_timer(shake_duration / 12.0).timeout
		
		ui_background.position = original_pos

func heal(amount: int):
	if is_dead or is_dying:
		return
		
	current_health += amount
	current_health = min(current_health, max_health)
	
	print("Player healed ", amount, "! Health: ", current_health, "/", max_health)
	
	health_changed.emit(current_health)
	update_health_ui()
	
	# Healing effect - portrait glows green briefly
	if character_portrait:
		character_portrait.modulate = Color.GREEN
		var tween = create_tween()
		tween.tween_property(character_portrait, "modulate", Color.WHITE, 0.5)

func die():
	if is_dead or is_dying:
		return
		
	is_dying = true
	print("Player is dying! Playing death animation...")
	
	# Stop movement and knockback
	velocity = Vector2.ZERO
	is_knocked_back = false
	knockback_velocity = Vector2.ZERO
	
	# Turn off flashlight
	set_flashlight(false)
	
	# Force crying animation on portrait
	if character_portrait and character_portrait.sprite_frames and character_portrait.sprite_frames.has_animation("crying"):
		character_portrait.play("crying")
	
	# Play death animation ONCE
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("dead"):
		print("Playing death animation (no loop)")
		animated_sprite.play("dead")
		
		if not animated_sprite.animation_finished.is_connected(_on_death_animation_finished):
			animated_sprite.animation_finished.connect(_on_death_animation_finished)
		
		get_tree().create_timer(3.0).timeout.connect(_on_death_animation_finished)
	else:
		print("No death animation found, waiting 1.5 seconds")
		get_tree().create_timer(1.5).timeout.connect(_on_death_animation_finished)

func _on_death_animation_finished():
	if not is_dying:
		return
		
	if animated_sprite and animated_sprite.animation_finished.is_connected(_on_death_animation_finished):
		animated_sprite.animation_finished.disconnect(_on_death_animation_finished)
	
	print("Death animation finished!")
	
	is_dead = true
	is_dying = false
	
	player_died.emit()
	
	print("Restarting game in 1 second...")
	await get_tree().create_timer(1.0).timeout
	restart_game()

func restart_game():
	print("Restarting the game scene...")
	get_tree().reload_current_scene()

# Enemy interaction
func get_damaged_by_enemy(damage: int, enemy_position: Vector2 = Vector2.ZERO):
	take_damage(damage, enemy_position)

# Exit system
func set_can_exit(value: bool):
	can_exit = value

# Debug functions (keeping your original debug keys)
func debug_take_damage():
	var fake_attacker_pos = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
	take_damage(15, fake_attacker_pos)
	print("Debug: Took 15 damage with knockback")

func debug_heal():
	heal(20)
	print("Debug: Healed 20 HP")

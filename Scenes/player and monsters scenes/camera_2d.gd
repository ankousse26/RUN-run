extends Camera2D

# Camera shake settings - Very gentle
@export var shake_intensity: float = 0.3  # Even lower
@export var shake_duration: float = 0.15  # Shorter duration
@export var shake_decay: float = 8.0  # Faster fade
@export var max_shake_offset: float = 2.0  # Much smaller movement

# Camera follow settings
@export var follow_speed: float = 4.0
@export var follow_target: Node2D
@export var follow_smoothing: bool = true

# Shake variables
var shake_timer: float = 0.0
var shake_strength: float = 0.0
var initial_position: Vector2
var random_shake: Vector2 = Vector2.ZERO

func _ready():
	# Store initial position
	initial_position = global_position
	
	# Find player automatically if no target assigned
	if not follow_target:
		follow_target = get_tree().get_first_node_in_group("player")
		if follow_target:
			print("Camera auto-found player target: ", follow_target.name)
	
	# Connect to player damage signal if player exists
	if follow_target and follow_target.has_signal("health_changed"):
		follow_target.health_changed.connect(_on_player_damaged)
		print("Camera connected to player damage signal")
	
	# Also check for player_died signal for stronger shake
	if follow_target and follow_target.has_signal("player_died"):
		follow_target.player_died.connect(_on_player_died)

func _physics_process(delta):
	# Handle camera follow
	handle_camera_follow(delta)
	
	# Handle camera shake
	handle_camera_shake(delta)

func handle_camera_follow(delta):
	if not follow_target:
		return
	
	var target_position = follow_target.global_position
	
	if follow_smoothing:
		# Smooth camera follow
		global_position = global_position.lerp(target_position, follow_speed * delta)
	else:
		# Instant camera follow
		global_position = target_position

func handle_camera_shake(delta):
	if shake_timer > 0:
		shake_timer -= delta
		
		# Reduce shake strength over time
		shake_strength = shake_strength * (1.0 - shake_decay * delta)
		
		# Generate random shake offset
		random_shake = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		
		# Clamp shake to maximum offset
		random_shake = random_shake.limit_length(max_shake_offset)
		
		# Apply shake offset
		offset = random_shake
		
		# Stop shake when timer runs out or strength is very low
		if shake_timer <= 0 or shake_strength < 0.1:
			shake_timer = 0
			shake_strength = 0
			offset = Vector2.ZERO
	else:
		# No shake - ensure offset is zero
		offset = Vector2.ZERO

# Public method to trigger camera shake
func shake_camera(intensity: float = -1, duration: float = -1):
	# Use default values if not provided
	var final_intensity = intensity if intensity > 0 else shake_intensity
	var final_duration = duration if duration > 0 else shake_duration
	
	print("Camera shake triggered - Intensity: ", final_intensity, ", Duration: ", final_duration)
	
	# Set shake parameters
	shake_strength = final_intensity
	shake_timer = final_duration

# Signal handlers - MUCH gentler values
func _on_player_damaged(new_health: int):
	# Very subtle shake - just a tiny nudge
	var health_percentage = float(new_health) / 100.0
	
	if new_health <= 0:
		# Death shake - noticeable but not overwhelming
		shake_camera(1.5, 0.3)  # Was 25.0, 0.8
	elif health_percentage <= 0.2:
		# Low health - light shake
		shake_camera(1.0, 0.2)  # Was 15.0, 0.5
	elif health_percentage <= 0.5:
		# Medium health - very light shake
		shake_camera(0.7, 0.15)  # Was 12.0, 0.4
	else:
		# High health - barely noticeable
		shake_camera(0.5, 0.1)  # Was 10.0, 0.3

func _on_player_died():
	# Death shake - a bit more noticeable but still gentle
	shake_camera(2.0, 0.4)  # Was 30.0, 1.0
	print("Death shake triggered!")

# Utility methods - All much gentler
func light_shake():
	shake_camera(0.3, 0.1)  # Was 5.0, 0.2

func medium_shake():
	shake_camera(0.6, 0.15)  # Was 12.0, 0.4

func strong_shake():
	shake_camera(1.0, 0.2)  # Was 20.0, 0.6

func explosion_shake():
	shake_camera(1.5, 0.25)  # Was 25.0, 0.8

# Method to change follow target
func set_follow_target(new_target: Node2D):
	# Disconnect from old target
	if follow_target:
		if follow_target.has_signal("health_changed") and follow_target.health_changed.is_connected(_on_player_damaged):
			follow_target.health_changed.disconnect(_on_player_damaged)
		if follow_target.has_signal("player_died") and follow_target.player_died.is_connected(_on_player_died):
			follow_target.player_died.disconnect(_on_player_died)
	
	# Set new target
	follow_target = new_target
	
	# Connect to new target
	if follow_target:
		if follow_target.has_signal("health_changed"):
			follow_target.health_changed.connect(_on_player_damaged)
		if follow_target.has_signal("player_died"):
			follow_target.player_died.connect(_on_player_died)
		print("Camera target changed to: ", follow_target.name)

# Debug method - Much gentler
func debug_shake():
	shake_camera(0.8, 0.2)  # Was 15.0, 0.5
	print("Debug shake triggered!")

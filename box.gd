extends RigidBody2D

@export var push_responsiveness: float = 1.0
@export var friction_strength: float = 15.0
@export var max_speed: float = 200.0

func _ready():
	add_to_group("pushable")
	
	# Configure RigidBody2D for classic box behavior
	gravity_scale = 0  # No gravity in top-down
	linear_damp = 8.0  # Natural slowdown
	angular_damp = 20.0  # Prevent spinning
	lock_rotation = true  # Keep box upright
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY  # Prevent tunneling through walls
	
	print("Pushable box ready: ", name)

func push_box(direction: Vector2, force: float):
	# Apply push force in the specified direction
	var push_force = direction * force * push_responsiveness
	apply_central_impulse(push_force)
	
	# Limit speed
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed
	
	# Debug
	var direction_name = ""
	if abs(direction.x) > abs(direction.y):
		direction_name = "RIGHT" if direction.x > 0 else "LEFT"
	else:
		direction_name = "DOWN" if direction.y > 0 else "UP"
	
	print("Box pushed ", direction_name, " with force ", force)

func _physics_process(delta):
	# Apply extra friction when moving slowly
	if linear_velocity.length() < 50 and linear_velocity.length() > 5:
		var friction_force = -linear_velocity.normalized() * friction_strength
		apply_central_force(friction_force)
	
	# Stop very slow movement
	if linear_velocity.length() < 5:
		linear_velocity = Vector2.ZERO

extends RigidBody2D

@export var friction_strength: float = 12.0
@export var max_speed: float = 180.0

func _ready():
	add_to_group("pushable")
	
	# Godot 4.4.1 settings
	gravity_scale = 0
	linear_damp = 6.0
	angular_damp = 20.0
	lock_rotation = true
	
	# In Godot 4, freeze properties work differently
	# By default, nothing is frozen, so we don't need to set anything
	# If you want to be explicit:
	freeze = false
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	
	# Enable collision
	collision_layer = 8  # Layer 4
	collision_mask = 1   # Layer 1
	
	print("Box ready for push/pull: ", name)

# FIXED: This was "func *physics*process(delta):" - the asterisks broke it
func _physics_process(delta):
	# Apply extra friction when moving slowly
	if linear_velocity.length() < 40 and linear_velocity.length() > 5:
		var friction_force = -linear_velocity.normalized() * friction_strength
		apply_central_force(friction_force)
	
	# Stop very slow movement
	if linear_velocity.length() < 5:
		linear_velocity = Vector2.ZERO
	
	# Limit maximum speed
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed

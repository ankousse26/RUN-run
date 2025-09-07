extends Node2D

# Trap settings
@export var damage: int = 25
@export var activation_delay: float = 0.2  # Delay before spikes come up
@export var reset_time: float = 2.0  # Time before trap can trigger again
@export var uses: int = -1  # -1 for infinite uses, positive number for limited uses
@export var targets_enemies: bool = true
@export var targets_player: bool = false

# References
@onready var animated_sprite = $AnimatedSprite2D
@onready var detect_area = $detect_area

# State management
enum TrapState { IDLE, TRIGGERED, COOLDOWN, DEPLETED }
var current_state: TrapState = TrapState.IDLE
var current_uses: int = 0
var bodies_in_range: Array = []

# Timers
var activation_timer: Timer
var cooldown_timer: Timer

func _ready():
	# Set up detection area
	if detect_area:
		detect_area.body_entered.connect(_on_body_entered)
		detect_area.body_exited.connect(_on_body_exited)
		detect_area.monitoring = true
	
	# Create activation delay timer
	activation_timer = Timer.new()
	activation_timer.one_shot = true
	activation_timer.wait_time = activation_delay
	activation_timer.timeout.connect(_activate_trap)
	add_child(activation_timer)
	
	# Create cooldown timer
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.wait_time = reset_time
	cooldown_timer.timeout.connect(_reset_trap)
	add_child(cooldown_timer)
	
	# Initialize uses
	current_uses = uses
	
	# Start with idle animation
	if animated_sprite:
		animated_sprite.play("idel")
	
	print("Spike trap initialized - Damage: ", damage, " Uses: ", uses)

func _on_body_entered(body):
	# Check if we should react to this body
	if not _should_trigger_for(body):
		return
	
	bodies_in_range.append(body)
	
	# Only trigger if trap is idle
	if current_state == TrapState.IDLE:
		_trigger_trap()

func _on_body_exited(body):
	bodies_in_range.erase(body)

func _should_trigger_for(body) -> bool:
	# Check if trap is active
	if current_state != TrapState.IDLE:
		return false
	
	# Check if trap is depleted
	if current_uses == 0:
		return false
	
	# Check target type
	if targets_enemies and body.is_in_group("enemy"):
		return true
	
	if targets_player and body.is_in_group("player"):
		return true
	
	return false

func _trigger_trap():
	if current_state != TrapState.IDLE:
		return
	
	current_state = TrapState.TRIGGERED
	print("Spike trap triggered!")
	
	# Start activation delay
	if activation_delay > 0:
		activation_timer.start()
		# Optional: Play a warning animation or sound
	else:
		_activate_trap()

func _activate_trap():
	# Play attack animation
	if animated_sprite:
		animated_sprite.play("attack")
		# Connect to animation finished if not already connected
		if not animated_sprite.animation_finished.is_connected(_on_attack_animation_finished):
			animated_sprite.animation_finished.connect(_on_attack_animation_finished)
	
	# Deal damage to all bodies in range
	for body in bodies_in_range:
		_apply_damage(body)
	
	# Reduce uses if limited
	if uses > 0:
		current_uses -= 1
		print("Spike trap uses remaining: ", current_uses)
		
		if current_uses <= 0:
			_deplete_trap()
			return
	
	# Start cooldown
	current_state = TrapState.COOLDOWN
	cooldown_timer.start()

func _apply_damage(body):
	# Apply damage based on target type
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
			print("Spike trap dealt ", damage, " damage to enemy: ", body.name)
		elif body.has_method("hurt"):
			body.hurt(damage)
	elif body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
			print("Spike trap dealt ", damage, " damage to player!")
		elif body.has_method("get_damaged_by_enemy"):
			body.get_damaged_by_enemy(damage, global_position)

func _on_attack_animation_finished():
	# Return to idle animation after attack
	if animated_sprite and current_state != TrapState.DEPLETED:
		animated_sprite.play("idel")

func _reset_trap():
	if current_state == TrapState.DEPLETED:
		return
	
	current_state = TrapState.IDLE
	print("Spike trap reset and ready")
	
	# Check if any bodies are still in range
	if bodies_in_range.size() > 0:
		# Re-trigger if enemies still standing on trap
		for body in bodies_in_range:
			if _should_trigger_for(body):
				_trigger_trap()
				break

func _deplete_trap():
	current_state = TrapState.DEPLETED
	print("Spike trap depleted!")
	
	# Optional: Change visual to show trap is used up
	if animated_sprite:
		animated_sprite.modulate = Color(0.5, 0.5, 0.5, 0.5)
	
	# Optional: Disable detection
	if detect_area:
		detect_area.monitoring = false
	
	# Optional: Remove trap after a delay
	var remove_timer = Timer.new()
	remove_timer.one_shot = true
	remove_timer.wait_time = 3.0
	remove_timer.timeout.connect(queue_free)
	add_child(remove_timer)
	remove_timer.start()

# Public methods for external control
func activate_manually():
	if current_state == TrapState.IDLE:
		_trigger_trap()

func set_damage(new_damage: int):
	damage = new_damage

func set_uses(new_uses: int):
	uses = new_uses
	current_uses = new_uses

func get_state() -> TrapState:
	return current_state

func reset():
	current_state = TrapState.IDLE
	current_uses = uses
	bodies_in_range.clear()
	if animated_sprite:
		animated_sprite.play("idel")
		animated_sprite.modulate = Color.WHITE

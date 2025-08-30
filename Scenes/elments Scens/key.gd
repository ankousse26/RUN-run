extends Area2D

@export var key_id: String = "key_1"
@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D

var is_collected: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	
	# Make sure this Area2D doesn't interfere with combat
	collision_layer = 4
	collision_mask = 1
	
	print("Key ready: ", key_id)
	
	# Start flashing effect to make it more noticeable
	add_flashing_effect()
	add_floating_effect()

func _on_body_entered(body):
	if body.is_in_group("player") and not is_collected:
		collect_key(body)

func collect_key(player):
	if is_collected:
		return
		
	is_collected = true
	print("Key collected: ", key_id)
	
	# Play collection animation instead of just hiding
	play_collection_animation()
	
	# Notify player
	if player.has_method("collect_key"):
		player.collect_key(key_id)
	
	# Remove from scene after animation
	get_tree().create_timer(0.5).timeout.connect(queue_free)

func play_collection_animation():
	# Disable collision immediately
	if collision_shape:
		collision_shape.disabled = true
	
	# Flash white then shrink away
	if sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Flash white
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(sprite, "modulate", Color.YELLOW, 0.1).set_delay(0.1)
		tween.tween_property(sprite, "modulate", Color.TRANSPARENT, 0.2).set_delay(0.2)
		
		# Scale up then shrink
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.2)
		tween.tween_property(sprite, "scale", Vector2(0.1, 0.1), 0.3).set_delay(0.2)
		
		# Create sparkle effects
		create_sparkle_effects()

func create_sparkle_effects():
	# Create multiple sparkle particles
	for i in range(3):
		var particles = CPUParticles2D.new()
		get_parent().add_child(particles)
		particles.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		particles.emitting = true
		particles.amount = 8
		particles.lifetime = 0.4
		particles.one_shot = true
		particles.initial_velocity_min = 30
		particles.initial_velocity_max = 100
		particles.spread = 360
		particles.color = Color.YELLOW
		particles.scale_amount_min = 0.3
		particles.scale_amount_max = 0.8
		
		# Clean up
		get_tree().create_timer(0.5).timeout.connect(particles.queue_free)

func add_flashing_effect():
	# Subtle flash to make key noticeable
	if sprite:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "modulate", Color(1.2, 1.2, 0.8), 0.5)  # Yellow tint
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)  # Normal

func add_floating_effect():
	# Gentle up/down floating
	if sprite:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "position:y", sprite.position.y - 5, 1.2).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "position:y", sprite.position.y + 5, 1.2).set_trans(Tween.TRANS_SINE)

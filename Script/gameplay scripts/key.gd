extends Area2D

@export var key_id: String = "key_1"
@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D
@onready var detection_area = $DetectionArea
@onready var key_label = $Label

var is_collected: bool = false
var text_tween: Tween  # This remembers our text animation

func _ready():
	# Main pickup area
	body_entered.connect(_on_body_entered)
	
	# Detection area for showing text
	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)
	
	# Set up the label (this is the "KEY" text)
	setup_label()
	
	# Set collision layers
	collision_layer = 4
	collision_mask = 1
	
	# Make sure DetectionArea has different collision settings
	detection_area.collision_layer = 2
	detection_area.collision_mask = 1
	
	print("Key ready: ", key_id)
	
	# Your existing effects
	add_flashing_effect()
	add_floating_effect()

# This makes the "KEY" text look pretty
func setup_label():
	# IMPORTANT: Start invisible and tiny
	key_label.visible = false
	key_label.scale = Vector2.ZERO  # Make it tiny (size 0)
	key_label.text = "KEY"
	
	# Make the text look fancy
	key_label.add_theme_font_size_override("font_size", 20)  # Bigger text
	key_label.add_theme_color_override("font_color", Color.GOLD)  # Gold color
	
	# Add a dark outline so text is easy to read
	key_label.add_theme_color_override("font_outline_color", Color.BLACK)
	key_label.add_theme_constant_override("outline_size", 2)
	
	# Center the text
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

# When player gets CLOSE to key (enters big circle)
func _on_detection_entered(body):
	print("Detection entered by: ", body.name)
	if body.is_in_group("player") and not is_collected:
		print("Showing KEY text with cool animation!")
		show_key_text_animated()

# When player moves AWAY from key (exits big circle)
func _on_detection_exited(body):
	print("Detection exited by: ", body.name)
	if body.is_in_group("player") and not is_collected:
		print("Hiding KEY text with cool animation!")
		hide_key_text_animated()

# This makes the "KEY" text POP UP smoothly!
func show_key_text_animated():
	# Stop any current animation
	if text_tween:
		text_tween.kill()
	
	# Make the text visible but still tiny
	key_label.visible = true
	key_label.scale = Vector2.ZERO
	
	# Create smooth growing animation
	text_tween = create_tween()
	text_tween.set_parallel(true)  # Multiple animations at once
	
	# Grow from tiny to normal size with a bounce!
	text_tween.tween_property(key_label, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	text_tween.tween_property(key_label, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.2)
	
	# Fade in the color
	key_label.modulate.a = 0  # Start transparent
	text_tween.tween_property(key_label, "modulate:a", 1.0, 0.3)

# This makes the "KEY" text shrink and disappear smoothly
func hide_key_text_animated():
	if not key_label.visible:
		return
	
	# Stop any current animation
	if text_tween:
		text_tween.kill()
	
	# Create shrinking animation
	text_tween = create_tween()
	text_tween.set_parallel(true)
	
	# Shrink to tiny
	text_tween.tween_property(key_label, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Fade out
	text_tween.tween_property(key_label, "modulate:a", 0.0, 0.15)
	
	# Hide when done
	text_tween.tween_callback(func(): key_label.visible = false).set_delay(0.15)

# When player TOUCHES the key (enters small circle)
func _on_body_entered(body):
	print("Pickup area entered by: ", body.name)
	if body.is_in_group("player") and not is_collected:
		collect_key(body)

# This happens when you collect the key!
func collect_key(player):
	if is_collected:
		return
		
	is_collected = true
	print("Key collected: ", key_id)
	
	# Cool text flying away effect!
	play_text_collection_effect()
	
	# Disable collision immediately
	if collision_shape:
		collision_shape.disabled = true
	
	# Disable detection area too
	detection_area.monitoring = false
	
	# Play collection animation
	play_collection_animation()
	
	# Notify player
	if player.has_method("collect_key"):
		player.collect_key(key_id)
	
	# Remove from scene after animation (wait a bit longer for the shake to finish)
	get_tree().create_timer(0.7).timeout.connect(queue_free)

# NEW! This makes the "KEY" text fly up when collected
func play_text_collection_effect():
	if not key_label.visible:
		return
	
	# Stop any current text animation
	if text_tween:
		text_tween.kill()
	
	# Make sure text is visible and normal
	key_label.visible = true
	key_label.modulate = Color.GOLD
	key_label.scale = Vector2(1.0, 1.0)
	
	# Create flying effect
	text_tween = create_tween()
	text_tween.set_parallel(true)
	
	# Fly upward
	var start_pos = key_label.position
	text_tween.tween_property(key_label, "position", start_pos + Vector2(0, -50), 0.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Fade out
	text_tween.tween_property(key_label, "modulate:a", 0.0, 0.5).set_delay(0.3)
	
	# Get bigger then smaller
	text_tween.tween_property(key_label, "scale", Vector2(1.5, 1.5), 0.2)
	text_tween.tween_property(key_label, "scale", Vector2(0.5, 0.5), 0.6).set_delay(0.2)

# Your existing collection animation (keep this the same)
func play_collection_animation():
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
		
		create_sparkle_effects()

# Your existing sparkle effects (keep this the same)
func create_sparkle_effects():
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
		
		get_tree().create_timer(0.5).timeout.connect(particles.queue_free)

# Your existing flashing effect (keep this the same)
func add_flashing_effect():
	if sprite:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "modulate", Color(1.2, 1.2, 0.8), 0.5)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)

# Your existing floating effect (keep this the same)
func add_floating_effect():
	if sprite:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "position:y", sprite.position.y - 5, 1.2).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "position:y", sprite.position.y + 5, 1.2).set_trans(Tween.TRANS_SINE)

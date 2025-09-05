extends Area2D

# Item properties
@export var item_name: String = "wood"  # What material this gives
@export var min_amount: int = 1         # Minimum amount to give
@export var max_amount: int = 10        # Maximum amount to give
@export var auto_pickup: bool = true    # Pick up on touch or require E key
@export var pickup_text: String = "collect"

# References
@onready var sprite = $Wood
@onready var collision_shape = $CollisionShape2D
@onready var pickup_label = $PickupLabel
@onready var detection_area = $DetectionArea

# Variables
var is_collected: bool = false
var player_nearby: bool = false
var player_in_area: CharacterBody2D = null
var item_amount: int = 0  # Will be set randomly
var is_collecting: bool = false  # Prevent double collection during animation

func _ready():
	add_to_group("collectible")
	
	# Randomize the amount this item will give
	item_amount = randi_range(min_amount, max_amount)
	print("Collectible item ready: ", item_name, " (Amount: ", item_amount, ")")
	
	# Setup main pickup area
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Setup detection area for showing pickup text
	if detection_area:
		detection_area.body_entered.connect(_on_detection_entered)
		detection_area.body_exited.connect(_on_detection_exited)
		detection_area.monitoring = true
		detection_area.monitorable = false
		print("DetectionArea signals connected successfully")
	else:
		print("ERROR: DetectionArea not found!")
	
	# Setup pickup label
	setup_pickup_label()
	
	# Set collision layers
	collision_layer = 8  # Collectibles layer
	collision_mask = 1   # Detects player layer
	
	# Make sure DetectionArea has correct collision settings
	if detection_area:
		detection_area.collision_layer = 0
		detection_area.collision_mask = 1
	
	# Visual effects
	add_floating_effect()
	add_glow_effect()
	add_shimmer_effect()  # New shimmer effect
	
	# Setup item appearance based on type
	setup_item_appearance()

func setup_pickup_label():
	if pickup_label:
		pickup_label.visible = false
		pickup_label.modulate.a = 0.0
		# Update pickup text to show the amount
		pickup_label.text = pickup_text + " (" + str(item_amount) + ")"
		pickup_label.add_theme_font_size_override("font_size", 14)
		pickup_label.add_theme_color_override("font_color", Color.WHITE)
		pickup_label.add_theme_color_override("font_outline_color", Color.BLACK)
		pickup_label.add_theme_constant_override("outline_size", 2)
		pickup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pickup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		print("Pickup label setup complete - showing amount: ", item_amount)
	else:
		print("ERROR: PickupLabel not found!")

func setup_item_appearance():
	if not sprite:
		return
	
	# Set sprite and color based on item type with enhanced colors
	match item_name:
		"wood":
			sprite.modulate = Color(0.7, 0.5, 0.3)  # Richer brown
		"metal":
			sprite.modulate = Color(0.8, 0.8, 0.9)  # Brighter silver
		"bones":
			sprite.modulate = Color(0.95, 0.95, 0.85)  # Cleaner bone white
		"blood":
			sprite.modulate = Color(0.9, 0.2, 0.2)  # Vibrant red
		"stone":
			sprite.modulate = Color(0.6, 0.6, 0.6)  # Lighter gray
		"rope":
			sprite.modulate = Color(0.8, 0.7, 0.5)  # Warmer tan
		_:
			sprite.modulate = Color.WHITE

func _input(event):
	# Manual pickup with E key
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_E):
		if player_nearby and not auto_pickup and not is_collected and not is_collecting:
			start_collection_sequence()

func _on_body_entered(body):
	if body.is_in_group("player") and not is_collected and not is_collecting:
		player_in_area = body
		
		if auto_pickup:
			# Add a small delay for auto pickup to show anticipation
			start_collection_sequence()
		else:
			# Manual pickup - just mark player as nearby
			player_nearby = true
			show_pickup_indicator()  # New indicator
			print("Press E to collect ", item_amount, " ", item_name)

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_area = null
		player_nearby = false
		hide_pickup_indicator()

func _on_detection_entered(body):
	if body.is_in_group("player") and not is_collected and not is_collecting:
		show_pickup_text()

func _on_detection_exited(body):
	if body.is_in_group("player"):
		hide_pickup_text()

func show_pickup_indicator():
	# Pulse effect to indicate item is ready for pickup
	if sprite and not is_collecting:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.3)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.3)

func hide_pickup_indicator():
	# Stop the pulse effect
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)

func show_pickup_text():
	if pickup_label:
		pickup_label.visible = true
		# Animate text appearing with bounce
		var tween = create_tween()
		pickup_label.modulate.a = 0
		pickup_label.scale = Vector2(0.8, 0.8)
		tween.set_parallel(true)
		tween.tween_property(pickup_label, "modulate:a", 1.0, 0.3)
		tween.tween_property(pickup_label, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_pickup_text():
	if pickup_label:
		# Animate text disappearing
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(pickup_label, "modulate:a", 0.0, 0.2)
		tween.tween_property(pickup_label, "scale", Vector2(0.8, 0.8), 0.2)
		tween.tween_callback(func(): pickup_label.visible = false).set_delay(0.2)

func start_collection_sequence():
	if is_collected or is_collecting:
		return
	
	is_collecting = true
	
	# Hide pickup text immediately
	hide_pickup_text()
	hide_pickup_indicator()
	
	# Play anticipation effects
	play_anticipation_flash()
	
	# Wait for flash, then collect
	await get_tree().create_timer(0.4).timeout
	collect_item()

func play_anticipation_flash():
	if not sprite:
		return
	
	# Create multiple flash effects
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Quick bright flash sequence
	var original_modulate = sprite.modulate
	var flash_color = original_modulate * 2.5  # Very bright
	
	# First flash - quick and bright
	tween.tween_property(sprite, "modulate", flash_color, 0.1)
	tween.tween_property(sprite, "modulate", original_modulate, 0.1).set_delay(0.1)
	
	# Second flash - slightly delayed
	tween.tween_property(sprite, "modulate", flash_color * 1.5, 0.08).set_delay(0.25)
	tween.tween_property(sprite, "modulate", original_modulate, 0.08).set_delay(0.33)
	
	# Scale pulse during flash
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.15)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.25).set_delay(0.15)
	
	# Create anticipation particles
	create_anticipation_particles()

func create_anticipation_particles():
	# Create small sparkle effect before collection
	var particles = CPUParticles2D.new()
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	particles.amount = 8
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.initial_velocity_min = 15
	particles.initial_velocity_max = 35
	particles.spread = 360
	particles.gravity = Vector2(0, -20)  # Slight upward drift
	
	# Color based on item type
	match item_name:
		"wood":
			particles.color = Color(0.8, 0.6, 0.4, 0.8)
		"metal":
			particles.color = Color(0.9, 0.9, 1.0, 0.8)
		"bones":
			particles.color = Color(1.0, 1.0, 0.9, 0.8)
		"blood":
			particles.color = Color(1.0, 0.4, 0.4, 0.8)
		"stone":
			particles.color = Color(0.7, 0.7, 0.7, 0.8)
		"rope":
			particles.color = Color(0.9, 0.8, 0.6, 0.8)
		_:
			particles.color = Color(1.0, 1.0, 0.5, 0.8)
	
	particles.scale_amount_min = 0.2
	particles.scale_amount_max = 0.5
	
	# Clean up particles
	get_tree().create_timer(0.6).timeout.connect(particles.queue_free)

func collect_item():
	if is_collected:
		return
	
	# Find the player and add item to their inventory
	var player = player_in_area
	if not player and player_nearby:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	if not player:
		print("ERROR: Could not find player to give item to")
		is_collecting = false
		return
	
	# Give item to player
	if player.has_method("collect_item"):
		player.collect_item(item_name, item_amount)
		print("Player collected: ", item_amount, " ", item_name)
	elif player.has_method("add_material"):
		player.add_material(item_name, item_amount)
		print("Player collected: ", item_amount, " ", item_name)
	else:
		print("ERROR: Player doesn't have collect_item or add_material method")
		is_collecting = false
		return
	
	# Show collection message BEFORE starting animations
	show_collection_message()
	
	# Mark as collected and play collection animation
	is_collected = true
	play_collection_animation()
	
	# Disable collision immediately
	if collision_shape:
		collision_shape.disabled = true
	if detection_area:
		detection_area.monitoring = false
	
	# Remove item after animation
	get_tree().create_timer(1.2).timeout.connect(queue_free)

func show_collection_message():
	# Create floating "+X ItemName" message with fast animation
	var message_label = Label.new()
	get_parent().add_child(message_label)
	
	# Setup the message text
	var message_text = "+" + str(item_amount) + " " + item_name.capitalize()
	message_label.text = message_text
	message_label.global_position = global_position + Vector2(-40, -30)
	
	# Styling
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 2)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Color based on item type
	match item_name:
		"wood":
			message_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
		"metal":
			message_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
		"bones":
			message_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9))
		"blood":
			message_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		"stone":
			message_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		"rope":
			message_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		_:
			message_label.add_theme_color_override("font_color", Color.YELLOW)
	
	# Fast animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Quick float upward
	var end_position = message_label.global_position + Vector2(0, -50)
	tween.tween_property(message_label, "global_position", end_position, 1.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Quick fade out
	tween.tween_property(message_label, "modulate:a", 0.0, 0.6).set_delay(0.4)
	
	# Quick scale animation
	message_label.scale = Vector2(0.7, 0.7)
	tween.tween_property(message_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(message_label, "scale", Vector2(0.8, 0.8), 0.4).set_delay(0.6)
	
	# Quick cleanup
	get_tree().create_timer(1.2).timeout.connect(message_label.queue_free)
	
	print("Showing collection message: ", message_text)

func play_collection_animation():
	if sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Enhanced flash and fade
		var bright_flash = sprite.modulate * 3.0
		tween.tween_property(sprite, "modulate", bright_flash, 0.15)
		tween.tween_property(sprite, "modulate", Color.TRANSPARENT, 0.4).set_delay(0.15)
		
		# Enhanced movement and scaling
		var start_pos = sprite.position
		tween.tween_property(sprite, "position", start_pos + Vector2(0, -40), 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", Vector2(1.8, 1.8), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", Vector2(0.3, 0.3), 0.3).set_delay(0.25)
		
		# Rotation for extra flair
		tween.tween_property(sprite, "rotation", deg_to_rad(360), 0.5)
		
		# Create enhanced particle effect
		create_pickup_particles()

func create_pickup_particles():
	# Enhanced particle effect when collected
	var particles = CPUParticles2D.new()
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	particles.amount = 25  # More particles
	particles.lifetime = 1.2
	particles.one_shot = true
	particles.initial_velocity_min = 30
	particles.initial_velocity_max = 80
	particles.spread = 360
	particles.gravity = Vector2(0, 40)
	
	# Enhanced colors based on item type
	match item_name:
		"wood":
			particles.color = Color(0.8, 0.6, 0.4)
		"metal":
			particles.color = Color(0.9, 0.9, 1.0)
		"bones":
			particles.color = Color(1.0, 1.0, 0.9)
		"blood":
			particles.color = Color(1.0, 0.3, 0.3)
		"stone":
			particles.color = Color(0.7, 0.7, 0.7)
		"rope":
			particles.color = Color(0.9, 0.8, 0.6)
		_:
			particles.color = Color.YELLOW
	
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 1.2
	
	# Add some randomness to particle behavior
	particles.angular_velocity_min = -180
	particles.angular_velocity_max = 180
	
	# Clean up particles after they finish
	get_tree().create_timer(1.5).timeout.connect(particles.queue_free)

func add_floating_effect():
	if sprite:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "position:y", sprite.position.y - 4, 2.0).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "position:y", sprite.position.y + 4, 2.0).set_trans(Tween.TRANS_SINE)

func add_glow_effect():
	if sprite:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "modulate:a", 0.8, 1.5)
		tween.tween_property(sprite, "modulate:a", 1.0, 1.5)

func add_shimmer_effect():
	# New subtle shimmer effect
	if sprite:
		var shimmer_tween = create_tween()
		shimmer_tween.set_loops()
		# Slight rotation shimmer
		shimmer_tween.tween_property(sprite, "rotation", deg_to_rad(2), 3.0).set_trans(Tween.TRANS_SINE)
		shimmer_tween.tween_property(sprite, "rotation", deg_to_rad(-2), 3.0).set_trans(Tween.TRANS_SINE)

# Function to spawn this item at a position
static func spawn_item(scene_parent: Node, item_type: String, position: Vector2, min_amt: int = 1, max_amt: int = 10):
	# Load the collectible item scene
	var item_scene = preload("res://Scenes/elments Scens/wood.tscn")
	var item_instance = item_scene.instantiate()
	
	# Configure the item
	item_instance.item_name = item_type
	item_instance.min_amount = min_amt
	item_instance.max_amount = max_amt
	item_instance.global_position = position
	
	# Add to scene
	scene_parent.add_child(item_instance)
	
	print("Spawned ", item_type, " (", min_amt, "-", max_amt, ") at ", position)
	return item_instance

# Debug function to spawn test items around the player
static func debug_spawn_items_around_player(player: Node):
	if not player:
		print("No player found for debug spawn")
		return
	
	var spawn_parent = player.get_parent()
	var player_pos = player.global_position
	var spawn_distance = 120
	
	# Spawn different materials in a circle around player
	var materials = ["wood", "metal", "bones", "blood", "stone", "rope"]
	
	for i in range(materials.size()):
		var angle = (i * 2 * PI) / materials.size()
		var spawn_pos = player_pos + Vector2(cos(angle), sin(angle)) * spawn_distance
		spawn_item(spawn_parent, materials[i], spawn_pos, 1, 10)
	
	print("DEBUG: Spawned test materials around player with random amounts")

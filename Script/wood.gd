extends Area2D

# Item properties
@export var item_name: String = "wood"  # What material this gives
@export var item_amount: int = 1        # How many you get
@export var auto_pickup: bool = true    # Pick up on touch or require E key
@export var pickup_text: String = "Press E to collect"

# References
@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D
@onready var pickup_label = $PickupLabel
@onready var detection_area = $DetectionArea

# Variables
var is_collected: bool = false
var player_nearby: bool = false
var player_in_area: CharacterBody2D = null

func _ready():
	add_to_group("collectible")
	print("Collectible item ready: ", item_name)
	
	# Setup main pickup area
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Setup detection area for showing pickup text
	if detection_area:
		detection_area.body_entered.connect(_on_detection_entered)
		detection_area.body_exited.connect(_on_detection_exited)
		detection_area.monitoring = true
		detection_area.monitorable = false  # Don't need to be detected by others
		print("DetectionArea signals connected successfully")
	else:
		print("ERROR: DetectionArea not found!")
	
	# Setup pickup label - MAKE SURE IT'S HIDDEN AT START
	setup_pickup_label()
	
	# Set collision layers
	collision_layer = 8  # Collectibles layer
	collision_mask = 1   # Detects player layer
	
	# Make sure DetectionArea has correct collision settings
	if detection_area:
		detection_area.collision_layer = 0  # Don't emit collision
		detection_area.collision_mask = 1   # Only detect player
	
	# Visual effects
	add_floating_effect()
	add_glow_effect()
	
	# Setup item appearance based on type
	setup_item_appearance()

func setup_pickup_label():
	if pickup_label:
		# FORCE the label to be invisible at start
		pickup_label.visible = false
		pickup_label.modulate.a = 0.0  # Also set alpha to 0
		pickup_label.text = pickup_text
		pickup_label.add_theme_font_size_override("font_size", 14)
		pickup_label.add_theme_color_override("font_color", Color.WHITE)
		pickup_label.add_theme_color_override("font_outline_color", Color.BLACK)
		pickup_label.add_theme_constant_override("outline_size", 2)
		pickup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pickup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		print("Pickup label setup complete - should be invisible")
	else:
		print("ERROR: PickupLabel not found!")

func setup_item_appearance():
	if not sprite:
		return
	
	# Set sprite and color based on item type
	match item_name:
		"wood":
			sprite.modulate = Color(0.6, 0.4, 0.2)  # Brown
		"metal":
			sprite.modulate = Color(0.7, 0.7, 0.8)  # Silver
		"bones":
			sprite.modulate = Color(0.9, 0.9, 0.8)  # Bone white
		"blood":
			sprite.modulate = Color(0.8, 0.2, 0.2)  # Red
		"stone":
			sprite.modulate = Color(0.5, 0.5, 0.5)  # Gray
		"rope":
			sprite.modulate = Color(0.7, 0.6, 0.4)  # Tan
		_:
			sprite.modulate = Color.WHITE

func _input(event):
	# Manual pickup with E key
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_E):
		if player_nearby and not auto_pickup and not is_collected:
			collect_item()

func _on_body_entered(body):
	if body.is_in_group("player") and not is_collected:
		player_in_area = body
		
		if auto_pickup:
			# Automatic pickup
			collect_item()
		else:
			# Manual pickup - just mark player as nearby
			player_nearby = true
			print("Press E to collect ", item_name)

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_area = null
		player_nearby = false

func _on_detection_entered(body):
	if body.is_in_group("player") and not is_collected and not auto_pickup:
		show_pickup_text()

func _on_detection_exited(body):
	if body.is_in_group("player") and not auto_pickup:
		hide_pickup_text()

func show_pickup_text():
	if pickup_label:
		pickup_label.visible = true
		# Animate text appearing
		var tween = create_tween()
		pickup_label.modulate.a = 0
		tween.tween_property(pickup_label, "modulate:a", 1.0, 0.2)

func hide_pickup_text():
	if pickup_label:
		# Animate text disappearing
		var tween = create_tween()
		tween.tween_property(pickup_label, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): pickup_label.visible = false).set_delay(0.2)

func collect_item():
	if is_collected:
		return
	
	# Find the player and add item to their inventory
	var player = player_in_area
	if not player and player_nearby:
		# Try to find player in the scene
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	if not player:
		print("ERROR: Could not find player to give item to")
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
		return
	
	# Show collection message BEFORE starting animations
	show_collection_message()
	
	# Mark as collected and play collection animation
	is_collected = true
	play_collection_animation()
	
	# Disable collision and hide pickup text immediately
	if collision_shape:
		collision_shape.disabled = true
	if detection_area:
		detection_area.monitoring = false
	hide_pickup_text()
	
	# Remove item after animation
	get_tree().create_timer(1.0).timeout.connect(queue_free)

func show_collection_message():
	# Create floating "+X ItemName" message
	var message_label = Label.new()
	get_parent().add_child(message_label)
	
	# Setup the message text
	var message_text = "+" + str(item_amount) + " " + item_name.capitalize()
	message_label.text = message_text
	message_label.global_position = global_position + Vector2(-30, -20)  # Start slightly above and left
	
	# Style the message
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", Color.YELLOW)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 2)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Color the message based on item type
	match item_name:
		"wood":
			message_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))  # Brown-yellow
		"metal":
			message_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))  # Silver-white
		"bones":
			message_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))  # Bone white
		"blood":
			message_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # Bright red
		"stone":
			message_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))  # Light gray
		"rope":
			message_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))  # Tan
		_:
			message_label.add_theme_color_override("font_color", Color.YELLOW)  # Default yellow
	
	# Animate the message
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Float upward
	var end_position = message_label.global_position + Vector2(0, -60)
	tween.tween_property(message_label, "global_position", end_position, 1.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Fade out
	tween.tween_property(message_label, "modulate:a", 0.0, 0.8).set_delay(0.7)
	
	# Scale animation - start big, shrink to normal, then shrink to disappear
	message_label.scale = Vector2(1.5, 1.5)
	tween.tween_property(message_label, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(message_label, "scale", Vector2(0.8, 0.8), 0.5).set_delay(1.0)
	
	# Remove the message after animation
	get_tree().create_timer(1.8).timeout.connect(message_label.queue_free)
	
	print("Showing collection message: ", message_text)

func play_collection_animation():
	if sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Flash bright then fade
		tween.tween_property(sprite, "modulate", Color.WHITE * 2.0, 0.1)
		tween.tween_property(sprite, "modulate", Color.TRANSPARENT, 0.3).set_delay(0.1)
		
		# Float up and scale
		var start_pos = sprite.position
		tween.tween_property(sprite, "position", start_pos + Vector2(0, -30), 0.4)
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.2)
		tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.2).set_delay(0.2)
		
		# Create sparkle effect
		create_pickup_particles()

func create_pickup_particles():
	# Create particle effect when collected
	var particles = CPUParticles2D.new()
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	particles.amount = 15
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.initial_velocity_min = 20
	particles.initial_velocity_max = 60
	particles.spread = 360
	particles.gravity = Vector2(0, 50)
	
	# Color particles based on item type
	match item_name:
		"wood":
			particles.color = Color(0.6, 0.4, 0.2)
		"metal":
			particles.color = Color(0.7, 0.7, 0.8)
		"bones":
			particles.color = Color(0.9, 0.9, 0.8)
		"blood":
			particles.color = Color(0.8, 0.2, 0.2)
		"stone":
			particles.color = Color(0.5, 0.5, 0.5)
		"rope":
			particles.color = Color(0.7, 0.6, 0.4)
		_:
			particles.color = Color.YELLOW
	
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.8
	
	# Clean up particles after they finish
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

func add_floating_effect():
	if sprite:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "position:y", sprite.position.y - 3, 1.5).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "position:y", sprite.position.y + 3, 1.5).set_trans(Tween.TRANS_SINE)

func add_glow_effect():
	if sprite:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "modulate:a", 0.7, 1.0)
		tween.tween_property(sprite, "modulate:a", 1.0, 1.0)

# Function to spawn this item at a position
static func spawn_item(scene_parent: Node, item_type: String, position: Vector2, amount: int = 1):
	# Load the collectible item scene
	var item_scene = preload("res://Scenes/elments Scens/wood.tscn")  # You'll need to create this scene
	var item_instance = item_scene.instantiate()
	
	# Configure the item
	item_instance.item_name = item_type
	item_instance.item_amount = amount
	item_instance.global_position = position
	
	# Add to scene
	scene_parent.add_child(item_instance)
	
	print("Spawned ", amount, " ", item_type, " at ", position)
	return item_instance

# Debug function to spawn test items around the player
static func debug_spawn_items_around_player(player: Node):
	if not player:
		print("No player found for debug spawn")
		return
	
	var spawn_parent = player.get_parent()
	var player_pos = player.global_position
	var spawn_distance = 100
	
	# Spawn different materials in a circle around player
	var materials = ["wood", "metal", "bones", "blood", "stone", "rope"]
	
	for i in range(materials.size()):
		var angle = (i * 2 * PI) / materials.size()
		var spawn_pos = player_pos + Vector2(cos(angle), sin(angle)) * spawn_distance
		spawn_item(spawn_parent, materials[i], spawn_pos, randi_range(1, 3))
	
	print("DEBUG: Spawned test materials around player")

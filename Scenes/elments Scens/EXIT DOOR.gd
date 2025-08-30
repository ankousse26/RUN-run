extends Area2D

@export var exit_enabled: bool = false
@onready var animated_sprite = $AnimatedSprite2D
@onready var status_label = $Label
@onready var audio_player = $AudioStreamPlayer2D

var player_nearby: bool = false

func _ready():
	add_to_group("exit_door")
	
	# IMPORTANT: Set collision layers to prevent damage interference
	collision_layer = 8   # Different layer from enemies
	collision_mask = 1    # Only detect player layer
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Initialize door state
	update_door_state()
	
	print("Exit door ready - NO DAMAGE!")

func _process(delta):
	# Check for EXIT key input when player is nearby
	if player_nearby and Input.is_action_just_pressed("EXIT"):  # Space key
		attempt_exit()

func _on_body_entered(body):
	# ONLY interaction, NO DAMAGE
	if body.is_in_group("player"):
		player_nearby = true
		
		print("Player near exit door - NO DAMAGE APPLIED")
		
		# Set can_exit flag on player
		if body.has_method("set_can_exit"):
			body.set_can_exit(true)
		
		# Check if player can escape
		if body.has_method("can_escape") and body.can_escape():
			if not exit_enabled:
				enable_exit()
			show_exit_prompt()
		else:
			show_locked_message(body)

func _on_body_exited(body):
	# ONLY interaction cleanup, NO DAMAGE
	if body.is_in_group("player"):
		player_nearby = false
		
		print("Player left exit door area")
		
		# Remove can_exit flag from player
		if body.has_method("set_can_exit"):
			body.set_can_exit(false)
		
		hide_messages()

func attempt_exit():
	var player = get_tree().get_first_node_in_group("player")
	
	if not player:
		return
	
	if exit_enabled and player.has_method("can_escape") and player.can_escape():
		trigger_escape()
	elif not player.can_escape():
		var current_keys = player.collected_keys.size()
		var needed_keys = player.keys_needed_to_escape
		var missing_keys = needed_keys - current_keys
		
		print("Cannot escape! Need ", missing_keys, " more keys")
		
		if status_label:
			status_label.text = "Need " + str(missing_keys) + " more keys!"
			status_label.modulate = Color.RED

func enable_exit():
	exit_enabled = true
	print("Exit door enabled!")
	update_door_state()

func update_door_state():
	# Only update if nodes exist
	if animated_sprite and animated_sprite.sprite_frames:
		if exit_enabled:
			if animated_sprite.sprite_frames.has_animation("unlocked"):
				animated_sprite.play("unlocked")
		else:
			if animated_sprite.sprite_frames.has_animation("locked"):
				animated_sprite.play("locked")
	
	if status_label:
		if exit_enabled:
			status_label.text = "EXIT AVAILABLE"
			status_label.modulate = Color.GREEN
		else:
			status_label.text = "LOCKED - NEED KEY"
			status_label.modulate = Color.RED

func show_exit_prompt():
	if status_label and exit_enabled:
		status_label.text = "Press SPACE to ESCAPE!"
		status_label.modulate = Color.YELLOW

func show_locked_message(player):
	if not status_label:
		return
		
	if player and player.has_method("can_escape"):
		var current_keys = player.collected_keys.size()
		var needed_keys = player.keys_needed_to_escape
		var missing_keys = needed_keys - current_keys
		
		status_label.text = "Need " + str(missing_keys) + " more keys"
		status_label.modulate = Color.RED

func hide_messages():
	update_door_state()

func trigger_escape():
	print("Player escaped successfully!")
	
	# Victory effects
	if status_label:
		status_label.text = "ESCAPING..."
		status_label.modulate = Color.GREEN
	
	# Play escape sound if available
	if audio_player and audio_player.stream:
		audio_player.play()
	
	# Trigger player's escape
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("trigger_escape"):
		player.trigger_escape()
	else:
		# Fallback - restart scene after delay
		get_tree().create_timer(1.5).timeout.connect(func():
			print("Victory! Restarting...")
			get_tree().reload_current_scene()
		)

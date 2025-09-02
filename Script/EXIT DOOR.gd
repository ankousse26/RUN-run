extends Area2D

@export var exit_enabled: bool = false
@export var current_level: int = 1  # You can set this manually or let it auto-detect
@export var total_levels: int = 5   # Total number of levels

@onready var animated_sprite = $AnimatedSprite2D
@onready var status_label = $Label
@onready var audio_player = $AudioStreamPlayer2D

var player_nearby: bool = false

# This will auto-populate with detected level files
var level_paths = {}

func _ready():
	add_to_group("exit_door")
	
	# Auto-detect all level files
	scan_for_level_files()
	
	# Auto-detect current level from scene name
	detect_current_level()
	
	# Set collision layers
	collision_layer = 8   # Different layer from enemies
	collision_mask = 1    # Only detect player layer
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Initialize door state
	update_door_state()
	
	print("=== EXIT DOOR DEBUG ===")
	print("Current level: ", current_level)
	print("Available level paths: ", level_paths)
	print("Exit door ready!")

func scan_for_level_files():
	# Clear existing paths
	level_paths.clear()
	
	# Common level file patterns to search for
	var possible_paths = [
		# Your current structure
		"res://Scenes/Levels/level 1.tscn",
		"res://Scenes/Levels/Level 2.tscn",
		"res://Scenes/Levels/Level 3.tscn", 
		"res://Scenes/Levels/Level 4.tscn",
		"res://Scenes/Levels/Level 5.tscn",
		
		# Alternative naming patterns
		"res://Scenes/Levels/level1.tscn",
		"res://Scenes/Levels/level2.tscn",
		"res://Scenes/Levels/level3.tscn",
		"res://Scenes/Levels/level4.tscn", 
		"res://Scenes/Levels/level5.tscn",
		
		"res://Scenes/Levels/Level1.tscn",
		"res://Scenes/Levels/Level2.tscn",
		"res://Scenes/Levels/Level3.tscn",
		"res://Scenes/Levels/Level4.tscn",
		"res://Scenes/Levels/Level5.tscn",
		
		# Direct in Levels folder
		"res://Levels/level 1.tscn",
		"res://Levels/Level 2.tscn",
		"res://Levels/Level 3.tscn",
		"res://Levels/Level 4.tscn",
		"res://Levels/Level 5.tscn"
	]
	
	# Check which files actually exist and map them
	for i in range(1, total_levels + 1):
		for path in possible_paths:
			if str(i) in path and FileAccess.file_exists(path):
				level_paths[i] = path
				print("Found Level ", i, ": ", path)
				break
	
	print("Detected ", level_paths.size(), " level files out of ", total_levels, " total levels")

func detect_current_level():
	# Try to auto-detect level from scene file name
	var scene_file = get_tree().current_scene.scene_file_path
	print("Current scene file: ", scene_file)
	
	# Extract level number from filename - more robust detection
	var file_lower = scene_file.to_lower()
	
	for i in range(1, total_levels + 1):
		var level_patterns = [
			"level " + str(i),
			"level" + str(i), 
			"level_" + str(i),
			"lv" + str(i),
			"stage" + str(i)
		]
		
		for pattern in level_patterns:
			if pattern in file_lower:
				current_level = i
				print("Auto-detected current level: ", current_level)
				return
	
	print("Could not auto-detect level, using current_level = ", current_level)

func _process(delta):
	# Check for EXIT key input when player is nearby
	if player_nearby:
		if (Input.is_action_just_pressed("EXIT") or 
			Input.is_action_just_pressed("ui_accept") or 
			Input.is_physical_key_pressed(KEY_SPACE)):
			print("Exit key pressed!")
			attempt_exit()

func _on_body_entered(body):
	print("=== BODY ENTERED EXIT DOOR ===")
	print("Body: ", body.name, " Groups: ", body.get_groups())
	
	if body.is_in_group("player"):
		player_nearby = true
		print("✓ Player detected near exit door!")
		
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
	if body.is_in_group("player"):
		player_nearby = false
		print("Player left exit door area")
		
		if body.has_method("set_can_exit"):
			body.set_can_exit(false)
		
		hide_messages()

func attempt_exit():
	print("=== ATTEMPTING EXIT ===")
	var player = get_tree().get_first_node_in_group("player")
	
	if not player:
		print("✗ No player found!")
		return
	
	print("Player found: ", player.name)
	print("Exit enabled: ", exit_enabled)
	print("Player can escape: ", player.can_escape() if player.has_method("can_escape") else "NO METHOD")
	
	if exit_enabled and player.has_method("can_escape") and player.can_escape():
		print("✓ All conditions met - triggering escape!")
		trigger_escape()
	else:
		if not player.can_escape():
			var current_keys = player.collected_keys.size()
			var needed_keys = player.keys_needed_to_escape
			var missing_keys = needed_keys - current_keys
			
			print("✗ Cannot escape! Missing ", missing_keys, " keys")
			
			if status_label:
				status_label.text = "Need " + str(missing_keys) + " more keys!"
				status_label.modulate = Color.RED

func enable_exit():
	exit_enabled = true
	print("✓ Exit door enabled!")
	update_door_state()

func update_door_state():
	if status_label:
		if exit_enabled:
			if current_level < total_levels:
				status_label.text = "EXIT TO LEVEL " + str(current_level + 1)
			else:
				status_label.text = "EXIT - FINAL LEVEL!"
			status_label.modulate = Color.GREEN
		else:
			status_label.text = "LOCKED - NEED KEY"
			status_label.modulate = Color.RED

func show_exit_prompt():
	if status_label and exit_enabled:
		if current_level < total_levels:
			status_label.text = "Press SPACE - Go to Level " + str(current_level + 1)
		else:
			status_label.text = "Press SPACE - COMPLETE GAME!"
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
	var next_level = current_level + 1
	
	if next_level <= total_levels:
		print("🎉 Player completed Level ", current_level, "! Going to Level ", next_level)
		load_next_level()
	else:
		print("🎉 Player completed the final level! Game finished!")
		trigger_game_completion()

func load_next_level():
	var next_level = current_level + 1
	
	# Victory effects
	if status_label:
		status_label.text = "LEVEL COMPLETE!"
		status_label.modulate = Color.GREEN
	
	print("Loading Level ", next_level, " in 1.5 seconds...")
	
	# Load next level after delay
	get_tree().create_timer(1.5).timeout.connect(func():
		if next_level in level_paths:
			var next_level_path = level_paths[next_level]
			print("Loading Level ", next_level, ": ", next_level_path)
			
			if FileAccess.file_exists(next_level_path):
				print("✓ File exists, changing scene...")
				get_tree().change_scene_to_file(next_level_path)
			else:
				print("✗ ERROR: Level file not found: ", next_level_path)
				fallback_reload()
		else:
			print("✗ ERROR: No path found for level ", next_level)
			print("Available levels: ", level_paths.keys())
			fallback_reload()
	)

func fallback_reload():
	print("Falling back to reload current scene")
	get_tree().reload_current_scene()

func trigger_game_completion():
	print("🎉 CONGRATULATIONS! YOU COMPLETED ALL ", total_levels, " LEVELS! 🎉")
	
	if status_label:
		status_label.text = "GAME COMPLETE!"
		status_label.modulate = Color.GOLD
	
	# Return to first level after completion
	get_tree().create_timer(3.0).timeout.connect(func():
		print("Returning to Level 1...")
		if 1 in level_paths and FileAccess.file_exists(level_paths[1]):
			get_tree().change_scene_to_file(level_paths[1])
		else:
			get_tree().reload_current_scene()
	)

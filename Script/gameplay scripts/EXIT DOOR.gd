extends Area2D

@export var exit_enabled: bool = false
@export var total_levels: int = 5

var current_level: int = 1
var player_nearby: bool = false

@onready var status_label = $Label
@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	add_to_group("exit_door")
	
	# Simple level detection from scene name
	var scene_file = get_tree().current_scene.scene_file_path
	print("=== EXIT DOOR DEBUG ===")
	print("Scene file: ", scene_file)
	
	# Extract level number - simple method
	if "1" in scene_file:
		current_level = 1
	elif "2" in scene_file:
		current_level = 2
	elif "3" in scene_file:
		current_level = 3
	elif "4" in scene_file:
		current_level = 4
	elif "5" in scene_file:
		current_level = 5
	
	print("Detected current level: ", current_level)
	
	# Set collision
	collision_layer = 8
	collision_mask = 1
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	print("Exit door setup complete")

func _process(delta):
	# Debug key - press L to see detailed info
	if Input.is_action_just_pressed("ui_select") or Input.is_physical_key_pressed(KEY_L):
		debug_status()
	
	# Exit attempt
	if player_nearby and (Input.is_action_just_pressed("ui_accept") or Input.is_physical_key_pressed(KEY_SPACE)):
		print("SPACE KEY PRESSED!")
		attempt_exit()

func debug_status():
	print("=== DEBUG STATUS ===")
	print("Current level: ", current_level)
	print("Player nearby: ", player_nearby)
	print("Exit enabled: ", exit_enabled)
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		print("Player found: ", player.name)
		print("Player groups: ", player.get_groups())
		if player.has_method("can_escape"):
			print("Player can escape: ", player.can_escape())
			print("Player keys: ", player.collected_keys.size(), "/", player.keys_needed_to_escape)
		else:
			print("Player missing can_escape method!")
	else:
		print("No player found!")

func _on_body_entered(body):
	print("=== BODY ENTERED ===")
	print("Body: ", body.name)
	print("Groups: ", body.get_groups())
	print("Is player: ", body.is_in_group("player"))
	
	if body.is_in_group("player"):
		player_nearby = true
		print("Player is near exit door!")
		
		if body.has_method("set_can_exit"):
			body.set_can_exit(true)
		
		# Check keys
		if body.has_method("can_escape") and body.can_escape():
			exit_enabled = true
			print("Exit enabled - player has keys!")
			if status_label:
				status_label.text = "Press SPACE to go to Level " + str(current_level + 1)
				status_label.modulate = Color.GREEN
		else:
			print("Exit locked - player needs keys")
			if status_label:
				status_label.text = "Need key to exit!"
				status_label.modulate = Color.RED

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		print("Player left exit door")
		if body.has_method("set_can_exit"):
			body.set_can_exit(false)

func attempt_exit():
	print("=== ATTEMPTING EXIT ===")
	var player = get_tree().get_first_node_in_group("player")
	
	if not player:
		print("ERROR: No player found!")
		return
	
	if not player.has_method("can_escape"):
		print("ERROR: Player has no can_escape method!")
		return
	
	if not player.can_escape():
		print("ERROR: Player cannot escape - needs keys!")
		return
	
	if not exit_enabled:
		print("ERROR: Exit not enabled!")
		return
	
	print("SUCCESS: All conditions met!")
	
	# Simple level progression
	var next_level = current_level + 1
	if next_level > total_levels:
		print("Game complete!")
		get_tree().reload_current_scene()
		return
	
	# Try to load next level - hardcoded paths for debugging
	var next_level_paths = [
		"res://Scenes/Levels/level " + str(next_level) + ".tscn",
		"res://Scenes/Levels/Level " + str(next_level) + ".tscn",
		"res://Scenes/Levels/level" + str(next_level) + ".tscn",
		"res://Scenes/Levels/Level" + str(next_level) + ".tscn"
	]
	
	for path in next_level_paths:
		if FileAccess.file_exists(path):
			print("Loading: ", path)
			get_tree().change_scene_to_file(path)
			return
	
	print("ERROR: Could not find level ", next_level, " file!")
	print("Tried paths:")
	for path in next_level_paths:
		print("  ", path, " exists: ", FileAccess.file_exists(path))
	
	# Fallback
	get_tree().reload_current_scene()

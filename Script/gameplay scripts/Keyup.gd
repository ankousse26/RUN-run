extends Area2D

# Your existing key variables...
@export var key_id: String = "basic_key"
@onready var prompt_label = $Label

# Add this to your existing _ready() function
func _ready():
	# Your existing key setup code...
	
	# Add proximity detection
	body_entered.connect(_on_player_near)
	body_exited.connect(_on_player_left)
	
	# Setup the prompt label
	setup_prompt_label()

func setup_prompt_label():
	# Hide the prompt at start
	prompt_label.text = ""
	prompt_label.visible = false
	
	# Style the label
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_color_override("font_color", Color.YELLOW)
	prompt_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	
	# Center the text above the key
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _on_player_near(body):
	if body.is_in_group("player"):
		show_key_prompt()

func _on_player_left(body):
	if body.is_in_group("player"):
		hide_key_prompt()

func show_key_prompt():
	prompt_label.text = "KEY"
	prompt_label.visible = true
	
	# Optional: Add a subtle animation
	animate_prompt_in()

func hide_key_prompt():
	prompt_label.visible = false

func animate_prompt_in():
	# Simple bounce animation
	prompt_label.scale = Vector2(0.5, 0.5)
	
	var tween = create_tween()
	tween.tween_property(prompt_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(prompt_label, "scale", Vector2(1.0, 1.0), 0.1)

# Your existing key collection code stays the same...
func collect_key(player):
	# Hide prompt when collected
	prompt_label.visible = false
	
	# Your existing collection logic...
	player.collect_key(key_id)
	queue_free()

extends Area2D

@export var exit_enabled: bool = false
var player_nearby: bool = false
@onready var status_label = $Label

func _ready():
	collision_layer = 8
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta):
	if player_nearby and Input.is_action_just_pressed("ui_accept"):
		attempt_exit()

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true
		if body.has_method("can_escape") and body.can_escape():
			exit_enabled = true
			if status_label:
				status_label.text = "Press SPACE - Go to Level 2"
				status_label.modulate = Color.GREEN

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false

func attempt_exit():
	var player = get_tree().get_first_node_in_group("player")
	if player and player.can_escape() and exit_enabled:
		get_tree().change_scene_to_file("res://Scenes/Levels/level 3.tscn")

extends Area2D

@export var battery_amount: float = 25.0

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player") and body.has_method("add_battery"):
		body.add_battery(battery_amount)
		queue_free()

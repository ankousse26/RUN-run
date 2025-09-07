extends Node2D

# References
@onready var interaction_area = $StaticBody2D/InteractionArea
@onready var crafting_ui = $CraftingUI
@onready var safe_zone = $SafeZone

# Interaction prompt (you can create this as a Label or use existing UI)
var interaction_prompt_scene = null  # We'll create the prompt dynamicall
var player_in_range = false
var player_reference = null
# Add this with your other variables at the top
var interaction_prompt = null

func _ready():
	# Hide crafting UI at start
	if crafting_ui:
		crafting_ui.visible = false
	
	# Connect interaction area signals
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	
	# Connect crafting UI signals
	if crafting_ui:
		if crafting_ui.has_signal("craft_item_requested"):
			crafting_ui.craft_item_requested.connect(_on_craft_item_requested)
		if crafting_ui.has_signal("close_requested"):
			crafting_ui.close_requested.connect(_on_close_crafting_ui)
	
	print("Crafting Bench initialized!")

func _input(event):
	# Check for interaction key (E)
	if player_in_range and player_reference:
		if event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
			toggle_crafting_ui()

func _on_interaction_area_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		player_reference = body
		show_interaction_prompt()
		print("Player entered crafting area")

func _on_interaction_area_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		hide_interaction_prompt()
		close_crafting_ui()
		player_reference = null
		print("Player left crafting area")

func show_interaction_prompt():
	# Simple text prompt - you can make this fancier
	if not interaction_prompt:
		interaction_prompt = Label.new()
		interaction_prompt.text = "Press [E] to Craft"
		interaction_prompt.add_theme_font_size_override("font_size", 16)
		interaction_prompt.add_theme_color_override("font_color", Color.WHITE)
		interaction_prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
		interaction_prompt.add_theme_constant_override("shadow_offset_x", 2)
		interaction_prompt.add_theme_constant_override("shadow_offset_y", 2)
		
		# Position above the bench
		interaction_prompt.position = Vector2(-50, -100)
		add_child(interaction_prompt)
	
	interaction_prompt.visible = true

func hide_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.visible = false

func toggle_crafting_ui():
	if crafting_ui:
		crafting_ui.visible = not crafting_ui.visible
		
		if crafting_ui.visible:
			open_crafting_ui()
		else:
			close_crafting_ui()

func open_crafting_ui():
	if crafting_ui and player_reference:
		crafting_ui.visible = true
		# Pass player reference to UI so it can check materials
		if crafting_ui.has_method("set_player"):
			crafting_ui.set_player(player_reference)
		if crafting_ui.has_method("refresh_recipes"):
			crafting_ui.refresh_recipes()
		
		hide_interaction_prompt()
		print("Opened crafting UI")

func close_crafting_ui():
	if crafting_ui:
		crafting_ui.visible = false
		
		# Show prompt again if player still in range
		if player_in_range:
			show_interaction_prompt()
		
		print("Closed crafting UI")

func _on_craft_item_requested(item_name: String):
	# This is called when player clicks craft button in UI
	if player_reference and player_reference.has_method("craft_item"):
		var success = player_reference.craft_item(item_name)
		
		if success:
			print("Successfully crafted: ", item_name)
			# Refresh UI to update material counts
			if crafting_ui and crafting_ui.has_method("refresh_recipes"):
				crafting_ui.refresh_recipes()
			
			# Play success animation/sound here
			play_craft_success_effect()
		else:
			print("Failed to craft: ", item_name, " (insufficient materials)")
			# Play failure sound here
			play_craft_failure_effect()

func _on_close_crafting_ui():
	close_crafting_ui()

func play_craft_success_effect():
	# Add your success animation/particles/sound here
	pass

func play_craft_failure_effect():
	# Add your failure animation/sound here
	pass

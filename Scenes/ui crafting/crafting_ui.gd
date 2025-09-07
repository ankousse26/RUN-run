extends Control

# This script replaces your existing crafting_ui.gd
# First, let's fix your UI structure in the editor

# STEP 1: Fix your CraftingUI scene structure in Godot Editor:
# 
# CraftingUI (Control) - Set to FULL_RECT preset
# ├── Background (ColorRect) - Semi-transparent black overlay - FULL_RECT
# └── CenterContainer - FULL_RECT preset
#     └── Panel (Panel) - Custom size 600x400
#         ├── MarginContainer - FULL_RECT with margins
#         │   └── VBoxContainer
#         │       ├── Header (HBoxContainer)
#         │       │   ├── TitleLabel (Label) - "Crafting Bench"
#         │       │   ├── Spacer (Control) - Expand horizontal
#         │       │   └── CloseButton (Button) - "X"
#         │       ├── HSeparator
#         │       └── ScrollContainer - Expand both
#         │           └── RecipeList (VBoxContainer)

# Signals
signal craft_item_requested(item_name)
signal close_requested

# UI References - UPDATE THESE PATHS to match your new structure
@onready var background = $Background
@onready var main_panel = $CenterContainer/Panel
@onready var recipe_container = $CenterContainer/Panel/MarginContainer/VBoxContainer/ScrollContainer/RecipeList
@onready var close_button = $CenterContainer/Panel/MarginContainer/VBoxContainer/Header/CloseButton
@onready var title_label = $CenterContainer/Panel/MarginContainer/VBoxContainer/Header/TitleLabel

var recipe_button_scene = null
var player = null

# Recipe definitions
var recipes = {
	"spike_trap": {
		"name": "Spike Trap",
		"description": "Damages enemies that step on it",
		"materials": {"wood": 3, "metal": 2},
		"icon": "res://assets/items/spike_trap_icon.png"
	},
	"poison_trap": {
		"name": "Poison Trap", 
		"description": "Poisons enemies over time",
		"materials": {"blood": 2, "bones": 1},
		"icon": "res://assets/items/poison_trap_icon.png"
	},
	"rope_trap": {
		"name": "Rope Trap",
		"description": "Immobilizes enemies",
		"materials": {"rope": 2, "wood": 1},
		"icon": "res://assets/items/rope_trap_icon.png"
	},
	"fire_trap": {
		"name": "Fire Trap",
		"description": "Burns enemies in an area",
		"materials": {"coal": 2, "metal": 1},
		"icon": "res://assets/items/fire_trap_icon.png"
	},
	"health_potion": {
		"name": "Health Potion",
		"description": "Restores 30 HP",
		"materials": {"blood": 1},
		"icon": "res://assets/items/health_potion_icon.png"
	},
	"super_health_potion": {
		"name": "Super Health Potion",
		"description": "Restores 50 HP",
		"materials": {"blood": 2, "crystal": 1},
		"icon": "res://assets/items/super_health_potion_icon.png"
	}
}

func _ready():
	visible = false
	setup_ui_style()
	
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	if title_label:
		title_label.text = "Crafting Bench"
		title_label.add_theme_font_size_override("font_size", 24)
		title_label.add_theme_color_override("font_color", Color.WHITE)
	
	create_recipe_buttons()
	print("CraftingUI initialized with ", recipes.size(), " recipes")

func setup_ui_style():
	# Style the background overlay
	if background:
		background.color = Color(0, 0, 0, 0.5)  # Semi-transparent black
		background.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks behind UI
	
	# Style the main panel
	if main_panel:
		main_panel.custom_minimum_size = Vector2(600, 400)
		
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
		panel_style.border_width_left = 3
		panel_style.border_width_right = 3
		panel_style.border_width_top = 3
		panel_style.border_width_bottom = 3
		panel_style.border_color = Color(0.3, 0.3, 0.4)
		panel_style.corner_radius_top_left = 10
		panel_style.corner_radius_top_right = 10
		panel_style.corner_radius_bottom_left = 10
		panel_style.corner_radius_bottom_right = 10
		panel_style.shadow_color = Color(0, 0, 0, 0.3)
		panel_style.shadow_size = 10
		panel_style.shadow_offset = Vector2(0, 5)
		main_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Style close button
	if close_button:
		close_button.custom_minimum_size = Vector2(30, 30)
		close_button.text = "✕"
		close_button.add_theme_font_size_override("font_size", 18)
		
		var button_style_normal = StyleBoxFlat.new()
		button_style_normal.bg_color = Color(0.8, 0.2, 0.2, 0.8)
		button_style_normal.corner_radius_top_left = 5
		button_style_normal.corner_radius_top_right = 5
		button_style_normal.corner_radius_bottom_left = 5
		button_style_normal.corner_radius_bottom_right = 5
		
		var button_style_hover = button_style_normal.duplicate()
		button_style_hover.bg_color = Color(1.0, 0.3, 0.3, 1.0)
		
		close_button.add_theme_stylebox_override("normal", button_style_normal)
		close_button.add_theme_stylebox_override("hover", button_style_hover)
		close_button.add_theme_stylebox_override("pressed", button_style_hover)

func set_player(player_ref):
	player = player_ref
	refresh_recipes()

func create_recipe_buttons():
	if recipe_container:
		for child in recipe_container.get_children():
			child.queue_free()
	
	for recipe_id in recipes:
		var recipe_data = recipes[recipe_id]
		create_recipe_button(recipe_id, recipe_data)

func create_recipe_button(recipe_id: String, recipe_data: Dictionary):
	# Main container with margin
	var recipe_margin = MarginContainer.new()
	recipe_margin.set("theme_override_constants/margin_left", 5)
	recipe_margin.set("theme_override_constants/margin_right", 5)
	recipe_margin.set("theme_override_constants/margin_top", 5)
	recipe_margin.set("theme_override_constants/margin_bottom", 5)
	
	# Recipe panel
	var recipe_panel = Panel.new()
	recipe_panel.custom_minimum_size = Vector2(550, 90)
	
	# Style the recipe panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.5)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	recipe_panel.add_theme_stylebox_override("panel", style)
	
	recipe_margin.add_child(recipe_panel)
	
	# Content container with padding
	var content_margin = MarginContainer.new()
	content_margin.anchors_preset = Control.PRESET_FULL_RECT
	content_margin.set("theme_override_constants/margin_left", 10)
	content_margin.set("theme_override_constants/margin_right", 10)
	content_margin.set("theme_override_constants/margin_top", 10)
	content_margin.set("theme_override_constants/margin_bottom", 10)
	recipe_panel.add_child(content_margin)
	
	# Horizontal layout
	var hbox = HBoxContainer.new()
	hbox.set("theme_override_constants/separation", 15)
	content_margin.add_child(hbox)
	
	# Item icon
	var icon_bg = Panel.new()
	icon_bg.custom_minimum_size = Vector2(64, 64)
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	icon_style.corner_radius_top_left = 5
	icon_style.corner_radius_top_right = 5
	icon_style.corner_radius_bottom_left = 5
	icon_style.corner_radius_bottom_right = 5
	icon_bg.add_theme_stylebox_override("panel", icon_style)
	hbox.add_child(icon_bg)
	
	var icon = TextureRect.new()
	icon.anchors_preset = Control.PRESET_FULL_RECT
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	if FileAccess.file_exists(recipe_data.icon):
		icon.texture = load(recipe_data.icon)
	else:
		icon.texture = load("res://icon.png")
	icon_bg.add_child(icon)
	
	# Info container
	var info_container = VBoxContainer.new()
	info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_container.set("theme_override_constants/separation", 5)
	hbox.add_child(info_container)
	
	# Item name
	var name_label = Label.new()
	name_label.text = recipe_data.name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	info_container.add_child(name_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = recipe_data.description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_container.add_child(desc_label)
	
	# Materials
	var materials_label = RichTextLabel.new()
	materials_label.bbcode_enabled = true
	materials_label.fit_content = true
	materials_label.custom_minimum_size = Vector2(0, 20)
	materials_label.text = get_materials_text_rich(recipe_data.materials)
	info_container.add_child(materials_label)
	
	# Craft button
	var craft_button = Button.new()
	craft_button.text = "CRAFT"
	craft_button.custom_minimum_size = Vector2(100, 50)
	craft_button.pressed.connect(func(): _on_craft_button_pressed(recipe_id))
	
	# Style craft button
	var btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0.2, 0.5, 0.3, 0.9)
	btn_style_normal.corner_radius_top_left = 5
	btn_style_normal.corner_radius_top_right = 5
	btn_style_normal.corner_radius_bottom_left = 5
	btn_style_normal.corner_radius_bottom_right = 5
	
	var btn_style_hover = btn_style_normal.duplicate()
	btn_style_hover.bg_color = Color(0.3, 0.6, 0.4, 1.0)
	
	var btn_style_disabled = btn_style_normal.duplicate()
	btn_style_disabled.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	
	craft_button.add_theme_stylebox_override("normal", btn_style_normal)
	craft_button.add_theme_stylebox_override("hover", btn_style_hover)
	craft_button.add_theme_stylebox_override("pressed", btn_style_hover)
	craft_button.add_theme_stylebox_override("disabled", btn_style_disabled)
	craft_button.add_theme_font_size_override("font_size", 14)
	
	hbox.add_child(craft_button)
	
	# Store references
	recipe_panel.set_meta("recipe_id", recipe_id)
	recipe_panel.set_meta("craft_button", craft_button)
	recipe_panel.set_meta("materials_label", materials_label)
	recipe_panel.set_meta("panel_style", style)
	
	if recipe_container:
		recipe_container.add_child(recipe_margin)

func get_materials_text_rich(materials: Dictionary) -> String:
	var text = "[color=#aaaaaa]Required: [/color]"
	var material_strings = []
	
	for material in materials:
		var amount = materials[material]
		var player_amount = 0
		if player and player.has_method("get_material_count"):
			player_amount = player.get_material_count(material)
		
		var color = "lime" if player_amount >= amount else "red"
		var mat_text = "[color=" + color + "]" + material.capitalize() + " (" + str(player_amount) + "/" + str(amount) + ")[/color]"
		material_strings.append(mat_text)
	
	text += " ".join(material_strings)
	return text

func refresh_recipes():
	if not recipe_container or not player:
		return
	
	for child in recipe_container.get_children():
		var panel = child.get_child(0) if child.get_child_count() > 0 else null
		if panel and panel.has_meta("recipe_id"):
			var recipe_id = panel.get_meta("recipe_id")
			var craft_button = panel.get_meta("craft_button")
			var materials_label = panel.get_meta("materials_label")
			
			if recipes.has(recipe_id):
				var recipe_data = recipes[recipe_id]
				
				if materials_label:
					materials_label.text = get_materials_text_rich(recipe_data.materials)
				
				var can_craft = can_player_craft(recipe_id)
				
				if craft_button:
					craft_button.disabled = not can_craft
					craft_button.modulate = Color.WHITE if can_craft else Color(0.5, 0.5, 0.5)

func can_player_craft(recipe_id: String) -> bool:
	if not player or not player.has_method("has_material"):
		return false
	
	if not recipes.has(recipe_id):
		return false
	
	var recipe_data = recipes[recipe_id]
	
	for material in recipe_data.materials:
		var required_amount = recipe_data.materials[material]
		if not player.has_material(material, required_amount):
			return false
	
	return true

func _on_craft_button_pressed(recipe_id: String):
	print("Craft button pressed for: ", recipe_id)
	craft_item_requested.emit(recipe_id)

func _on_close_button_pressed():
	close_requested.emit()

func _input(event):
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		close_requested.emit()

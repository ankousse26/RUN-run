extends CharacterBody2D

# --- EXISTING VARIABLES AND EXPORTS (KEEP AS IS) ---
# Movement settings
@export var speed: float = 300.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0
# Push/Pull settings
@export var push_pull_force: float = 600.0
@export var push_pull_speed: float = 150.0  # Slower speed when pushing/pulling
@export var interaction_distance: float = 80.0  # How close to be to detect and select box
@export var push_distance: float = 35.0  # How close to be to actually push/pull the box
# Key collection system
@export var keys_needed_to_escape: int = 1
var collected_keys: Array[String] = []
@onready var key_ui = $UI/KeyCounter
# Health settings
@export var max_health: int = 100
@export var current_health: int = 100
@export var invincible_time: float = 1.0
# Knockback settings
@export var knockback_force: float = 300.0
@export var knockback_duration: float = 0.3
# UI Settings
@export var health_bar_max_width: float = 100.0
# Flashlight system
@export var flashlight_enabled: bool = true
@export var max_battery: float = 100.0
@export var battery_drain_rate: float = 15.0
@export var flashlight_detection_range: float = 200.0
# HOTBAR SYSTEM (5 slots for equipped items/tools/traps)
@export var hotbar_slots: int = 5
var hotbar: Array = []  # Equipped items: [{item: "spike_trap", count: 3}, null, {item: "flashlight"}, ...]
var selected_hotbar_slot: int = 0  # Which hotbar slot is selected (0-4)
# INVENTORY SYSTEM (for storing materials)
var inventory: Dictionary = {}  # Materials storage: {"wood": 10, "metal": 5, "bones": 3}
var inventory_ui_open: bool = false
# Flashlight references
@onready var flashlight_light = $PointLight2D
@onready var flashlight_area = $FlashlightDetectionArea
@onready var battery_ui = $UI/BatteryBar
@onready var battery_label = $UI/BatteryLabel
# Hotbar UI references (the bottom bar you see)
@onready var hotbar_ui = $UI/InventoryBar
@onready var hotbar_slots_container = $UI/InventoryBar/InventorySlots
# Visual Inventory UI references (separate menu)
@onready var inventory_menu = $UI/InventoryMenu
@onready var inventory_grid = $UI/InventoryMenu/InventoryPanel/InventoryGrid
@onready var inventory_background = $UI/InventoryMenu/InventoryBackground
# Flashlight variables
var current_battery: float = 100.0
var flashlight_on: bool = false
var enemies_in_light: Array = []
# References
@onready var animated_sprite = $AnimatedSprite2D
@onready var health_ui = $UI/HealthBar
@onready var health_label = $UI/HealthLabel
@onready var character_portrait = $UI/AnimatedSprite2D # Assuming this is the portrait node
@onready var ui_background = $UI/UIBackground
# --- NEW REFERENCES FOR DEATH SEQUENCE ---
@onready var dead_screen = $UI/DeadScreen # Reference to the "U DEAD" screen CanvasLayer/Control
@onready var restart_label = $UI/DeadScreen/RestartLabel # Reference to the blinking "Press R to Restart" label

# Variables
var is_moving: bool = false
var is_invincible: bool = false
var is_dead: bool = false
var is_dying: bool = false
var is_knocked_back: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var can_exit: bool = false
# Push/Pull variables
var is_push_pull_mode: bool = false
var target_box: RigidBody2D = null
var is_pushing: bool = false
var is_pulling: bool = false
# Signals
signal health_changed(new_health)
signal player_died

func _ready():
	add_to_group("player")
	print("Player ready with hotbar and visual inventory system!")
	# Initialize health
	current_health = max_health
	update_health_ui()
	# Initialize flashlight
	current_battery = max_battery
	setup_flashlight()
	update_battery_ui()
	# Initialize hotbar and inventory
	setup_hotbar()
	setup_inventory()
	setup_inventory_grid()  # Setup grid layout
	check_ui_elements()
	# Debug pushable objects after everything loads
	call_deferred("debug_pushable_objects")
	
	# --- Initialize Death UI ---
	if dead_screen:
		dead_screen.hide() # Ensure it's hidden at start
	if restart_label:
		restart_label.hide() # Ensure it's hidden at start

# --- EXISTING FUNCTIONS (KEEP AS IS) ---
# HOTBAR SYSTEM (Quick access tools/traps/weapons)
func setup_hotbar():
	print("Setting up hotbar (quick access tools)...")
	# Initialize empty hotbar slots
	hotbar.clear()
	for i in range(hotbar_slots):
		hotbar.append(null)  # Each slot starts empty
	# Setup hotbar UI
	create_hotbar_ui()
	update_hotbar_ui()
	print("Hotbar ready with ", hotbar_slots, " empty slots!")

func equip_to_hotbar(item_name: String, slot_index: int, count: int = 1):
	if slot_index >= 0 and slot_index < hotbar_slots:
		hotbar[slot_index] = {"item": item_name, "count": count}
		print("Equipped ", count, " ", item_name, " to hotbar slot ", slot_index + 1)
		update_hotbar_ui()

func use_hotbar_item(slot_index: int):
	var slot_data = hotbar[slot_index]
	if slot_data == null:
		print("Hotbar slot ", slot_index + 1, " is empty")
		return
	var item_name = slot_data.item
	var count = slot_data.count
	print("Using ", item_name, " from hotbar slot ", slot_index + 1)
	match item_name:
		"spike_trap":
			place_trap("spike_trap")
		"poison_trap":
			place_trap("poison_trap")
		"rope_trap":
			place_trap("rope_trap")
		"fire_trap":
			place_trap("fire_trap")
		"health_potion":
			use_health_potion()
		"super_health_potion":
			use_super_health_potion()
		"flashlight":
			toggle_flashlight()
		_:
			print("Don't know how to use: ", item_name)
	# Reduce count or remove item
	if count > 1:
		slot_data.count -= 1
	else:
		hotbar[slot_index] = null  # Remove item from hotbar
	update_hotbar_ui()

func place_trap(trap_type: String):
	print("Placing ", trap_type, " at player position!")
	# TODO: Create trap at player position
	# This will be implemented when we create the trap system

func use_health_potion():
	heal(30)
	print("Used health potion! +30 HP")

func use_super_health_potion():
	heal(50)
	print("Used super health potion! +50 HP")

# INVENTORY SYSTEM (Materials storage with visual UI)
func setup_inventory():
	print("Setting up inventory with visual UI...")
	# Initialize all material counts
	inventory.clear()
	inventory["wood"] = 0
	inventory["metal"] = 0
	inventory["gold"] = 0      # Rare material
	inventory["bones"] = 0
	inventory["blood"] = 0
	inventory["stone"] = 0
	inventory["rope"] = 0
	inventory["crystal"] = 0   # Very rare material
	inventory["coal"] = 0      # Fuel material
	print("Inventory initialized with all 9 material types")

func add_material(material_name: String, amount: int = 1):
	if not inventory.has(material_name):
		inventory[material_name] = 0
	inventory[material_name] += amount
	print("Added ", amount, " ", material_name, " to inventory. Total: ", inventory[material_name])
	# Update visual inventory if it's open
	if inventory_ui_open and inventory_menu and inventory_menu.visible:
		update_visual_inventory()
	show_pickup_message(material_name, amount)

func remove_material(material_name: String, amount: int = 1) -> bool:
	if not inventory.has(material_name) or inventory[material_name] < amount:
		print("Not enough ", material_name, " in inventory")
		return false
	inventory[material_name] -= amount
	print("Removed ", amount, " ", material_name, " from inventory")
	# Update visual inventory if it's open
	if inventory_ui_open and inventory_menu and inventory_menu.visible:
		update_visual_inventory()
	return true

func has_material(material_name: String, amount: int = 1) -> bool:
	return inventory.has(material_name) and inventory[material_name] >= amount

func get_material_count(material_name: String) -> int:
	if inventory.has(material_name):
		return inventory[material_name]
	return 0

# IMPROVED VISUAL INVENTORY UI SYSTEM
func update_visual_inventory():
	if not inventory_grid:
		print("ERROR: Inventory grid not found!")
		return
	# Clear existing inventory display
	for child in inventory_grid.get_children():
		child.queue_free()
	# Define all possible materials with optional rarity for color coding
	var material_data = {
		"wood": {"rarity": "common"},
		"stone": {"rarity": "common"},
		"rope": {"rarity": "common"},
		"metal": {"rarity": "uncommon"},
		"bones": {"rarity": "uncommon"},
		"coal": {"rarity": "uncommon"},
		"blood": {"rarity": "rare"},
		"gold": {"rarity": "rare"},
		"crystal": {"rarity": "legendary"}
	}
	# Filter materials the player actually has
	var materials_to_show = []
	for material in material_data.keys():
		if get_material_count(material) > 0:
			materials_to_show.append(material)
	# Sort by rarity then alphabetically
	materials_to_show.sort_custom(func(a, b):
		var rarity_order = {"common": 0, "uncommon": 1, "rare": 2, "legendary": 3}
		var a_rarity = rarity_order.get(material_data[a].rarity, 0)
		var b_rarity = rarity_order.get(material_data[b].rarity, 0)
		if a_rarity != b_rarity:
			return a_rarity > b_rarity
		return a < b
	)
	# Create visual slots only for materials with count > 0
	if materials_to_show.size() > 0:
		for material in materials_to_show:
			var rarity = material_data[material].rarity if material_data.has(material) else "common"
			create_inventory_slot(material, get_material_count(material), rarity)
	else:
		# Show empty inventory message
		var empty_container = VBoxContainer.new()
		empty_container.anchors_preset = Control.PRESET_FULL_RECT
		empty_container.alignment = BoxContainer.ALIGNMENT_CENTER
		var empty_icon = TextureRect.new()
		empty_icon.texture = load("res://icon.png")  # Default Godot icon or custom empty icon
		empty_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		empty_icon.custom_minimum_size = Vector2(64, 64)
		empty_icon.modulate = Color(0.5, 0.5, 0.5, 0.5)
		empty_container.add_child(empty_icon)
		var empty_label = Label.new()
		empty_label.text = "Inventory Empty"
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_container.add_child(empty_label)
		inventory_grid.add_child(empty_container)

func create_inventory_slot(material_name: String, count: int, rarity: String = "common"):
	# Create main container for the slot
	var slot_container = MarginContainer.new()
	slot_container.custom_minimum_size = Vector2(100, 120)
	slot_container.set("theme_override_constants/margin_left", 4)
	slot_container.set("theme_override_constants/margin_right", 4)
	slot_container.set("theme_override_constants/margin_top", 4)
	slot_container.set("theme_override_constants/margin_bottom", 4)
	# Create the panel for the slot
	var slot_panel = Panel.new()
	# Style based on rarity with modern gradient effects
	var style = create_slot_style(rarity)
	slot_panel.add_theme_stylebox_override("panel", style)
	slot_container.add_child(slot_panel)
	# Create vertical layout for slot contents
	var content_container = VBoxContainer.new()
	content_container.anchors_preset = Control.PRESET_FULL_RECT
	content_container.alignment = BoxContainer.ALIGNMENT_CENTER
	content_container.set("theme_override_constants/separation", 2)
	slot_panel.add_child(content_container)
	# Add top spacer for centering
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 8)
	content_container.add_child(top_spacer)
	# Create icon container with proper centering
	var icon_container = CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(80, 60)
	content_container.add_child(icon_container)
	# Create item icon - LARGER AND CENTERED
	var item_icon = TextureRect.new()
	item_icon.texture = get_material_icon(material_name)
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.custom_minimum_size = Vector2(48, 48)  # Larger icon size
	# Add glow effect for rare items
	if rarity == "rare" or rarity == "legendary":
		add_glow_effect(item_icon, rarity)
	icon_container.add_child(item_icon)
	# Create material name label - modern styling
	var name_label = Label.new()
	name_label.text = material_name.capitalize()
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", get_rarity_text_color(rarity))
	name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content_container.add_child(name_label)
	# Create count badge - modern pill-shaped design
	if count > 1 or rarity == "legendary":
		var count_container = CenterContainer.new()
		content_container.add_child(count_container)
		var count_bg = Panel.new()
		count_bg.custom_minimum_size = Vector2(32, 20)
		var count_style = StyleBoxFlat.new()
		count_style.bg_color = get_count_badge_color(rarity)
		count_style.corner_radius_top_left = 10
		count_style.corner_radius_top_right = 10
		count_style.corner_radius_bottom_left = 10
		count_style.corner_radius_bottom_right = 10
		count_bg.add_theme_stylebox_override("panel", count_style)
		count_container.add_child(count_bg)
		var count_label = Label.new()
		count_label.text = str(count) if count > 999 else str(count)
		if count > 9999:
			count_label.text = str(int(count/1000)) + "k"
		count_label.add_theme_font_size_override("font_size", 12)
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.add_theme_constant_override("outline_size", 1)
		count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_label.anchors_preset = Control.PRESET_FULL_RECT
		count_bg.add_child(count_label)
	# Add interactive hover effects
	slot_panel.mouse_entered.connect(func(): on_slot_hover(slot_panel, material_name, count, rarity))
	slot_panel.mouse_exited.connect(func(): on_slot_unhover(slot_panel, rarity))
	# Add click handler for future functionality
	slot_panel.gui_input.connect(func(event): on_slot_clicked(event, material_name, count))
	inventory_grid.add_child(slot_container)

func create_slot_style(rarity: String) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	# Base styling
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	# Shadow for depth
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 2)
	# Rarity-based colors with gradients
	match rarity:
		"common":
			style.bg_color = Color(0.15, 0.15, 0.18, 0.95)
			style.border_color = Color(0.4, 0.4, 0.45)
		"uncommon":
			style.bg_color = Color(0.1, 0.2, 0.15, 0.95)
			style.border_color = Color(0.2, 0.7, 0.3)
		"rare":
			style.bg_color = Color(0.1, 0.1, 0.25, 0.95)
			style.border_color = Color(0.3, 0.5, 1.0)
		"legendary":
			style.bg_color = Color(0.2, 0.1, 0.25, 0.95)
			style.border_color = Color(0.9, 0.6, 1.0)
			# Add glow for legendary items
			style.shadow_color = Color(0.9, 0.6, 1.0, 0.3)
			style.shadow_size = 8
		_:
			style.bg_color = Color(0.15, 0.15, 0.18, 0.95)
			style.border_color = Color(0.4, 0.4, 0.45)
	return style

func get_rarity_text_color(rarity: String) -> Color:
	match rarity:
		"common":
			return Color(0.9, 0.9, 0.9)
		"uncommon":
			return Color(0.4, 0.9, 0.4)
		"rare":
			return Color(0.5, 0.7, 1.0)
		"legendary":
			return Color(1.0, 0.7, 0.9)
		_:
			return Color.WHITE

func get_count_badge_color(rarity: String) -> Color:
	match rarity:
		"common":
			return Color(0.3, 0.3, 0.35, 0.9)
		"uncommon":
			return Color(0.2, 0.5, 0.2, 0.9)
		"rare":
			return Color(0.2, 0.3, 0.7, 0.9)
		"legendary":
			return Color(0.6, 0.2, 0.7, 0.9)
		_:
			return Color(0.3, 0.3, 0.35, 0.9)

func add_glow_effect(icon: TextureRect, rarity: String):
	# Add a subtle glow/shine effect for rare items
	match rarity:
		"rare":
			icon.modulate = Color(1.1, 1.1, 1.3)
		"legendary":
			icon.modulate = Color(1.2, 1.1, 1.3)
			# Could add animated shine effect here

func on_slot_hover(panel: Panel, material_name: String, count: int, rarity: String):
	var style = panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		# Brighten background slightly
		var hover_style = style.duplicate()
		hover_style.bg_color = hover_style.bg_color.lightened(0.1)
		hover_style.border_width_left = 3
		hover_style.border_width_right = 3
		hover_style.border_width_top = 3
		hover_style.border_width_bottom = 3
		hover_style.border_color = hover_style.border_color.lightened(0.3)
		panel.add_theme_stylebox_override("panel", hover_style)
	# Show tooltip (you can expand this)
	print("[", rarity.to_upper(), "] ", material_name.capitalize(), " x", count)

func on_slot_unhover(panel: Panel, rarity: String):
	# Restore original style
	panel.add_theme_stylebox_override("panel", create_slot_style(rarity))

func on_slot_clicked(event: InputEvent, material_name: String, count: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Clicked on ", material_name, " (x", count, ")")
		# Add functionality here - crafting, moving to hotbar, etc.

# Setup the inventory grid container properties
func setup_inventory_grid():
	if inventory_grid:
		# Set grid properties for better layout
		if inventory_grid is GridContainer:
			inventory_grid.columns = 5  # 5 columns for a nice layout
			inventory_grid.set("theme_override_constants/h_separation", 8)
			inventory_grid.set("theme_override_constants/v_separation", 8)

func get_material_icon(material_name: String) -> Texture2D:
	# Return appropriate icon for each material
	match material_name:
		"wood":
			return load("res://assets/materials/wood_icon.png")
		"metal":
			return load("res://assets/materials/metal_icon.png")
		"gold":
			return load("res://assets/materials/gold_icon.png")
		"bones":
			return load("res://assets/materials/bones_icon.png")
		"blood":
			return load("res://assets/materials/blood_icon.png")
		"stone":
			return load("res://assets/materials/stone_icon.png")
		"rope":
			return load("res://assets/materials/rope_icon.png")
		"crystal":
			return load("res://assets/materials/crystal_icon.png")
		"coal":
			return load("res://assets/materials/coal_icon.png")
		_:
			return load("res://icon.png")  # Fallback to Godot default icon

# CRAFTING SYSTEM
func craft_item(item_type: String) -> bool:
	var recipe = get_recipe(item_type)
	if recipe.is_empty():
		print("No recipe found for: ", item_type)
		return false
	# Check if we have materials
	for material in recipe:
		if not has_material(material, recipe[material]):
			print("Missing ", recipe[material], " ", material, " to craft ", item_type)
			return false
	# Remove materials
	for material in recipe:
		remove_material(material, recipe[material])
	# Add crafted item to first empty hotbar slot
	add_to_hotbar(item_type, 1)
	print("Crafted ", item_type, "!")
	return true

func get_recipe(item_type: String) -> Dictionary:
	match item_type:
		"spike_trap":
			return {"wood": 3, "metal": 2}
		"poison_trap":
			return {"blood": 2, "bones": 1}
		"rope_trap":
			return {"rope": 2, "wood": 1}
		"fire_trap":           # NEW - burns enemies
			return {"coal": 2, "metal": 1}
		"golden_key":          # NEW - special escape key
			return {"gold": 1, "metal": 1}
		"crystal_weapon":      # NEW - powerful weapon
			return {"crystal": 1, "metal": 3, "gold": 1}
		"stone_barrier":       # NEW - defensive item
			return {"stone": 5, "wood": 2}
		"health_potion":
			return {"blood": 1}
		"super_health_potion": # NEW - better healing
			return {"blood": 2, "crystal": 1}
		_:
			return {}

func add_to_hotbar(item_name: String, count: int = 1):
	# Find first empty hotbar slot
	for i in range(hotbar_slots):
		if hotbar[i] == null:
			equip_to_hotbar(item_name, i, count)
			return
	print("Hotbar full! Cannot add ", item_name)

# INPUT HANDLING
func _input(event):
	# Exit with Space key
	if Input.is_action_just_pressed("EXIT"):
		attempt_exit()
	# Collect with E key
	if Input.is_action_just_pressed("COLLECT"):
		pass
	# Toggle flashlight with F key
	if event is InputEventKey and event.keycode == KEY_F and event.pressed and not event.echo and not is_dead and not is_dying:
		toggle_flashlight()
	# Push/Pull mode with B key
	if event is InputEventKey and event.keycode == KEY_B and not is_dead and not is_dying:
		if event.pressed and not event.echo:
			start_push_pull_mode()
		elif not event.pressed:
			stop_push_pull_mode()
	# Handle hotbar and inventory input
	handle_hotbar_input(event)
	handle_inventory_input(event)
	# Debug keys
	if event is InputEventKey && event.keycode == KEY_1 && event.pressed && !event.echo:
		debug_take_damage()
	if event is InputEventKey && event.keycode == KEY_2 && event.pressed && !event.echo:
		debug_heal()
	# Debug materials key
	if event is InputEventKey && event.keycode == KEY_G && event.pressed && !event.echo:
		debug_give_materials()
	# Debug visual inventory test
	if event is InputEventKey && event.keycode == KEY_V && event.pressed && !event.echo:
		debug_test_visual_inventory()
		
	# --- Handle Restart Input during Death Sequence ---
	if is_dead and dead_screen and dead_screen.visible:
		if event is InputEventKey and event.keycode == KEY_R and event.pressed and not event.echo:
			restart_game()

# HOTBAR INPUT
func handle_hotbar_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: 
				select_hotbar_slot(0)
				use_hotbar_item(0)
			KEY_2: 
				select_hotbar_slot(1)
				use_hotbar_item(1)
			KEY_3: 
				select_hotbar_slot(2)
				use_hotbar_item(2)
			KEY_4: 
				select_hotbar_slot(3)
				use_hotbar_item(3)
			KEY_5: 
				select_hotbar_slot(4)
				use_hotbar_item(4)
	# Mouse wheel to select hotbar slots (without using)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_hotbar_slot((selected_hotbar_slot - 1) % hotbar_slots)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_hotbar_slot((selected_hotbar_slot + 1) % hotbar_slots)

# INVENTORY INPUT
func handle_inventory_input(event):
	# I key to open/close inventory menu
	if event is InputEventKey and event.keycode == KEY_I and event.pressed and not event.echo:
		toggle_inventory_menu()
	# Tab key alternative for inventory
	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed and not event.echo:
		toggle_inventory_menu()

func select_hotbar_slot(slot_index: int):
	if slot_index >= 0 and slot_index < hotbar_slots:
		selected_hotbar_slot = slot_index
		update_hotbar_ui()
		var slot_data = hotbar[selected_hotbar_slot]
		if slot_data:
			print("Selected hotbar slot ", selected_hotbar_slot + 1, ": ", slot_data.count, " ", slot_data.item.capitalize())
		else:
			print("Selected empty hotbar slot ", selected_hotbar_slot + 1)

func toggle_inventory_menu():
	inventory_ui_open = not inventory_ui_open
	if inventory_menu:
		inventory_menu.visible = inventory_ui_open
		# Set proper z-index to appear on top
		if inventory_ui_open:
			inventory_menu.z_index = 100
			show_inventory_menu()
		else:
			hide_inventory_menu()
	else:
		print("ERROR: Inventory menu UI not found!")
		print("Please create: UI/InventoryMenu with proper structure")
		# Show console inventory as fallback
		print("=== INVENTORY (Console Fallback) ===")
		for material in inventory:
			if inventory[material] > 0:
				print("  ", material.capitalize(), ": ", inventory[material])
		print("===================================")

func show_inventory_menu():
	print("Opening visual inventory menu...")
	if inventory_grid:
		update_visual_inventory()
	else:
		print("ERROR: InventoryGrid not found! Check UI structure")

func hide_inventory_menu():
	print("Closing visual inventory menu")

# UI FUNCTIONS
func create_hotbar_ui():
	print("Creating hotbar UI...")
	if not hotbar_slots_container:
		print("ERROR: Hotbar slots container not found!")
		return
	# Style the hotbar slots
	for i in range(hotbar_slots_container.get_child_count()):
		var slot = hotbar_slots_container.get_child(i)
		if slot is Panel:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.1, 0.1, 0.2, 0.9)  # Dark blue background
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.border_color = Color.GRAY
			slot.add_theme_stylebox_override("panel", style)

func update_hotbar_ui():
	if not hotbar_slots_container:
		return
	# Update each hotbar slot's visual
	for i in range(min(hotbar_slots, hotbar_slots_container.get_child_count())):
		var slot_panel = hotbar_slots_container.get_child(i)
		var slot_data = hotbar[i]
		var item_icon = slot_panel.find_child("ItemIcon")
		var count_label = slot_panel.find_child("CountLabel")
		if slot_data != null:
			# Slot has an equipped item
			if item_icon:
				item_icon.texture = get_item_texture(slot_data.item)
				item_icon.visible = true
			if count_label:
				if slot_data.count > 1:
					count_label.text = str(slot_data.count)
					count_label.visible = true
				else:
					count_label.visible = false
		else:
			# Empty slot
			if item_icon:
				item_icon.visible = false
			if count_label:
				count_label.visible = false
		# Highlight selected slot
		if slot_panel is Panel:
			var style = slot_panel.get_theme_stylebox("panel")
			if style is StyleBoxFlat:
				if i == selected_hotbar_slot:
					style.border_color = Color.YELLOW
					style.border_width_left = 3
					style.border_width_right = 3
					style.border_width_top = 3
					style.border_width_bottom = 3
				else:
					style.border_color = Color.GRAY
					style.border_width_left = 2
					style.border_width_right = 2
					style.border_width_top = 2
					style.border_width_bottom = 2

func get_item_texture(item_name: String) -> Texture2D:
	match item_name:
		"spike_trap":
			return load("res://assets/items/spike_trap_icon.png")
		"poison_trap":
			return load("res://assets/items/poison_trap_icon.png")
		"rope_trap":
			return load("res://assets/items/rope_trap_icon.png")
		"fire_trap":
			return load("res://assets/items/fire_trap_icon.png")
		"health_potion":
			return load("res://assets/items/health_potion_icon.png")
		"super_health_potion":
			return load("res://assets/items/super_health_potion_icon.png")
		"golden_key":
			return load("res://assets/items/golden_key_icon.png")
		"crystal_weapon":
			return load("res://assets/items/crystal_weapon_icon.png")
		"flashlight":
			return load("res://assets/items/flashlight_icon.png")
		_:
			return load("res://icon.png")

func show_pickup_message(item_name: String, amount: int):
	print("COLLECTED: ", amount, " ", item_name.capitalize())

# DEBUG FUNCTIONS
func debug_give_materials():
	print("DEBUG: Adding test materials...")
	add_material("wood", 10)
	add_material("metal", 5)
	add_material("gold", 2)      # Rare
	add_material("bones", 3)
	add_material("blood", 2)
	add_material("stone", 8)     # More common
	add_material("rope", 3)
	add_material("crystal", 1)   # Very rare
	add_material("coal", 4)      # Fuel
	print("All materials added! Press I to view inventory")

func debug_test_visual_inventory():
	print("DEBUG: Testing visual inventory...")
	# Add some materials for testing
	add_material("wood", 5)
	add_material("metal", 3)
	add_material("gold", 1)
	add_material("bones", 2)
	# Open inventory to see results
	toggle_inventory_menu()

func debug_give_test_items():
	print("DEBUG: Adding test tools to hotbar...")
	equip_to_hotbar("spike_trap", 0, 3)
	equip_to_hotbar("poison_trap", 1, 2)
	equip_to_hotbar("health_potion", 2, 1)
	print("Tools added to hotbar!")

func debug_pushable_objects():
	await get_tree().process_frame
	var pushable_objects = get_tree().get_nodes_in_group("pushable")
	print("=== PUSHABLE OBJECTS DEBUG ===")
	print("Total pushable objects: ", pushable_objects.size())
	for obj in pushable_objects:
		print("- ", obj.name, " at position: ", obj.global_position)
		var distance = global_position.distance_to(obj.global_position)
		print("  Distance from player: ", distance)

func check_ui_elements():
	print("=== UI Elements Check ===")
	print("Health UI found: ", health_ui != null)
	print("Health Label found: ", health_label != null) 
	print("Character Portrait found: ", character_portrait != null)
	print("UI Background found: ", ui_background != null)
	print("Key UI found: ", key_ui != null)
	print("Flashlight Light found: ", flashlight_light != null)
	print("Flashlight Area found: ", flashlight_area != null)
	print("Battery UI found: ", battery_ui != null)
	print("Battery Label found: ", battery_label != null)
	print("Hotbar UI found: ", hotbar_ui != null)
	print("Hotbar Slots Container found: ", hotbar_slots_container != null)
	print("Inventory Menu found: ", inventory_menu != null)
	print("Inventory Grid found: ", inventory_grid != null)
	# FORCE INVENTORY TO BE HIDDEN AT START
	if inventory_menu:
		inventory_menu.visible = false
		inventory_ui_open = false
		print("FORCED inventory menu to be hidden at start")
	else:
		print("ERROR: Inventory Menu not found - check UI structure")

func setup_flashlight():
	# Setup flashlight area signals
	if flashlight_area:
		flashlight_area.body_entered.connect(_on_flashlight_area_entered)
		flashlight_area.body_exited.connect(_on_flashlight_area_exited)
		flashlight_area.monitoring = true
		flashlight_area.monitorable = true
	# Configure PointLight2D for Godot 4
	if flashlight_light:
		flashlight_light.enabled = false
		flashlight_light.energy = 3.0
		flashlight_light.texture_scale = 2.0
		flashlight_light.color = Color.WHITE
		# Create light texture if missing
		if not flashlight_light.texture:
			var gradient = Gradient.new()
			gradient.add_point(0.0, Color.WHITE)
			gradient.add_point(1.0, Color.TRANSPARENT)
			var gradient_texture = GradientTexture2D.new()
			gradient_texture.gradient = gradient
			gradient_texture.fill = GradientTexture2D.FILL_RADIAL
			gradient_texture.width = 256
			gradient_texture.height = 256
			flashlight_light.texture = gradient_texture
	# Setup detection area shape
	setup_flashlight_detection_shape()
	# Initialize flashlight state
	set_flashlight(false)

func setup_flashlight_detection_shape():
	if not flashlight_area:
		return
	# Clear existing shapes
	for child in flashlight_area.get_children():
		if child is CollisionShape2D:
			child.queue_free()
	# Create new collision shape
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = flashlight_detection_range
	collision_shape.shape = shape
	flashlight_area.add_child(collision_shape)

func _physics_process(delta):
	if is_dead or is_dying:
		return
	handle_input(delta)
	handle_push_pull_system()
	handle_animation()
	move_and_slide()
	# Handle flashlight battery
	handle_flashlight(delta)
	# Update flashlight direction to face mouse
	if flashlight_on and flashlight_light:
		update_flashlight_direction()

func start_push_pull_mode():
	target_box = find_nearest_box()
	if target_box:
		is_push_pull_mode = true
		var distance = global_position.distance_to(target_box.global_position)
		print("Push/Pull mode activated - Target: ", target_box.name)
		print("Distance to box: ", int(distance), " (need to be within ", push_distance, " to actually move it)")
		if target_box.has_node("Sprite2D"):
			var sprite = target_box.get_node("Sprite2D")
			sprite.modulate = Color(1.2, 1.2, 1.0)
		elif target_box.has_node("ColorRect"):
			var sprite = target_box.get_node("ColorRect")
			sprite.modulate = Color(1.2, 1.2, 1.0)
		elif target_box.has_method("set_modulate"):
			target_box.modulate = Color(1.2, 1.2, 1.0)
	else:
		print("No box nearby to push/pull")

func stop_push_pull_mode():
	if is_push_pull_mode:
		is_push_pull_mode = false
		is_pushing = false
		is_pulling = false
		if target_box:
			if target_box.has_node("Sprite2D"):
				var sprite = target_box.get_node("Sprite2D")
				sprite.modulate = Color.WHITE
			elif target_box.has_node("ColorRect"):
				var sprite = target_box.get_node("ColorRect")
				sprite.modulate = Color.WHITE
			elif target_box.has_method("set_modulate"):
				target_box.modulate = Color.WHITE
		target_box = null

func find_nearest_box() -> RigidBody2D:
	var nearest_box: RigidBody2D = null
	var nearest_distance: float = interaction_distance
	var boxes = get_tree().get_nodes_in_group("pushable")
	for box in boxes:
		if box is RigidBody2D:
			var distance = global_position.distance_to(box.global_position)
			if distance <= interaction_distance:
				if nearest_box == null or distance < nearest_distance:
					nearest_distance = distance
					nearest_box = box
	return nearest_box

func handle_push_pull_system():
	is_pushing = false
	is_pulling = false
	if not is_push_pull_mode or not target_box:
		return
	var distance_to_box = global_position.distance_to(target_box.global_position)
	if distance_to_box > interaction_distance * 1.5:
		stop_push_pull_mode()
		return
	var input_direction = Vector2.ZERO
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left"):
		input_direction.x -= 1
	if Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right"):
		input_direction.x += 1
	if Input.is_action_pressed("move_up") or Input.is_action_pressed("ui_up"):
		input_direction.y -= 1
	if Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down"):
		input_direction.y += 1
	if input_direction.length() > 0:
		input_direction = input_direction.normalized()
		if distance_to_box <= push_distance:
			var force_to_apply = input_direction * push_pull_force
			target_box.apply_central_force(force_to_apply)
			var direction_to_box = (target_box.global_position - global_position).normalized()
			var dot_product = input_direction.dot(direction_to_box)
			if dot_product > 0.1:
				is_pulling = true
			else:
				is_pushing = true

func handle_input(delta):
	var input_dir = Vector2.ZERO
	if not is_knocked_back:
		if Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left"):
			input_dir.x -= 1
		if Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right"):
			input_dir.x += 1
		if Input.is_action_pressed("move_up") or Input.is_action_pressed("ui_up"):
			input_dir.y -= 1
		if Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down"):
			input_dir.y += 1
	if is_knocked_back:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, friction * 2 * delta)
		is_moving = false
	else:
		if input_dir.length() > 0:
			input_dir = input_dir.normalized()
			var movement_speed = speed
			if is_push_pull_mode:
				movement_speed = push_pull_speed
			velocity = velocity.move_toward(input_dir * movement_speed, acceleration * delta)
			is_moving = true
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			is_moving = velocity.length() > 5.0

func toggle_flashlight():
	if not flashlight_enabled:
		return
	if current_battery <= 0:
		print("Battery empty!")
		return
	set_flashlight(not flashlight_on)
	handle_animation()

func set_flashlight(state: bool):
	flashlight_on = state and current_battery > 0
	if flashlight_light:
		flashlight_light.enabled = flashlight_on
	if flashlight_area:
		flashlight_area.monitoring = flashlight_on

func handle_flashlight(delta):
	if flashlight_on and current_battery > 0:
		current_battery -= battery_drain_rate * delta
		current_battery = max(current_battery, 0)
		if current_battery <= 0:
			set_flashlight(false)
			handle_animation()
	update_battery_ui()

func update_flashlight_direction():
	if flashlight_light:
		var mouse_pos = get_global_mouse_position()
		var direction = (mouse_pos - global_position).normalized()
		var angle = direction.angle()
		flashlight_light.rotation = angle
		if flashlight_area:
			flashlight_area.rotation = angle

func update_battery_ui():
	if battery_ui:
		var battery_percentage = current_battery / max_battery
		battery_ui.size.x = 150 * battery_percentage
		if battery_percentage > 0.5:
			battery_ui.color = Color.GREEN
		elif battery_percentage > 0.2:
			battery_ui.color = Color.YELLOW
		else:
			battery_ui.color = Color.RED
	if battery_label:
		var battery_percent = int((current_battery / max_battery) * 100)
		battery_label.text = "Battery: " + str(battery_percent) + "%"

func _on_flashlight_area_entered(body):
	if body.is_in_group("enemy") and body not in enemies_in_light:
		enemies_in_light.append(body)
		if body.has_method("enter_light"):
			body.enter_light()

func _on_flashlight_area_exited(body):
	if body.is_in_group("enemy") and body in enemies_in_light:
		enemies_in_light.erase(body)
		if body.has_method("exit_light"):
			body.exit_light()

func add_battery(amount: float):
	current_battery = min(current_battery + amount, max_battery)
	update_battery_ui()

func get_battery_percentage() -> float:
	return current_battery / max_battery

func get_flashlight_state() -> bool:
	return flashlight_on and current_battery > 0

func handle_animation():
	if not animated_sprite or is_dying:
		return
	if not animated_sprite.sprite_frames:
		return
	if is_moving:
		var walk_anim = "Walk"
		if flashlight_on and animated_sprite.sprite_frames.has_animation("Walk LIGHT"):
			walk_anim = "Walk LIGHT"
		elif animated_sprite.sprite_frames.has_animation("Walk"):
			walk_anim = "Walk"
		if animated_sprite.sprite_frames.has_animation(walk_anim):
			if animated_sprite.animation != walk_anim:
				animated_sprite.play(walk_anim)
	else:
		if animated_sprite.sprite_frames.has_animation("Idel"):
			if animated_sprite.animation != "Idel":
				animated_sprite.play("Idel")
		elif animated_sprite.sprite_frames.has_animation("idle"):
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")

# Keep all existing functions (health, combat, etc.)
func attempt_exit():
	if can_exit and can_escape():
		trigger_escape()
	elif can_exit and not can_escape():
		var needed = keys_needed_to_escape - collected_keys.size()
		print("Need ", needed, " more keys to escape!")

func trigger_escape():
	print("Victory! Player has escaped!")
	get_tree().create_timer(1.0).timeout.connect(func():
		get_tree().reload_current_scene()
	)

func collect_key(key_id: String):
	if key_id in collected_keys:
		return
	collected_keys.append(key_id)
	print("Collected key: ", key_id, " (", collected_keys.size(), "/", keys_needed_to_escape, ")")
	update_key_ui()
	check_escape_condition()

func update_key_ui():
	if key_ui:
		key_ui.text = "Keys: " + str(collected_keys.size()) + "/" + str(keys_needed_to_escape)

func check_escape_condition():
	if collected_keys.size() >= keys_needed_to_escape:
		print("All keys collected! Exit is now available!")

func can_escape() -> bool:
	return collected_keys.size() >= keys_needed_to_escape

func take_damage(amount: int, attacker_position: Vector2 = Vector2.ZERO):
	if is_invincible or is_dead or is_dying:
		return
	current_health -= amount
	current_health = max(current_health, 0)
	if is_push_pull_mode:
		stop_push_pull_mode()
	health_changed.emit(current_health)
	update_health_ui()
	apply_knockback(attacker_position)
	hurt_effect()
	if current_health <= 0:
		die()
	else:
		become_invincible()

func apply_knockback(attacker_position: Vector2):
	var knockback_direction: Vector2
	if attacker_position != Vector2.ZERO:
		knockback_direction = (global_position - attacker_position).normalized()
	else:
		knockback_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	knockback_velocity = knockback_direction * knockback_force
	is_knocked_back = true
	get_tree().create_timer(knockback_duration).timeout.connect(stop_knockback)

func stop_knockback():
	is_knocked_back = false
	knockback_velocity = Vector2.ZERO

func become_invincible():
	is_invincible = true
	if animated_sprite:
		var blink_duration = 0.1
		var total_blinks = int(invincible_time / blink_duration)
		for i in range(total_blinks):
			if not is_dead and not is_dying:
				animated_sprite.modulate.a = 0.3
				await get_tree().create_timer(blink_duration / 2).timeout
				if not is_dead and not is_dying:
					animated_sprite.modulate.a = 1.0
					await get_tree().create_timer(blink_duration / 2).timeout
	if animated_sprite and not is_dead and not is_dying:
		animated_sprite.modulate.a = 1.0
	is_invincible = false

func hurt_effect():
	if animated_sprite:
		animated_sprite.modulate = Color.RED
		var flash_tween = create_tween()
		flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)

func update_health_ui():
	if health_ui:
		var health_percentage = float(current_health) / float(max_health)
		health_ui.size.x = health_bar_max_width * health_percentage
		health_ui.color = Color(1, 0, 0, 1.0)
	if health_label:
		health_label.text = str(current_health) + "/" + str(max_health)

func heal(amount: int):
	if is_dead or is_dying:
		return
	current_health += amount
	current_health = min(current_health, max_health)
	health_changed.emit(current_health)
	update_health_ui()

# --- MODIFIED DEATH SEQUENCE ---
func die():
	if is_dead or is_dying:
		return
	is_dying = true
	velocity = Vector2.ZERO
	set_flashlight(false)
	stop_push_pull_mode()
	
	# --- Play Death Animations ---
	# 1. Play the "dead" animation on the player sprite
	if animated_sprite and animated_sprite.sprite_frames.has_animation("dead"):
		animated_sprite.play("dead")
		# Wait for the animation to finish (or a portion of it)
		# Adjust the wait time or use animation_finished signal if needed
		await get_tree().create_timer(0.5).timeout # Adjust delay as needed or wait for animation end
	
	# 2. Play the "crying" animation on the UI portrait
	if character_portrait and character_portrait.sprite_frames and character_portrait.sprite_frames.has_animation("crying"):
		character_portrait.play("crying")
	
	# 3. Show the "U DEAD" screen
	if dead_screen:
		dead_screen.show()
	
	# 4. Show and start blinking the restart label after a short delay
	if restart_label:
		await get_tree().create_timer(1.0).timeout # Wait a bit before showing the prompt
		if restart_label: # Check again in case it was freed
			restart_label.show()
			# Start blinking animation for the label
			var blink_tween = create_tween().set_loops()
			blink_tween.tween_property(restart_label, "modulate:a", 0.0, 0.8) # Fade out
			blink_tween.tween_property(restart_label, "modulate:a", 1.0, 0.8) # Fade in
			# Note: The loop will stop when the node is freed or scene changes.
	
	# Signal that the player died
	player_died.emit()
	
	# Mark as dead after animations start
	is_dead = true
	is_dying = false
	# Do NOT call restart_game here. It's handled by _input.

# --- MODIFIED RESTART GAME ---
func restart_game():
	# Stop any ongoing tweens related to the restart label to prevent errors
	# This is a simple way, you might need to manage tweens more carefully
	# if you have many of them.
	# For the blinking tween, it's usually fine as it loops on a node that will be freed.
	
	# Hide the death screen elements if they exist
	if dead_screen:
		dead_screen.hide()
	if restart_label:
		restart_label.hide()
		
	# Reload the scene
	get_tree().reload_current_scene()

func get_damaged_by_enemy(damage: int, enemy_position: Vector2 = Vector2.ZERO):
	take_damage(damage, enemy_position)

func set_can_exit(value: bool):
	can_exit = value

func debug_take_damage():
	var fake_attacker_pos = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
	take_damage(15, fake_attacker_pos)

func debug_heal():
	heal(20)

func debug_kill_player():
	print("DEBUG: Instant death!")
	current_health = 0
	die()

# Functions for collectible items to call
func collect_item(item_name: String, amount: int = 1):
	add_material(item_name, amount)

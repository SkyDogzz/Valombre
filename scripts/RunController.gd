extends Node
class_name RunController

const ENEMY_SCRIPT := preload("res://scripts/Enemy.gd")
const PROFILE_SCHEMA_VERSION := 2
const WORLD_SIZE := Vector2(1500.0, 1100.0)
const OBSTACLES := [Vector3(605, 530, 27), Vector3(898, 605, 31), Vector3(770, 415, 23), Vector3(735, 705, 24)]

var main: Node2D
var arena: Arena
var player: ValombrePlayer
var catalog: ContentCatalog
var state := "title"
var hero_id := "pilgrim"
var weapon_id := "sabre"
var mode := "waves"
var difficulty_id := "insane"
var wave := 0
var defeated := 0
var hp := 100.0
var max_hp := 100.0
var base_hp := 100.0
var bonus_max_hp := 0.0
var xp := 0.0
var next_xp := 5.0
var level := 1
var damage_multiplier := 1.0
var attack_speed_multiplier := 1.0
var range_bonus := 0.0
var movement_multiplier := 1.0
var defense := 0.0
var pickup_range := 90.0
var pickup_range_multiplier := 1.0
var upgrade_ranks := {"damage": 0, "attackSpeed": 0, "range": 0, "projectileSize": 0, "projectileSpeed": 0, "movementSpeed": 0, "health": 0, "defense": 0, "pickupRange": 0}
var pending_upgrades := 0
var weapon_cooldown := 0.0
var spawn_clock := 1.0
var intermission := 0.0
var contact_cooldown := 0.0
var skill_cooldown := 0.0
var pending_spawns: Array[Dictionary] = []
var wave_groups: Array[Dictionary] = []
var swarm_timer := -1.0
var boss_after_wave_id := ""
var enemies: Array[ValombreEnemy] = []
var drops: Array[Dictionary] = []
var weapon_inventory: Array[Dictionary] = []
var relic_inventory: Array[Dictionary] = []
var weapon_cooldowns: Dictionary = {}
var weapon_attack_timers: Dictionary = {}
var equipment_damage := 1.0
var equipment_speed := 1.0
var equipment_range := 0.0
var equipment_defense := 0.0
var equipment_xp := 1.0
var equipment_lifesteal := 0.0
var global_pickup := false
var player_shield := 0.0
var cheat_infinite_life := false
var scythe_souls := 0
var weapon_swing_counts: Dictionary = {}
var projectiles: Array[Dictionary] = []
var damage_zones: Array[Dictionary] = []
var damage_numbers: Array[Dictionary] = []
var weapon_effects: Array[Dictionary] = []
var projectile_size_multiplier := 1.0
var projectile_speed_multiplier := 1.0
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var objective_type := "kills"
var objective_progress := 0
var objective_target := 12
var objective_complete := false
var run_challenges: Array[Dictionary] = []
var single_weapon := false
var uncapped_inventory := false
var custom_drops := false
var selected_drop_weapons: Array[String] = []
var selected_drop_relics: Array[String] = []
var profile := {"schema_version": 2, "wins": 0, "bestKills": 0, "shards": 0, "run": null, "hero": "pilgrim", "weapon": "sabre", "mode": "waves", "difficulty": "insane", "singleWeapon": false, "uncappedInventory": false, "customDrops": false, "dropWeapons": [], "dropRelics": [], "bestiary": {}, "discoveredWeapons": {}, "discoveredRelics": {}, "discoveredSynergies": {}, "muted": false, "volume": 0.25, "autoPickUpgrade": true}
var result_recorded := false
var notice_text := ""
var notice_timer := 0.0

var layer: CanvasLayer
var menu_panel: PanelContainer
var overlay_backdrop: ColorRect
var title_label: Label
var status_label: Label
var picker_labels: Array[Label] = []
var hero_picker: OptionButton
var weapon_picker: OptionButton
var mode_picker: OptionButton
var difficulty_picker: OptionButton
var start_button: Button
var new_run_button: Button
var single_weapon_toggle: CheckBox
var uncapped_inventory_toggle: CheckBox
var custom_drops_toggle: CheckBox
var weapon_drop_menu: MenuButton
var relic_drop_menu: MenuButton
var drop_filter_row: HBoxContainer
var hud: Label
var inventory_panel: PanelContainer
var inventory_list: VBoxContainer
var inventory_open := false
var pause_catalog: ScrollContainer
var pause_catalog_list: VBoxContainer
var auto_pick_toggle: CheckBox
var auto_pick_remaining := -1.0
var upgrade_choices: Array[GameDefinition] = []
var upgrade_buttons: Array[Button] = []
var loot_buttons: Array[Button] = []
var menu_column: VBoxContainer
var boss_bar: ProgressBar
var health_bar: ProgressBar
var shield_bar: ProgressBar
var xp_bar: ProgressBar
var boss_name_label: Label
var notice_label: Label
var ability_label: Label
var mute_toggle: CheckBox
var volume_slider: HSlider
var reset_button: Button
var cheat_button: Button
var audio_player: AudioStreamPlayer
var sound_generator: AudioStreamGenerator
var sound_playback: AudioStreamGeneratorPlayback
var sound_phase := 0.0
var held_weapon_sprite: Sprite2D
var mouse_aim_active := false
var touch_controls: ValombreTouchControls
var particle_layer: ValombreParticleLayer
var combat_effects: ValombreCombatEffects

func _ready() -> void:
	_configure_gamepad_inputs()
	main = get_parent()
	arena = main.get_node("Arena")
	player = arena.get_node("Player")
	particle_layer = ValombreParticleLayer.new()
	particle_layer.name = "CombatParticles"
	particle_layer.z_index = 10
	particle_layer.set_process(false)
	arena.add_child(particle_layer)
	combat_effects = ValombreCombatEffects.new()
	combat_effects.name = "CombatEffects"
	combat_effects.set_process(false)
	arena.add_child(combat_effects)
	player.dodge_started.connect(func(position: Vector2) -> void: _spawn_burst(position, Color("d9c18a"), 8))
	catalog = main.catalog
	_load_profile()
	hero_id = str(profile.hero)
	weapon_id = str(profile.weapon)
	mode = str(profile.mode)
	difficulty_id = str(profile.difficulty)
	single_weapon = bool(profile.singleWeapon)
	uncapped_inventory = bool(profile.uncappedInventory)
	custom_drops = bool(profile.customDrops)
	selected_drop_weapons.assign(profile.dropWeapons)
	selected_drop_relics.assign(profile.dropRelics)
	rng.randomize()
	_create_interface()
	_create_audio()
	_create_held_weapon_sprite()
	_create_cheat_button()
	_update_player_visuals()
	player.run_active = false

func _configure_gamepad_inputs() -> void:
	_add_gamepad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_gamepad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_gamepad_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_gamepad_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_gamepad_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_gamepad_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_gamepad_button("move_up", JOY_BUTTON_DPAD_UP)
	_add_gamepad_button("move_down", JOY_BUTTON_DPAD_DOWN)
	_add_gamepad_button("attack", JOY_BUTTON_A)
	_add_gamepad_button("special", JOY_BUTTON_Y)
	_add_gamepad_button("dodge", JOY_BUTTON_LEFT_SHOULDER)
	_add_gamepad_button("pause", JOY_BUTTON_START)
	_add_gamepad_button("inventory", JOY_BUTTON_RIGHT_SHOULDER)

func _add_gamepad_axis(action: String, axis: int, direction: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	InputMap.action_add_event(action, event)

func _add_gamepad_button(action: String, button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		mouse_aim_active = true
	if event.is_action_pressed("pause"):
		if state == "playing":
			inventory_open = false
			inventory_panel.visible = false
			_set_state("paused")
		elif state == "paused":
			pause_catalog.visible = false
			_set_state("playing")
		elif state in ["victory", "defeat"]:
			_set_state("title")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and state == "playing":
		inventory_open = not inventory_open
		inventory_panel.visible = inventory_open
		_refresh_inventory_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("special") and state == "playing":
		_use_hero_skill()
	elif state == "levelUp" and ((event is InputEventKey and event.pressed) or event is InputEventMouseMotion or event is InputEventMouseButton):
		auto_pick_remaining = 3.0

func _process(delta: float) -> void:
	if state == "levelUp" and auto_pick_remaining >= 0.0:
		auto_pick_remaining -= delta
		if auto_pick_remaining <= 0.0 and not upgrade_choices.is_empty():
			_apply_upgrade(upgrade_choices[0])
			return
	if state != "playing":
		return
	notice_timer = maxf(0.0, notice_timer - delta)
	elapsed += delta
	weapon_cooldown = maxf(0.0, weapon_cooldown - delta)
	for id in weapon_cooldowns.keys():
		weapon_cooldowns[id] = maxf(0.0, float(weapon_cooldowns[id]) - delta)
	for id in weapon_attack_timers.keys():
		weapon_attack_timers[id] = maxf(0.0, float(weapon_attack_timers[id]) - delta)
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	skill_cooldown = maxf(0.0, skill_cooldown - delta)
	if intermission > 0.0:
		intermission -= delta
		_process_weapon_effects(delta)
		if intermission <= 0.0:
			_start_wave(wave + 1)
	else:
		_update_spawns(delta)
		_update_enemies(delta)
		if state != "playing":
			return
		_process_weapon_effects(delta)
		_update_projectiles(delta)
		if state != "playing":
			return
		_update_damage_zones(delta)
		if state != "playing":
			return
		_update_auto_attack()
		if state != "playing":
			return
	_update_player_visuals()
	_update_drops(delta)
	_update_damage_numbers(delta)
	_update_hud()
	if inventory_open:
		_refresh_inventory_panel()

func _create_interface() -> void:
	layer = CanvasLayer.new()
	main.add_child(layer)
	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_panel.custom_minimum_size = Vector2(390, 0)
	var dialog_style := StyleBoxFlat.new()
	dialog_style.bg_color = Color("1b1b17")
	dialog_style.border_color = Color("796443")
	dialog_style.set_border_width_all(1)
	dialog_style.content_margin_left = 30.0
	dialog_style.content_margin_right = 30.0
	dialog_style.content_margin_top = 28.0
	dialog_style.content_margin_bottom = 24.0
	dialog_style.shadow_color = Color(0.0, 0.0, 0.0, 0.73)
	dialog_style.shadow_size = 18
	dialog_style.shadow_offset = Vector2(0.0, 12.0)
	menu_panel.add_theme_stylebox_override("panel", dialog_style)
	layer.add_child(menu_panel)
	var column := VBoxContainer.new()
	menu_column = column
	column.add_theme_constant_override("separation", 12)
	menu_panel.add_child(column)
	title_label = Label.new()
	title_label.text = "LES CENDRES DE VALOMBRE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	column.add_child(title_label)
	var subtitle := Label.new()
	subtitle.text = "La nuit se lève. Les morts se sont éveillés."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	hero_picker = _add_picker(column, "Héros", ["Le Pèlerin", "La Sentinelle"])
	weapon_picker = _add_picker(column, "Arme de départ", [])
	for weapon in catalog.definitions.get("weapons", []):
		weapon_picker.add_item(weapon.display_name)
		weapon_picker.set_item_metadata(weapon_picker.item_count - 1, str(weapon.id))
	hero_picker.select(1 if hero_id == "sentinel" else 0)
	for index in weapon_picker.item_count:
		if str(weapon_picker.get_item_metadata(index)) == weapon_id:
			weapon_picker.select(index)
			break
	hero_picker.item_selected.connect(func(index: int) -> void:
		profile.hero = "sentinel" if index == 1 else "pilgrim"
		_save_profile()
	)
	weapon_picker.item_selected.connect(func(index: int) -> void:
		profile.weapon = str(weapon_picker.get_item_metadata(index))
		_save_profile()
	)
	mode_picker = _add_picker(column, "Mode", ["Vagues", "Infini"])
	difficulty_picker = _add_picker(column, "Difficulté", ["Insane", "Nightmare", "Cataclysm"])
	mode_picker.select(1 if mode == "infinite" else 0)
	difficulty_picker.select(["insane", "nightmare", "cataclysm"].find(difficulty_id))
	mode_picker.item_selected.connect(func(index: int) -> void:
		profile.mode = "infinite" if index == 1 else "waves"
		_save_profile()
	)
	difficulty_picker.item_selected.connect(func(index: int) -> void:
		profile.difficulty = ["insane", "nightmare", "cataclysm"][index]
		_save_profile()
	)
	single_weapon_toggle = CheckBox.new()
	single_weapon_toggle.text = "Butin : arme de départ uniquement"
	single_weapon_toggle.button_pressed = single_weapon
	single_weapon_toggle.toggled.connect(_on_single_weapon_toggled)
	column.add_child(single_weapon_toggle)
	uncapped_inventory_toggle = CheckBox.new()
	uncapped_inventory_toggle.text = "Inventaire sans limite"
	uncapped_inventory_toggle.button_pressed = uncapped_inventory
	uncapped_inventory_toggle.toggled.connect(_on_uncapped_inventory_toggled)
	column.add_child(uncapped_inventory_toggle)
	custom_drops_toggle = CheckBox.new()
	custom_drops_toggle.text = "Filtrer les armes et reliques obtenues"
	custom_drops_toggle.button_pressed = custom_drops
	custom_drops_toggle.toggled.connect(_on_custom_drops_toggled)
	column.add_child(custom_drops_toggle)
	auto_pick_toggle = CheckBox.new()
	auto_pick_toggle.text = "Choisir la première amélioration après 3 s"
	auto_pick_toggle.button_pressed = bool(profile.get("autoPickUpgrade", true))
	auto_pick_toggle.toggled.connect(_on_auto_pick_toggled)
	column.add_child(auto_pick_toggle)
	mute_toggle = CheckBox.new()
	mute_toggle.text = "Muet"
	mute_toggle.button_pressed = bool(profile.muted)
	mute_toggle.toggled.connect(_on_mute_toggled)
	column.add_child(mute_toggle)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = float(profile.volume)
	volume_slider.value_changed.connect(_on_volume_changed)
	column.add_child(volume_slider)
	reset_button = Button.new()
	reset_button.text = "Effacer la progression et les options"
	reset_button.pressed.connect(_reset_profile)
	column.add_child(reset_button)
	drop_filter_row = HBoxContainer.new()
	column.add_child(drop_filter_row)
	weapon_drop_menu = _add_drop_menu(drop_filter_row, "Armes autorisées", "weapons", selected_drop_weapons)
	relic_drop_menu = _add_drop_menu(drop_filter_row, "Reliques autorisées", "relics", selected_drop_relics)
	_update_drop_filter_controls()
	start_button = Button.new()
	start_button.text = "Entrer dans la forêt"
	start_button.pressed.connect(_on_start_pressed)
	column.add_child(start_button)
	new_run_button = Button.new()
	new_run_button.text = "Nouvelle run"
	new_run_button.pressed.connect(_on_new_run_pressed)
	column.add_child(new_run_button)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status_label)
	pause_catalog = ScrollContainer.new()
	pause_catalog.custom_minimum_size = Vector2(520, 330)
	pause_catalog.visible = false
	column.add_child(pause_catalog)
	pause_catalog_list = VBoxContainer.new()
	pause_catalog_list.custom_minimum_size.x = 520
	pause_catalog.add_child(pause_catalog_list)
	shield_bar = _create_hud_bar(Vector2(18, 18), Vector2(130, 5), Color("8cb7c5"))
	health_bar = _create_hud_bar(Vector2(18, 27), Vector2(130, 5), Color("c44c3b"))
	xp_bar = _create_hud_bar(Vector2(18, 36), Vector2(130, 5), Color("b686c8"))
	hud = Label.new()
	hud.position = Vector2(18, 52)
	hud.add_theme_font_size_override("font_size", 11)
	hud.add_theme_color_override("font_color", Color("eee2c5"))
	hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(hud)
	ability_label = Label.new()
	ability_label.position = Vector2(18, 500)
	ability_label.size = Vector2(460, 24)
	ability_label.add_theme_font_size_override("font_size", 10)
	ability_label.add_theme_color_override("font_color", Color("d8c9a8"))
	layer.add_child(ability_label)
	notice_label = Label.new()
	notice_label.position = Vector2(250, 460)
	notice_label.size = Vector2(460, 30)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_color_override("font_color", Color("f2d89b"))
	layer.add_child(notice_label)
	boss_name_label = Label.new()
	boss_name_label.position = Vector2(290, 82)
	boss_name_label.size = Vector2(380, 13)
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 10)
	boss_name_label.add_theme_color_override("font_color", Color("ead8b4"))
	boss_name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	boss_name_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(boss_name_label)
	boss_bar = ProgressBar.new()
	boss_bar.position = Vector2(290, 100)
	boss_bar.size = Vector2(380, 9)
	boss_bar.show_percentage = false
	var boss_track := StyleBoxFlat.new()
	boss_track.bg_color = Color("17120f")
	boss_track.border_color = Color("6b4a39")
	boss_track.set_border_width_all(1)
	boss_track.shadow_color = Color(0.0, 0.0, 0.0, 0.75)
	boss_track.shadow_size = 4
	boss_track.shadow_offset = Vector2(0.0, 2.0)
	boss_bar.add_theme_stylebox_override("background", boss_track)
	var boss_fill := StyleBoxFlat.new()
	boss_fill.bg_color = Color("b74634")
	boss_bar.add_theme_stylebox_override("fill", boss_fill)
	layer.add_child(boss_bar)
	boss_name_label.visible = false
	boss_bar.visible = false
	inventory_panel = PanelContainer.new()
	inventory_panel.position = Vector2(620, 90)
	inventory_panel.custom_minimum_size = Vector2(320, 0)
	inventory_panel.visible = false
	layer.add_child(inventory_panel)
	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.custom_minimum_size = Vector2(320, 360)
	inventory_panel.add_child(inventory_scroll)
	inventory_list = VBoxContainer.new()
	inventory_list.custom_minimum_size.x = 300
	inventory_scroll.add_child(inventory_list)
	touch_controls = ValombreTouchControls.new()
	touch_controls.name = "TouchControls"
	touch_controls.player = player
	touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_controls.visible = false
	layer.add_child(touch_controls)
	overlay_backdrop = ColorRect.new()
	overlay_backdrop.color = Color(0.043, 0.047, 0.035, 0.72)
	overlay_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_backdrop.visible = false
	layer.add_child(overlay_backdrop)
	layer.move_child(menu_panel, layer.get_child_count() - 1)
	status_label.visible = false
	_set_state("title")
	_update_hud()

func _create_hud_bar(bar_position: Vector2, bar_size: Vector2, tint: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = bar_position
	bar.size = bar_size
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	var shield_style := tint.g > 0.65 and tint.b > 0.65
	background.bg_color = Color("111d27") if shield_style else Color("282821")
	background.border_color = Color("315c75") if shield_style else Color("464438")
	background.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint
	bar.add_theme_stylebox_override("fill", fill)
	layer.add_child(bar)
	return bar

func _add_picker(parent: VBoxContainer, label_text: String, choices: Array) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	picker_labels.append(label)
	var picker := OptionButton.new()
	for choice in choices:
		picker.add_item(choice)
	parent.add_child(picker)
	return picker

func _add_drop_menu(parent: HBoxContainer, title: String, group: String, selected_ids: Array[String]) -> MenuButton:
	var button := MenuButton.new()
	button.text = title
	var popup := button.get_popup()
	var records: Array = catalog.content.weapons.values() if group == "weapons" else catalog.content.relics
	var ids: Array = catalog.content.weapons.keys() if group == "weapons" else catalog.content.relics.map(func(item: Dictionary) -> String: return str(item.id))
	for index in ids.size():
		var record: Dictionary = records[index] if group == "relics" else catalog.content.weapons[ids[index]]
		popup.add_check_item(str(record.get("name", record.get("displayName", ids[index]))), index)
		popup.set_item_metadata(index, str(ids[index]))
		popup.set_item_checked(index, selected_ids.has(str(ids[index])))
	if group == "weapons":
		popup.id_pressed.connect(_on_weapon_filter_pressed)
	else:
		popup.id_pressed.connect(_on_relic_filter_pressed)
	parent.add_child(button)
	return button

func _on_weapon_filter_pressed(item_id: int) -> void:
	var popup := weapon_drop_menu.get_popup()
	var index := popup.get_item_index(item_id)
	popup.set_item_checked(index, not popup.is_item_checked(index))
	selected_drop_weapons.clear()
	for item_index in popup.item_count:
		if popup.is_item_checked(item_index):
			selected_drop_weapons.append(str(popup.get_item_metadata(item_index)))
	profile.dropWeapons = selected_drop_weapons.duplicate()
	_save_profile()

func _on_relic_filter_pressed(item_id: int) -> void:
	var popup := relic_drop_menu.get_popup()
	var index := popup.get_item_index(item_id)
	popup.set_item_checked(index, not popup.is_item_checked(index))
	selected_drop_relics.clear()
	for item_index in popup.item_count:
		if popup.is_item_checked(item_index):
			selected_drop_relics.append(str(popup.get_item_metadata(item_index)))
	profile.dropRelics = selected_drop_relics.duplicate()
	_save_profile()

func _on_single_weapon_toggled(enabled: bool) -> void:
	single_weapon = enabled
	profile.singleWeapon = enabled
	_save_profile()

func _on_uncapped_inventory_toggled(enabled: bool) -> void:
	uncapped_inventory = enabled
	profile.uncappedInventory = enabled
	_save_profile()

func _on_custom_drops_toggled(enabled: bool) -> void:
	custom_drops = enabled
	profile.customDrops = enabled
	_update_drop_filter_controls()
	_save_profile()

func _on_auto_pick_toggled(enabled: bool) -> void:
	profile.autoPickUpgrade = enabled
	if state == "levelUp":
		auto_pick_remaining = 3.0 if enabled else -1.0
	_save_profile()

func _on_mute_toggled(enabled: bool) -> void:
	profile.muted = enabled
	_save_profile()

func _on_volume_changed(value: float) -> void:
	profile.volume = value
	_save_profile()

func _reset_profile() -> void:
	var confirmation := ConfirmationDialog.new()
	confirmation.dialog_text = "Effacer la run, les découvertes, les victoires, les éclats et toutes les options sauvegardées ?"
	confirmation.confirmed.connect(func() -> void:
		profile = {"schema_version": PROFILE_SCHEMA_VERSION, "wins": 0, "bestKills": 0, "shards": 0, "run": null, "hero": "pilgrim", "weapon": "sabre", "mode": "waves", "difficulty": "insane", "singleWeapon": false, "uncappedInventory": false, "customDrops": false, "dropWeapons": [], "dropRelics": [], "bestiary": {}, "discoveredWeapons": {}, "discoveredRelics": {}, "discoveredSynergies": {}, "muted": false, "volume": 0.25, "autoPickUpgrade": true}
		hero_id = "pilgrim"
		weapon_id = "sabre"
		mode = "waves"
		difficulty_id = "insane"
		single_weapon = false
		uncapped_inventory = false
		custom_drops = false
		cheat_infinite_life = false
		selected_drop_weapons.clear()
		selected_drop_relics.clear()
		_load_profile_defaults()
		hero_picker.select(0)
		mode_picker.select(0)
		difficulty_picker.select(0)
		weapon_picker.select(0)
		single_weapon_toggle.set_pressed_no_signal(false)
		uncapped_inventory_toggle.set_pressed_no_signal(false)
		custom_drops_toggle.set_pressed_no_signal(false)
		auto_pick_toggle.set_pressed_no_signal(true)
		mute_toggle.set_pressed_no_signal(false)
		volume_slider.value = 0.25
		_refresh_drop_popup_checks()
		_update_drop_filter_controls()
		_save_profile()
		_set_state("title")
	)
	main.add_child(confirmation)
	confirmation.popup_centered()

func _load_profile_defaults() -> void:
	for id in catalog.content.weapons:
		selected_drop_weapons.append(str(id))
	for relic: Dictionary in catalog.content.relics:
		selected_drop_relics.append(str(relic.id))
	profile.dropWeapons = selected_drop_weapons.duplicate()
	profile.dropRelics = selected_drop_relics.duplicate()
	profile.singleWeapon = false
	profile.uncappedInventory = false
	profile.customDrops = false

func _create_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	sound_generator = AudioStreamGenerator.new()
	sound_generator.mix_rate = 22050.0
	sound_generator.buffer_length = 0.12
	audio_player.stream = sound_generator
	main.add_child(audio_player)
	audio_player.play()
	sound_playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _create_held_weapon_sprite() -> void:
	held_weapon_sprite = Sprite2D.new()
	held_weapon_sprite.name = "HeldWeaponSprite"
	held_weapon_sprite.z_index = 1
	player.add_child(held_weapon_sprite)

func _create_cheat_button() -> void:
	cheat_button = Button.new()
	cheat_button.text = "VIE INFINIE · OFF"
	cheat_button.position = Vector2(744.0, 12.0)
	cheat_button.custom_minimum_size = Vector2(204.0, 34.0)
	cheat_button.visible = false
	cheat_button.pressed.connect(_toggle_infinite_life)
	layer.add_child(cheat_button)

func _toggle_infinite_life() -> void:
	if state != "playing":
		return
	cheat_infinite_life = not cheat_infinite_life
	_update_cheat_button()
	_save_checkpoint(wave)

func _update_cheat_button() -> void:
	if is_instance_valid(cheat_button):
		cheat_button.text = "VIE INFINIE · %s" % ("ON" if cheat_infinite_life else "OFF")

func _update_player_visuals() -> void:
	var avatar := player.get_node_or_null("Sprite2D") as Sprite2D
	if is_instance_valid(avatar):
		avatar.texture = load("res://assets/%s.svg" % ("sentinel" if hero_id == "sentinel" else "hero"))
		var blinking := player.invulnerability > 0.0 and int(Time.get_ticks_msec() / 70) % 2 == 1
		avatar.modulate = Color(1.0, 1.0, 1.0, 0.55) if blinking else Color.WHITE
	if not is_instance_valid(held_weapon_sprite):
		return
	var weapon_path := "res://assets/held-weapons/%s.svg" % weapon_id
	if held_weapon_sprite.texture == null or held_weapon_sprite.texture.resource_path != weapon_path:
		held_weapon_sprite.texture = load(weapon_path)
	if held_weapon_sprite.texture:
		var size := held_weapon_sprite.texture.get_size()
		held_weapon_sprite.scale = Vector2(42.0 / size.x, 18.0 / size.y)
	var weapon_sprite_scale := held_weapon_sprite.scale
	held_weapon_sprite.visible = state == "playing"
	if state != "playing":
		return
	var forward := player.facing.normalized()
	var sprite_position := forward * 7.0
	var sprite_rotation := player.facing.angle()
	var attack_timer := float(weapon_attack_timers.get(weapon_id, 0.0))
	if attack_timer > 0.0:
		var definition: Dictionary = catalog.content.weapons[weapon_id]
		var owned := _owned_weapon(weapon_id)
		var synergy := _synergy_data(weapon_id)
		var frequency := maxf(0.1, float(definition.speed) * attack_speed_multiplier * equipment_speed * (1.0 + 0.08 * (int(owned.get("level", 1)) - 1)) * float(synergy.get("attackSpeedMultiplier", 1.0)) * (1.2 if bool(owned.get("special", false)) else 1.0))
		var attack_duration := 0.26 / frequency
		var progress := clampf(1.0 - attack_timer / attack_duration, 0.0, 1.0)
		var recovery := 1.0 - clampf(progress / 0.32, 0.0, 1.0)
		match weapon_id:
			"sabre":
				var swing_direction := 1.0 if int(weapon_swing_counts.get(weapon_id, 0)) % 2 == 1 else -1.0
				sprite_rotation += swing_direction * (-1.3 + 2.6 * progress)
			"marteau": sprite_rotation += 1.25 * recovery
			"dagues": sprite_position += forward * 12.0 * recovery
			"arc":
				sprite_rotation -= 0.1 * recovery
				weapon_sprite_scale.y *= 1.0 + 0.25 * recovery
			"foudre": sprite_rotation -= 0.18 * recovery
			"bombe":
				sprite_position += forward * 7.0 * recovery
				sprite_rotation += sin(progress * PI) * 0.12
	held_weapon_sprite.position = sprite_position
	held_weapon_sprite.rotation = sprite_rotation
	held_weapon_sprite.scale = weapon_sprite_scale

func _play_tone(frequency: float, duration := 0.08, waveform := "sine") -> void:
	if bool(profile.muted) or float(profile.volume) <= 0.0 or not is_instance_valid(audio_player):
		return
	if sound_playback == null:
		return
	var frames := mini(int(duration * sound_generator.mix_rate), sound_playback.get_frames_available())
	for _frame in frames:
		var phase := fposmod(sound_phase, 1.0)
		var sample := sin(TAU * phase)
		if waveform == "square":
			sample = 1.0 if phase < 0.5 else -1.0
		elif waveform == "triangle":
			sample = 1.0 - 4.0 * absf(phase - 0.5)
		sample *= float(profile.volume) * 0.16
		sound_playback.push_frame(Vector2(sample, sample))
		sound_phase += frequency / sound_generator.mix_rate

func _update_drop_filter_controls() -> void:
	if is_instance_valid(weapon_drop_menu):
		weapon_drop_menu.disabled = not custom_drops
	if is_instance_valid(relic_drop_menu):
		relic_drop_menu.disabled = not custom_drops

func _refresh_drop_popup_checks() -> void:
	if is_instance_valid(weapon_drop_menu):
		var popup := weapon_drop_menu.get_popup()
		for index in popup.item_count:
			popup.set_item_checked(index, selected_drop_weapons.has(str(popup.get_item_metadata(index))))
	if is_instance_valid(relic_drop_menu):
		var popup := relic_drop_menu.get_popup()
		for index in popup.item_count:
			popup.set_item_checked(index, selected_drop_relics.has(str(popup.get_item_metadata(index))))

func _on_start_pressed() -> void:
	if state == "paused":
		_set_state("playing")
		return
	if state == "playing":
		return
	var checkpoint: Variant = profile.get("run")
	if checkpoint is Dictionary:
		var saved_player: Dictionary = checkpoint.get("player", {})
		hero_id = str(saved_player.get("hero", "pilgrim"))
		weapon_id = str(saved_player.get("weapon", "sabre"))
		mode = str(checkpoint.get("mode", "waves"))
		difficulty_id = str(checkpoint.get("difficulty", "insane"))
		single_weapon = bool(checkpoint.get("singleWeapon", profile.singleWeapon))
		uncapped_inventory = bool(checkpoint.get("uncappedInventory", profile.uncappedInventory))
		custom_drops = bool(checkpoint.get("customDrops", profile.customDrops))
		selected_drop_weapons.assign(checkpoint.get("dropWeapons", profile.dropWeapons))
		selected_drop_relics.assign(checkpoint.get("dropRelics", profile.dropRelics))
		profile.singleWeapon = single_weapon
		profile.uncappedInventory = uncapped_inventory
		profile.customDrops = custom_drops
		profile.dropWeapons = selected_drop_weapons.duplicate()
		profile.dropRelics = selected_drop_relics.duplicate()
		single_weapon_toggle.set_pressed_no_signal(single_weapon)
		uncapped_inventory_toggle.set_pressed_no_signal(uncapped_inventory)
		custom_drops_toggle.set_pressed_no_signal(custom_drops)
		auto_pick_toggle.set_pressed_no_signal(bool(profile.get("autoPickUpgrade", true)))
		_refresh_drop_popup_checks()
		_update_drop_filter_controls()
		hero_picker.select(1 if hero_id == "sentinel" else 0)
		mode_picker.select(1 if mode == "infinite" else 0)
		difficulty_picker.select(["insane", "nightmare", "cataclysm"].find(difficulty_id))
		for index in weapon_picker.item_count:
			if str(weapon_picker.get_item_metadata(index)) == weapon_id:
				weapon_picker.select(index)
				break
		_start_run(checkpoint)
		return
	hero_id = "sentinel" if hero_picker.selected == 1 else "pilgrim"
	mode = "infinite" if mode_picker.selected == 1 else "waves"
	difficulty_id = ["insane", "nightmare", "cataclysm"][difficulty_picker.selected]
	weapon_id = str(weapon_picker.get_item_metadata(weapon_picker.selected))
	_start_run()

func _on_new_run_pressed() -> void:
	profile.run = null
	hero_id = str(profile.hero)
	weapon_id = str(profile.weapon)
	mode = str(profile.mode)
	difficulty_id = str(profile.difficulty)
	hero_picker.select(1 if hero_id == "sentinel" else 0)
	mode_picker.select(1 if mode == "infinite" else 0)
	difficulty_picker.select(["insane", "nightmare", "cataclysm"].find(difficulty_id))
	for index in weapon_picker.item_count:
		if str(weapon_picker.get_item_metadata(index)) == weapon_id:
			weapon_picker.select(index)
			break
	_save_profile()
	_set_state("title")

func _start_run(checkpoint: Dictionary = {}) -> void:
	if is_instance_valid(particle_layer):
		particle_layer.clear()
	if is_instance_valid(combat_effects):
		combat_effects.clear()
	for enemy in enemies:
		enemy.queue_free()
	for drop in drops:
		drop.node.queue_free()
	enemies.clear()
	drops.clear()
	for projectile in projectiles:
		if is_instance_valid(projectile.get("node")):
			projectile.node.queue_free()
	projectiles.clear()
	for effect in weapon_effects:
		var visual: Variant = effect.get("visual")
		if is_instance_valid(visual):
			visual.queue_free()
	weapon_effects.clear()
	for number in damage_numbers:
		if is_instance_valid(number.get("node")):
			number.node.queue_free()
	damage_numbers.clear()
	damage_zones.clear()
	pending_spawns.clear()
	var hero := _find_definition("heroes", hero_id) as HeroDefinition
	max_hp = hero.health
	hp = max_hp
	player.position = WORLD_SIZE * 0.5
	player.run_active = true
	mouse_aim_active = false
	player.move_speed = hero.speed
	player.movement_multiplier = 1.0
	player.equipment_speed = 1.0
	player.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_update_player_visuals()
	player.facing = Vector2.DOWN
	xp = 0.0
	next_xp = 5.0
	level = 1
	defeated = 0
	damage_multiplier = 1.0
	movement_multiplier = 1.0
	defense = 0.0
	pickup_range = 90.0
	weapon_cooldown = 0.0
	spawn_clock = 1.0
	swarm_timer = -1.0
	intermission = 0.0
	contact_cooldown = 0.0
	skill_cooldown = 0.0
	wave = 0
	elapsed = 0.0
	boss_after_wave_id = ""
	base_hp = hero.health
	bonus_max_hp = 0.0
	weapon_inventory = [{"id": weapon_id, "level": 1, "special": false, "locked": false}]
	_mark_discovered("discoveredWeapons", weapon_id)
	relic_inventory.clear()
	weapon_cooldowns.clear()
	weapon_attack_timers.clear()
	equipment_damage = 1.0
	equipment_speed = 1.0
	equipment_range = 0.0
	equipment_defense = 0.0
	equipment_xp = 1.0
	equipment_lifesteal = 0.0
	global_pickup = false
	player_shield = 0.0
	cheat_infinite_life = false
	scythe_souls = 0
	weapon_swing_counts.clear()
	attack_speed_multiplier = 1.0
	range_bonus = 0.0
	projectile_size_multiplier = 1.0
	projectile_speed_multiplier = 1.0
	pickup_range_multiplier = 1.0
	upgrade_ranks = {"damage": 0, "attackSpeed": 0, "range": 0, "projectileSize": 0, "projectileSpeed": 0, "movementSpeed": 0, "health": 0, "defense": 0, "pickupRange": 0}
	pending_upgrades = 0
	run_challenges = [
		{"id": "kills", "label": "Vaincre 50 créatures", "target": 50, "progress": 0, "complete": false},
		{"id": "elites", "label": "Vaincre 5 élites", "target": 5, "progress": 0, "complete": false},
		{"id": "xp", "label": "Ramasser 20 orbes d’XP", "target": 20, "progress": 0, "complete": false},
	]
	result_recorded = false
	if not checkpoint.is_empty():
		var saved_player: Dictionary = checkpoint.get("player", {})
		mode = str(checkpoint.get("mode", mode))
		difficulty_id = str(checkpoint.get("difficulty", difficulty_id))
		xp = float(saved_player.get("xp", 0.0))
		next_xp = float(saved_player.get("nextXp", 5.0))
		level = int(saved_player.get("level", 1))
		defeated = int(checkpoint.get("defeated", 0))
		damage_multiplier = float(saved_player.get("damageMultiplier", 1.0))
		attack_speed_multiplier = float(saved_player.get("attackSpeedMultiplier", 1.0))
		range_bonus = float(saved_player.get("rangeBonus", 0.0))
		movement_multiplier = float(saved_player.get("movementMultiplier", 1.0))
		defense = float(saved_player.get("defense", 0.0))
		bonus_max_hp = float(saved_player.get("bonusMaxHp", 0.0))
		projectile_size_multiplier = float(saved_player.get("projectileSize", 1.0))
		projectile_speed_multiplier = float(saved_player.get("projectileSpeed", 1.0))
		pickup_range_multiplier = float(saved_player.get("pickupRangeMultiplier", 1.0))
		upgrade_ranks = _normalize_upgrade_ranks(saved_player)
		weapon_inventory = saved_player.get("weaponInventory", weapon_inventory).duplicate(true)
		relic_inventory = saved_player.get("inventory", []).duplicate(true)
		if not uncapped_inventory:
			weapon_inventory.resize(mini(weapon_inventory.size(), int(catalog.content.config.drops.maxWeapons)))
			relic_inventory.resize(mini(relic_inventory.size(), int(catalog.content.config.drops.maxRelics)))
		for item in weapon_inventory:
			_mark_discovered("discoveredWeapons", str(item.id))
		for item in relic_inventory:
			_mark_discovered("discoveredRelics", str(item.id))
		player_shield = float(saved_player.get("shield", 0.0))
		cheat_infinite_life = bool(saved_player.get("cheatInfiniteLife", false))
		scythe_souls = int(saved_player.get("scytheSouls", 0))
		var saved_position: Array = saved_player.get("position", [WORLD_SIZE.x * 0.5, WORLD_SIZE.y * 0.5])
		player.position = Vector2(float(saved_position[0]), float(saved_position[1]))
		var saved_facing: Array = saved_player.get("facing", [0.0, 1.0])
		player.facing = Vector2(float(saved_facing[0]), float(saved_facing[1])).normalized()
		elapsed = float(checkpoint.get("elapsedSeconds", 0))
		var saved_challenges: Variant = checkpoint.get("runChallenges", [])
		if saved_challenges is Array:
			run_challenges = saved_challenges.duplicate(true)
		var saved_objective: Variant = checkpoint.get("waveObjective", {})
		if saved_objective is Dictionary:
			objective_type = str(saved_objective.get("type", objective_type))
			objective_target = int(saved_objective.get("target", objective_target))
			objective_progress = int(saved_objective.get("progress", 0))
			objective_complete = bool(saved_objective.get("complete", false))
		_refresh_relic_stats()
		hp = float(saved_player.get("hp", max_hp))
		max_hp = maxf(max_hp, float(saved_player.get("maxHp", max_hp)))
		hp = minf(hp, max_hp)
		player.movement_multiplier = movement_multiplier
		player.equipment_speed = equipment_speed
		player.position = Vector2(float(saved_position[0]), float(saved_position[1]))
	rng.randomize()
	_start_wave(int(checkpoint.get("wave", 1)))
	_set_state("playing")

func _start_wave(number: int) -> void:
	wave = number
	objective_type = ["kills", "xp", "elite"][(number - 1) % 3]
	objective_target = [12, 8, 1][(number - 1) % 3]
	objective_progress = 0
	objective_complete = false
	if mode == "infinite" and number > 4:
		wave_groups = [
			{"kind": "ghoul", "count": 35 + number * 6},
			{"kind": "brute", "count": 12 + number * 3},
			{"kind": "caster", "count": mini(2 + int(number / 2), 9)},
			{"kind": "stalker", "count": mini(4 + number, 15)},
			{"kind": "charger", "count": mini(2 + number, 12)},
			{"kind": "shaman", "count": mini(1 + int(number / 2), 7)},
			{"kind": "leech", "count": mini(4 + number * 2, 32)},
			{"kind": "leaper", "count": mini(3 + number, 18)},
		]
	else:
		wave_groups = (catalog.content.waves[number - 1] if number <= catalog.content.waves.size() else []).duplicate(true)
	boss_after_wave_id = ["guardian", "matriarch", "colossus"][(int(number / 5) - 1) % 3] if mode == "infinite" and number % 5 == 0 else ""
	pending_spawns.clear()
	for entry in wave_groups:
		var count := int(entry.get("count", 1))
		for spawn_index in count:
			pending_spawns.append({"kind": str(entry.kind), "elite": entry.kind != "boss" and (spawn_index + 1) % (18 if mode == "infinite" else 24) == 0, "boss_id": entry.get("boss_id", "guardian")})
	spawn_clock = 1.0 if number == 1 else 0.62
	swarm_timer = rng.randf_range(14.0, 26.0) if rng.randf() < 0.38 else -1.0
	intermission = 0.0
	status_label.text = "Vague %d" % number
	_save_checkpoint(number)

func _save_checkpoint(number: int) -> void:
	var saved_player := {
		"hero": hero_id,
		"weapon": weapon_id,
		"hp": hp,
		"maxHp": max_hp,
		"xp": xp,
		"nextXp": next_xp,
		"level": level,
		"damageMultiplier": damage_multiplier,
		"attackSpeedMultiplier": attack_speed_multiplier,
		"rangeBonus": range_bonus,
		"movementMultiplier": movement_multiplier,
		"defense": defense,
		"bonusMaxHp": bonus_max_hp,
		"projectileSize": projectile_size_multiplier,
		"projectileSpeed": projectile_speed_multiplier,
		"pickupRangeMultiplier": pickup_range_multiplier,
		"upgradeRanks": upgrade_ranks.duplicate(true),
		"weaponInventory": weapon_inventory.duplicate(true),
		"inventory": relic_inventory.duplicate(true),
		"shield": player_shield,
		"cheatInfiniteLife": cheat_infinite_life,
		"scytheSouls": scythe_souls,
		"position": [player.position.x, player.position.y],
		"facing": [player.facing.x, player.facing.y],
	}
	profile.run = {
		"version": 1,
		"mode": mode,
		"difficulty": difficulty_id,
		"singleWeapon": single_weapon,
		"uncappedInventory": uncapped_inventory,
		"customDrops": custom_drops,
		"dropWeapons": selected_drop_weapons.duplicate(),
		"dropRelics": selected_drop_relics.duplicate(),
		"wave": number,
		"waveObjective": {"type": objective_type, "target": objective_target, "progress": objective_progress, "complete": objective_complete},
		"player": saved_player,
		"defeated": defeated,
		"runChallenges": run_challenges.duplicate(true),
		"elapsedSeconds": int(elapsed),
	}
	_save_profile()

func _update_spawns(delta: float) -> void:
	if swarm_timer > 0.0:
		swarm_timer -= delta
		if swarm_timer <= 0.0:
			var swarm_count := mini(62, 26 + mini(wave, 18) * 2)
			var swarm: Array[Dictionary] = []
			for _index in swarm_count:
				var total_weight := 0
				for group in wave_groups:
					total_weight += mini(int(group.get("count", 1)), 12)
				var selected_weight := rng.randi_range(1, max(1, total_weight))
				var kind := "ghoul"
				for group in wave_groups:
					selected_weight -= mini(int(group.get("count", 1)), 12)
					if selected_weight <= 0:
						kind = str(group.kind)
						break
				swarm.append({"kind": kind, "elite": false, "swarm": true, "boss_id": "guardian"})
			swarm.append_array(pending_spawns)
			pending_spawns = swarm
			spawn_clock = 0.0
			swarm_timer = -1.0
	if pending_spawns.is_empty() and enemies.is_empty():
		if not boss_after_wave_id.is_empty():
			var next_boss := boss_after_wave_id
			boss_after_wave_id = ""
			_spawn_enemy("boss", false, next_boss)
			return
		if mode == "infinite" or wave < catalog.content.waves.size():
			intermission = 3.0
			return
		if not enemies.any(func(enemy: ValombreEnemy) -> bool: return enemy.kind == "boss"):
			_spawn_enemy("boss", false, "guardian")
		return
	if pending_spawns.is_empty():
		return
	spawn_clock -= delta
	var difficulty: Dictionary = catalog.content.difficulties[difficulty_id]
	var capacity := 10.0 * float(difficulty.spawnCapacity)
	if mode == "infinite":
		capacity = minf(200.0, 10.0 + floorf(elapsed / 60.0 * 24.0)) * float(difficulty.spawnCapacity)
	var occupied := 0.0
	for enemy in enemies:
		occupied += float(enemy.get_meta("spawn_weight", 1.0))
	var pending_index := -1
	for index in pending_spawns.size():
		var weight := 10.0 if pending_spawns[index].kind == "boss" else float(catalog.content.config.enemies.get(pending_spawns[index].kind, {}).get("weight", 1.0))
		if occupied + weight <= capacity:
			pending_index = index
			break
	if spawn_clock <= 0.0 and pending_index >= 0:
		var spawn := pending_spawns.pop_at(pending_index)
		_spawn_enemy(str(spawn.kind), bool(spawn.get("elite", false)), str(spawn.get("boss_id", "guardian")))
		spawn_clock = 0.12 if spawn.get("swarm", false) else maxf(0.12, 0.62 * pow(0.7, elapsed / 60.0)) if mode == "infinite" else 0.62

func _spawn_enemy(kind: String, is_elite: bool, boss_id: String) -> void:
	var base: Dictionary
	if kind == "boss":
		base = catalog.content.bosses.get(boss_id, catalog.content.bosses.guardian).duplicate(true)
	else:
		base = catalog.content.config.enemies[kind].duplicate(true)
		base.merge(catalog.content.bestiary.get(kind, {}), true)
	var progress := maxf(0.0, wave - 1.0)
	var difficulty: Dictionary = catalog.content.difficulties[difficulty_id]
	var elite_id := ""
	var elite_stats: Dictionary = {}
	if is_elite:
		var elite_ids: Array = catalog.content.eliteAffixes.keys()
		elite_id = str(elite_ids[rng.randi_range(0, elite_ids.size() - 1)])
		elite_stats = catalog.content.eliteAffixes[elite_id]
	var infinite_health := pow(1.28, progress) if mode == "infinite" else 1.0
	var infinite_damage := pow(1.22, progress) if mode == "infinite" else 1.0
	var enemy_stats := base.duplicate(true)
	enemy_stats.health = roundi(float(base.get("health", 34)) * infinite_health * float(difficulty.health) * float(elite_stats.get("health", 1.0)))
	enemy_stats.speed = float(base.get("speed", 74)) * (1.0 + minf(1.2, progress * 0.035) if mode == "infinite" else 1.0) * float(difficulty.speed) * float(elite_stats.get("speed", 1.0))
	enemy_stats.damage = roundi(float(base.get("damage", 9)) * infinite_damage * float(difficulty.damage) * float(elite_stats.get("damage", 1.0)))
	enemy_stats.radius = float(base.get("radius", 33 if kind == "boss" else 14))
	if kind == "boss":
		enemy_stats.sprite = "boss" if boss_id == "guardian" else boss_id
	var enemy := ENEMY_SCRIPT.new() as ValombreEnemy
	enemy.configure(kind, enemy_stats, is_elite)
	if kind == "leaper":
		enemy.landing_radius = float(base.get("landingRadius", 54.0))
	elif kind == "charger":
		enemy.telegraph_range = float(base.get("range", 330.0))
	elif kind == "shaman":
		enemy.telegraph_range = float(base.get("range", 270.0))
	if is_elite:
		enemy.elite_id = elite_id
		enemy.elite_name = str(elite_stats.get("name", "Élite"))
		enemy.elite_color = Color(str(elite_stats.get("color", "#e4c978")))
		enemy.update_elite_label()
	enemy.attack_timer = rng.randf_range(0.3, 1.3)
	enemy.heal_on_hit = float(base.get("healOnHit", 0.0))
	if kind == "boss":
		enemy.radius = float(base.get("radius", 33))
		enemy.damage = roundf(float(base.get("slamDamage", 26)) * float(difficulty.damage) * infinite_damage)
		enemy.projectile_damage = float(base.get("projectileDamage", enemy.damage)) * float(difficulty.damage) * infinite_damage
		enemy.boss_id = boss_id
		enemy.boss_behavior = str(base.get("behavior", "guardian"))
		enemy.attack_mode = "volley" if enemy.boss_behavior == "volley" else "slam"
		enemy.boss_slam_radius = float(base.get("slamRadius", 138.0))
		enemy.boss_charge_distance = float(base.get("chargeDistance", 250.0))
		enemy.boss_dash_distance = float(base.get("dashDistance", 320.0))
		enemy.boss_dash_stop_distance = float(base.get("dashStopDistance", 75.0))
		enemy.boss_dash_width = float(base.get("dashWidth", 44.0))
		enemy.boss_charge_width = float(base.get("chargeWidth", 38.0))
		enemy.approach_cooldown = rng.randf_range(0.8, 2.0)
		enemy.set_meta("boss_id", boss_id)
		enemy.set_meta("display_name", str(base.get("name", boss_id)))
		enemy.set_meta("spawn_weight", float(base.get("weight", 10)))
	else:
		enemy.set_meta("spawn_weight", float(base.get("weight", 1)) + (1.0 if is_elite else 0.0))
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(350.0, 540.0)
	enemy.position = Vector2(
		clampf(player.position.x + cos(angle) * distance, 60.0, WORLD_SIZE.x - 60.0),
		clampf(player.position.y + sin(angle) * distance, 60.0, WORLD_SIZE.y - 60.0)
	)
	if kind == "boss":
		enemy.name = "Boss_" + boss_id
	arena.add_child(enemy)
	enemies.append(enemy)

func _update_enemies(delta: float) -> void:
	var to_remove: Array[ValombreEnemy] = []
	var attack_speed := float(catalog.content.difficulties[difficulty_id].attackSpeed)
	for enemy in enemies:
		if not is_instance_valid(enemy):
			to_remove.append(enemy)
			continue
		enemy.hit_flash = maxf(0.0, enemy.hit_flash - delta)
		var dagger_bleed: Variant = enemy.get_meta("dagger_bleed", null)
		if dagger_bleed is Dictionary:
			dagger_bleed.remaining = float(dagger_bleed.remaining) - delta
			dagger_bleed.tick = float(dagger_bleed.tick) - delta
			if float(dagger_bleed.tick) <= 0.0:
				_damage_enemy(enemy, float(dagger_bleed.damage), "dagues")
				dagger_bleed.tick = float(dagger_bleed.tick) + 0.45
			if not enemies.has(enemy):
				to_remove.append(enemy)
				continue
			if float(dagger_bleed.remaining) <= 0.0:
				enemy.remove_meta("dagger_bleed")
			else:
				enemy.set_meta("dagger_bleed", dagger_bleed)
		enemy.slow_time = maxf(0.0, enemy.slow_time - delta)
		if enemy.slow_time <= 0.0:
			enemy.slow_factor = 1.0
		enemy.visual_phase += delta * 3.0
		enemy.queue_redraw()
		enemy.attack_timer -= delta * attack_speed
		if enemy.dash_time_left > 0.0:
			_advance_enemy_dash(enemy, delta)
			if state != "playing":
				break
			continue
		var to_player := player.position - enemy.position
		var camera_center := player.get_node("Camera2D").get_screen_center_position()
		var visible_rect := Rect2(camera_center - Vector2(480.0, 270.0), Vector2(960.0, 540.0))
		if visible_rect.has_point(enemy.position):
			_discover_bestiary("boss:%s" % enemy.boss_id if enemy.kind == "boss" else enemy.kind, enemy.elite_id if enemy.elite else "")
		var distance := maxf(to_player.length(), 0.001)
		var direction := to_player / distance
		if enemy.kind == "boss":
			_update_boss(enemy, delta, attack_speed, to_player, distance, direction)
		elif enemy.kind == "charger":
			_update_charger(enemy, delta, attack_speed, distance, direction)
		elif enemy.kind == "leaper":
			_update_leaper(enemy, delta, attack_speed, distance, direction)
		elif enemy.kind == "caster" or enemy.kind == "shaman":
			_update_caster(enemy, delta, attack_speed, distance, direction)
		else:
			_update_contact_enemy(enemy, delta, direction)
		if state != "playing":
			break
	for enemy in to_remove:
		enemies.erase(enemy)

func _update_contact_enemy(enemy: ValombreEnemy, delta: float, direction: Vector2) -> void:
	var reach := enemy.radius + 24.0
	if enemy.position.distance_to(player.position) > reach:
		_move_enemy_around_obstacles(enemy, direction * enemy.speed * enemy.slow_factor * delta)
		return
	if enemy.attack_timer <= 0.0:
		enemy.attack_timer = float(catalog.content.config.enemies.attackCooldown)
		var was_hit := _damage_player(enemy.damage)
		if was_hit and enemy.heal_on_hit > 0.0 and hp > 0.0:
			enemy.hp = minf(enemy.max_hp, enemy.hp + enemy.heal_on_hit)

func _update_charger(enemy: ValombreEnemy, delta: float, attack_speed: float, distance: float, direction: Vector2) -> void:
	var spec: Dictionary = catalog.content.config.enemies.charger
	if enemy.telegraph > 0.0:
		enemy.telegraph = maxf(0.0, enemy.telegraph - delta * attack_speed)
		if enemy.telegraph <= 0.0:
			var dash := enemy.aim_position - enemy.position
			var dash_length := maxf(dash.length(), 0.001)
			var along := (player.position - enemy.position).dot(dash / dash_length)
			var across := absf((player.position - enemy.position).cross(dash / dash_length))
			if along > 0.0 and along < float(spec.range) and across < 30.0 and player.invulnerability <= 0.0:
				_damage_player(enemy.damage)
			var amount := float(spec.chargeSpeed) * float(catalog.content.difficulties[difficulty_id].speed) * 0.45
			_move_enemy_around_obstacles(enemy, (dash / dash_length) * amount)
			enemy.attack_timer = float(spec.attackCooldown)
	elif enemy.attack_timer <= 0.0 and distance < float(spec.range):
		enemy.aim_position = player.position
		enemy.telegraph = float(spec.windup)
	else:
		_move_enemy_around_obstacles(enemy, direction * enemy.speed * enemy.slow_factor * delta)

func _update_leaper(enemy: ValombreEnemy, delta: float, attack_speed: float, distance: float, direction: Vector2) -> void:
	var spec: Dictionary = catalog.content.config.enemies.leaper
	if enemy.telegraph > 0.0:
		enemy.telegraph = maxf(0.0, enemy.telegraph - delta * attack_speed)
		if enemy.telegraph <= 0.0:
			var leap := enemy.aim_position - enemy.position
			enemy.dash_direction = leap.normalized()
			enemy.dash_distance_left = leap.length()
			enemy.dash_time_left = 0.24
			enemy.dash_damage = enemy.damage
			enemy.dash_width = float(spec.landingRadius)
			enemy.dash_hit = false
			enemy.dash_landing_damage = true
			enemy.dash_sets_recovery = false
			enemy.attack_timer = float(spec.attackCooldown)
		return
	if enemy.attack_timer <= 0.0 and distance < float(spec.leapRange):
		enemy.aim_position = player.position
		enemy.telegraph = float(spec.windup)
	elif distance > enemy.radius + 24.0:
		_move_enemy_around_obstacles(enemy, direction * enemy.speed * enemy.slow_factor * delta)

func _update_caster(enemy: ValombreEnemy, delta: float, attack_speed: float, distance: float, direction: Vector2) -> void:
	var spec: Dictionary = catalog.content.config.enemies[enemy.kind]
	if distance < float(spec.range) * 0.72:
		_move_enemy_around_obstacles(enemy, -direction * enemy.speed * enemy.slow_factor * delta)
	elif distance > float(spec.range):
		_move_enemy_around_obstacles(enemy, direction * enemy.speed * enemy.slow_factor * delta)
	if enemy.telegraph > 0.0:
		enemy.telegraph = maxf(0.0, enemy.telegraph - delta * attack_speed)
		if enemy.telegraph <= 0.0:
			var count := 3 if enemy.kind == "shaman" else 1
			_fire_enemy_fan(enemy, count, 0.24, float(spec.projectileSpeed), enemy.damage, 2.0, "#bd79ce" if count == 3 else "#d7bb8d", 8.0 if enemy.kind == "shaman" else 7.0)
			enemy.attack_timer = float(spec.attackCooldown)
	elif enemy.attack_timer <= 0.0 and distance < float(spec.range) + 115.0:
		enemy.aim_position = player.position
		enemy.telegraph = float(spec.windup)

func _update_boss(enemy: ValombreEnemy, delta: float, attack_speed: float, to_player: Vector2, distance: float, direction: Vector2) -> void:
	var spec: Dictionary = catalog.content.bosses[enemy.boss_id]
	if enemy.approach_telegraph > 0.0:
		enemy.approach_telegraph = maxf(0.0, enemy.approach_telegraph - delta * attack_speed)
		if enemy.approach_telegraph <= 0.0:
			var approach_distance := minf(float(spec.dashDistance), maxf(0.0, distance - float(spec.dashStopDistance)))
			enemy.dash_direction = direction
			enemy.dash_distance_left = approach_distance
			enemy.dash_time_left = float(spec.dashDuration)
			enemy.dash_damage = roundf(float(spec.chargeDamage) * float(catalog.content.difficulties[difficulty_id].damage) * (pow(1.22, maxf(0.0, wave - 1.0)) if mode == "infinite" else 1.0))
			enemy.dash_width = float(spec.dashWidth)
			enemy.dash_hit = false
			enemy.dash_landing_damage = false
			enemy.dash_sets_recovery = true
			enemy.dash_is_approach = true
		return
	enemy.approach_cooldown -= delta * attack_speed
	if distance > float(spec.approachRange) and enemy.approach_cooldown <= 0.0 and enemy.telegraph <= 0.0:
		enemy.aim_position = player.position
		enemy.approach_telegraph = float(spec.dashWindup)
		return
	if enemy.boss_behavior == "volley":
		if distance < 210.0:
			_move_enemy_around_obstacles(enemy, -direction * enemy.speed * enemy.slow_factor * delta)
		elif distance > 330.0:
			_move_enemy_around_obstacles(enemy, direction * enemy.speed * enemy.slow_factor * delta)
		if enemy.telegraph > 0.0:
			enemy.telegraph = maxf(0.0, enemy.telegraph - delta * attack_speed)
			if enemy.telegraph <= 0.0:
				_fire_enemy_fan(enemy, 5, 0.2, float(spec.projectileSpeed), enemy.projectile_damage, 3.0, "#a8d978", 10.0)
				enemy.attack_timer = float(spec.cooldown)
		elif enemy.attack_timer <= 0.0:
			enemy.aim_position = player.position
			enemy.telegraph = float(spec.telegraph)
		return
	if enemy.telegraph > 0.0:
		enemy.telegraph = maxf(0.0, enemy.telegraph - delta * attack_speed)
		if enemy.telegraph <= 0.0:
			if enemy.attack_mode == "slam":
				if distance < float(spec.slamRadius) and player.invulnerability <= 0.0:
					_damage_player(enemy.damage)
			else:
				var vector := enemy.aim_position - enemy.position
				var dash_distance := minf(float(spec.chargeDistance), maxf(0.0, vector.length() - float(spec.dashStopDistance)))
				enemy.dash_direction = vector.normalized() if vector.length_squared() > 0.0 else direction
				enemy.dash_distance_left = dash_distance
				enemy.dash_time_left = float(spec.dashDuration)
				enemy.dash_damage = roundf(float(spec.chargeDamage) * float(catalog.content.difficulties[difficulty_id].damage) * (pow(1.22, maxf(0.0, wave - 1.0)) if mode == "infinite" else 1.0))
				enemy.dash_width = float(spec.chargeWidth)
				enemy.dash_hit = false
				enemy.dash_landing_damage = false
				enemy.dash_sets_recovery = true
				enemy.dash_is_approach = false
			enemy.attack_timer = float(spec.cooldown)
			enemy.attack_mode = "charge" if enemy.attack_mode == "slam" else "slam"
	elif enemy.attack_timer <= 0.0:
		enemy.aim_position = player.position
		enemy.telegraph = float(spec.telegraph)
	elif distance > enemy.radius + 85.0:
		_move_enemy_around_obstacles(enemy, direction * enemy.speed * enemy.slow_factor * delta)

func _fire_enemy_fan(enemy: ValombreEnemy, count: int, spread: float, speed: float, damage: float, lifetime: float, tint: String, projectile_radius: float = 7.0) -> void:
	var base_angle := (enemy.aim_position - enemy.position).angle()
	var difficulty: Dictionary = catalog.content.difficulties[difficulty_id]
	for shot in count:
		var angle := base_angle + (float(shot) - float(count - 1) * 0.5) * spread
		var direction := Vector2(cos(angle), sin(angle))
		var visual := ValombreProjectileVisual.new()
		visual.radius = projectile_radius
		visual.tint = Color(tint)
		visual.rotation = angle
		visual.position = enemy.position
		arena.add_child(visual)
		projectiles.append({"node": visual, "team": "enemy", "velocity": direction * speed * float(difficulty.projectileSpeed), "damage": damage, "radius": projectile_radius, "life": lifetime, "source": enemy.kind})

func _advance_enemy_dash(enemy: ValombreEnemy, delta: float) -> void:
	var step_length := minf(enemy.dash_distance_left, enemy.dash_distance_left * delta / maxf(enemy.dash_time_left, delta))
	var start := enemy.position
	var step := enemy.dash_direction * step_length
	_move_enemy_around_obstacles(enemy, step)
	var finish := enemy.position
	if not enemy.dash_landing_damage and not enemy.dash_hit and player.invulnerability <= 0.0 and _distance_to_segment(player.position, start, finish) < enemy.dash_width + 12.0:
		_damage_player(enemy.dash_damage)
		enemy.dash_hit = true
	enemy.dash_distance_left = maxf(0.0, enemy.dash_distance_left - step_length)
	enemy.dash_time_left = maxf(0.0, enemy.dash_time_left - delta)
	if enemy.dash_time_left <= 0.0 or enemy.dash_distance_left <= 0.0:
		if enemy.dash_landing_damage:
			if player.invulnerability <= 0.0 and player.position.distance_to(enemy.position) < enemy.dash_width:
				_damage_player(enemy.dash_damage)
			_spawn_burst(enemy.position, Color("e7a35c"), 8)
		enemy.dash_landing_damage = false
		if enemy.dash_sets_recovery:
			enemy.attack_timer = maxf(enemy.attack_timer, 0.65)
		if enemy.dash_is_approach:
			enemy.approach_cooldown = float(catalog.content.bosses[enemy.boss_id].dashCooldown)
			enemy.dash_is_approach = false

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0) if length_squared > 0.0 else 0.0
	return point.distance_to(start + segment * t)

func _move_enemy_around_obstacles(enemy: ValombreEnemy, step: Vector2) -> void:
	var candidate := enemy.position + step
	if _position_blocked(candidate, enemy.radius):
		candidate = enemy.position + Vector2(step.x, 0.0)
		if _position_blocked(candidate, enemy.radius):
			candidate = enemy.position + Vector2(0.0, step.y)
	if not _position_blocked(candidate, enemy.radius):
		enemy.position = candidate

func _position_blocked(position: Vector2, radius: float) -> bool:
	if position.x < 35.0 + radius or position.y < 35.0 + radius or position.x > WORLD_SIZE.x - 35.0 - radius or position.y > WORLD_SIZE.y - 35.0 - radius:
		return true
	for obstacle in OBSTACLES:
		if position.distance_to(Vector2(obstacle.x, obstacle.y)) < obstacle.z + radius:
			return true
	return false

func _update_auto_attack() -> void:
	for owned in weapon_inventory:
		if state != "playing":
			break
		var id := str(owned.id)
		var weapon: Dictionary = catalog.content.weapons[id]
		var ranged := bool(weapon.get("ranged", false))
		var target: ValombreEnemy
		var nearest := INF
		for enemy in enemies:
			var distance := player.position.distance_to(enemy.position)
			if distance < nearest:
				nearest = distance
				target = enemy
		var manual := Input.is_action_pressed("attack")
		var manual_melee := manual and not ranged
		var swing_count := int(weapon_swing_counts.get(id, 0)) + 1
		var special_finisher := bool(owned.special) and swing_count % 3 == 0
		var level_scale := 1.0 + 0.18 * (int(owned.level) - 1)
		var reach := (float(weapon.get("range", 108.0)) + range_bonus + equipment_range) * float(_synergy_data(id).get("rangeMultiplier", 1.0))
		if ((not target or nearest > reach) and not manual_melee) or (float(weapon_cooldowns.get(id, 0.0)) > 0.0 and not manual):
			continue
		var aim := player.facing
		if manual and mouse_aim_active:
			var mouse_direction := player.get_global_mouse_position() - player.global_position
			if mouse_direction.length() > 5.0:
				aim = mouse_direction.normalized()
		elif target:
			aim = (target.position - player.position).normalized()
		if aim != Vector2.ZERO:
			player.facing = aim
		var synergy := _synergy_data(id)
		var damage_scale := damage_multiplier * equipment_damage * level_scale * float(synergy.get("damageMultiplier", 1.0)) * (1.5 if bool(owned.special) else 1.0) * (1.0 + (level - 1) * 0.005)
		var frequency := maxf(0.1, float(weapon.speed) * attack_speed_multiplier * equipment_speed * (1.0 + 0.08 * (int(owned.level) - 1)) * float(synergy.get("attackSpeedMultiplier", 1.0)) * (1.2 if bool(owned.special) else 1.0))
		weapon_cooldowns[id] = 0.26 / frequency
		weapon_attack_timers[id] = 0.26 / frequency
		if ranged:
			_launch_projectile(weapon, target, damage_scale, id)
			continue
		_play_tone(155.0, 0.045, "triangle")
		weapon_swing_counts[id] = swing_count
		var attack_hit := false
		for enemy in enemies.duplicate():
			var offset := enemy.position - player.position
			var distance := offset.length()
			var in_shape := false
			if bool(weapon.get("circular", false)):
				in_shape = distance < reach
			elif bool(weapon.get("piercing", false)):
				var along := clampf(offset.dot(player.facing), 0.0, reach)
				var closest := player.position + player.facing * along
				in_shape = enemy.position.distance_to(closest) < 18.0 + enemy.radius + (8.0 if id == "lance" and special_finisher else 0.0)
			else:
				var alignment := offset.normalized().dot(player.facing) if distance > 0.0 else 1.0
				in_shape = distance < reach and alignment > float(weapon.get("arc", -1.0))
			if in_shape:
				attack_hit = true
				var sabre_burst := false
				if id == "sabre" and _synergy_active(id):
					var marks := int(enemy.get_meta("sabre_combo_marks", 0)) + 1
					enemy.set_meta("sabre_combo_marks", marks % 5)
					sabre_burst = marks >= 5
				if id == "lance" and _synergy_active(id):
					player_shield = minf(max_hp * 0.5, player_shield + 8.0)
				var hit_scale := 1.45 if id == "lance" and special_finisher else 1.0
				_damage_enemy(enemy, _weapon_base_damage(weapon, enemy) * damage_scale * hit_scale, id)
				if id == "sabre" and bool(owned.special) and int(weapon_swing_counts[id]) % 3 == 0 and is_instance_valid(enemy):
					enemy.set_meta("sabre_mark", true)
				if id == "dagues" and special_finisher and is_instance_valid(enemy) and enemies.has(enemy):
					enemy.set_meta("dagger_bleed", {"remaining": 1.8, "tick": 0.45, "damage": _weapon_base_damage(weapon, enemy) * damage_scale * 0.24})
				if sabre_burst:
					_add_combat_effect({"kind": "sabre_burst", "position": enemy.position, "radius": 104.0, "life": 0.34, "max_life": 0.34})
					for nearby in enemies.duplicate():
						if nearby.position.distance_to(enemy.position) <= 104.0:
							_damage_enemy(nearby, _weapon_base_damage(weapon, nearby) * damage_scale * 1.35, id)
				if state != "playing":
					break
		if attack_hit:
			var tint := Color("e99b58") if id == "marteau" else Color("bce7a0") if id == "faux" else Color("f0dfa8") if id == "lance" else Color("b4e2cd") if id == "dagues" else Color("e8c57e")
			_spawn_burst(player.position + player.facing * 65.0, tint, 11 if id == "marteau" else 5)
			if id == "dagues" and special_finisher:
				_play_tone(460.0, 0.08, "sawtooth")
				_spawn_burst(player.position + player.facing * 48.0, Color("a9ffe1"), 12)
		if state != "playing":
			break
		if id == "marteau" and bool(owned.special):
			var full_circle := _synergy_active(id)
			weapon_effects.append({"kind": "hammer_wave", "delay": 0.16, "position": player.position, "angle": player.facing.angle(), "arc": float(weapon.get("arc", -1.0)), "outer": reach + 34.0, "full_circle": full_circle, "weapon": id, "damage_scale": damage_scale * (1.05 if full_circle else 0.55)})
			if full_circle:
				_add_combat_effect({"kind": "hammer_wave", "delay": 0.16, "position": player.position, "outer": reach + 34.0, "full_circle": true, "life": 0.3, "max_life": 0.3})
		if id == "faux" and (special_finisher or (_synergy_active(id) and scythe_souls > 0)):
			var released := scythe_souls if _synergy_active(id) else 0
			scythe_souls -= released
			_add_combat_effect({"kind": "scythe_wave", "position": player.position, "radius": reach * 1.08, "souls": released, "life": 0.42, "max_life": 0.42})
			_play_tone(190.0, 0.1, "sawtooth")
			for enemy in enemies.duplicate():
				if enemy.position.distance_to(player.position) <= reach * 1.08:
					_damage_enemy(enemy, float(weapon.ghoulDamage) * damage_scale * (0.32 + released * 0.42), id)

func _weapon_base_damage(weapon: Dictionary, enemy: ValombreEnemy) -> float:
	return float(weapon.get("bruteDamage", 25) if enemy.kind == "brute" else weapon.get("ghoulDamage", 32))

func _launch_projectile(weapon: Dictionary, target: ValombreEnemy, damage_scale: float, id: String) -> void:
	var direction := (target.position - player.position).normalized()
	var owned := _owned_weapon(id)
	var is_special := bool(owned.get("special", false))
	var shot := {
		"direction": direction,
		"speed": 520.0 * projectile_speed_multiplier,
		"radius": 5.0 * projectile_size_multiplier,
		"damage": _weapon_base_damage(weapon, target) * damage_scale,
		"weapon": id,
		"remaining": INF,
		"explosive": bool(weapon.get("explosive", false)),
		"explosion_radius": (44.0 + (float(owned.get("level", 1)) - 1.0) * 9.0) * (1.35 if is_special else 1.0) if bool(weapon.get("explosive", false)) else 0.0,
		"special_blast": is_special and bool(weapon.get("explosive", false)),
		"lightning": bool(weapon.get("lightning", false)),
		"frost": bool(weapon.get("frost", false)),
		"piercing": is_special and id == "arc",
		"storm_special": is_special and bool(weapon.get("lightning", false)),
		"has_special": is_special,
		"slow_duration": 1.25 * float(_synergy_data(id).get("slowDurationMultiplier", 1.0)) * (2.4 / 1.25 if is_special else 1.0),
		"slow_factor": 0.42 if is_special else 0.58,
		"chain_targets": int(owned.get("level", 1)) + (1 if is_special and bool(weapon.get("lightning", false)) else 0),
		"chain_range": 380.0 if id == "foudre" and _synergy_active(id) else 190.0,
		"hit_targets": [],
	}
	var fan := id == "arc" and _synergy_active(id)
	var projectile_tint := Color("c7a8ff") if weapon.get("lightning", false) else Color("91e9ef") if weapon.get("frost", false) else Color("ff9a4e") if weapon.get("explosive", false) else Color("ffe39a") if is_special else Color("85d8ce")
	if is_special and id in ["arc", "foudre"]:
		var charge_visual := Sprite2D.new()
		charge_visual.texture = load("res://assets/xp.svg")
		charge_visual.modulate = Color("c7a8ff") if id == "foudre" else Color("ffe39a")
		charge_visual.scale = Vector2(0.12, 0.12)
		charge_visual.z_index = 3
		arena.add_child(charge_visual)
		weapon_effects.append({"kind": "ranged_charge", "delay": 0.14, "shot": shot, "fan": fan, "visual": charge_visual, "weapon": id})
		return
	if fan:
		var offsets := [-0.2, 0.0, 0.2]
		var damage_scales := [0.72, 1.0, 0.72]
		for index in offsets.size():
			var volley_shot := shot.duplicate(true)
			volley_shot.direction = direction.rotated(float(offsets[index]))
			volley_shot.damage = float(shot.damage) * float(damage_scales[index])
			_spawn_player_projectile(volley_shot)
	else:
		_spawn_player_projectile(shot)
	_spawn_burst(player.position + direction * 12.0, projectile_tint, 7 if is_special else 3)
	_play_tone(510.0, 0.055, "triangle")

func _spawn_player_projectile(projectile: Dictionary) -> void:
	var id := str(projectile.weapon)
	var weapon: Dictionary = catalog.content.weapons[id]
	var visual := ValombreProjectileVisual.new()
	visual.team = "player"
	visual.radius = float(projectile.radius)
	visual.tint = Color("c7a8ff") if weapon.get("lightning", false) else Color("91e9ef") if weapon.get("frost", false) else Color("ff9a4e") if weapon.get("explosive", false) else Color("ffe39a") if bool(projectile.get("has_special", false)) else Color("85d8ce")
	visual.explosive = bool(projectile.get("explosive", false))
	visual.special_blast = bool(projectile.get("special_blast", false))
	visual.piercing = bool(projectile.get("piercing", false))
	visual.rotation = projectile.direction.angle()
	visual.position = player.position + projectile.direction * 14.0
	arena.add_child(visual)
	projectile.node = visual
	projectiles.append(projectile)

func _process_weapon_effects(delta: float) -> void:
	for index in range(weapon_effects.size() - 1, -1, -1):
		var effect: Dictionary = weapon_effects[index]
		if str(effect.kind) == "hammer_shockwave":
			effect.delay = float(effect.delay) - delta
			if float(effect.delay) > 0.0:
				weapon_effects[index] = effect
				continue
			for enemy in enemies.duplicate():
				var away := enemy.position - effect.position
				if away.length() <= float(effect.radius) and away.length() > 0.0:
					_move_enemy_around_obstacles(enemy, away.normalized() * 76.0)
			_add_combat_effect({"kind": "hammer_shockwave", "position": effect.position, "radius": float(effect.radius), "delay": 0.12, "life": 0.28, "max_life": 0.28})
			_play_tone(120.0, 0.09)
			weapon_effects.remove_at(index)
			continue
		if str(effect.kind) == "hammer_wave":
			effect.delay = float(effect.delay) - delta
			if float(effect.delay) > 0.0:
				weapon_effects[index] = effect
				continue
			if bool(effect.full_circle):
				_mark_discovered("discoveredSynergies", "marteau-stone")
			_play_tone(92.0, 0.13, "sawtooth")
			var forward := Vector2(cos(float(effect.angle)), sin(float(effect.angle)))
			var weapon: Dictionary = catalog.content.weapons[str(effect.weapon)]
			for enemy in enemies.duplicate():
				var offset := enemy.position - effect.position
				var distance := offset.length()
				var facing := offset.normalized().dot(forward) if distance > 0.0 else 1.0
				if distance <= float(effect.outer) and (bool(effect.full_circle) or facing > float(effect.arc)):
					_damage_enemy(enemy, _weapon_base_damage(weapon, enemy) * float(effect.damage_scale), str(effect.weapon))
					if not bool(effect.full_circle) and enemies.has(enemy) and enemy.hp > 0.0 and distance > 0.0:
						_move_enemy_around_obstacles(enemy, offset.normalized() * 26.0)
				if state != "playing":
					break
			if bool(effect.full_circle):
				weapon_effects.append({"kind": "hammer_shockwave", "delay": 0.12, "position": effect.position, "radius": float(effect.outer) + 48.0})
			_spawn_burst(effect.position, Color("ffd184"), 14)
			weapon_effects.remove_at(index)
			if state != "playing":
				break
			continue
		var direction: Vector2 = effect.shot.direction
		var charge_distance := 23.0 if str(effect.weapon) == "foudre" else 31.0
		var visual: Sprite2D = effect.visual
		visual.position = player.position + direction * charge_distance
		var pulse := 1.0 + 0.25 * sin((0.14 - float(effect.delay)) * 60.0)
		visual.scale = Vector2(0.12, 0.12) * pulse
		effect.delay = float(effect.delay) - delta
		if float(effect.delay) > 0.0:
			weapon_effects[index] = effect
			continue
		var shot: Dictionary = effect.shot
		if bool(effect.fan):
			var offsets := [-0.2, 0.0, 0.2]
			var damage_scales := [0.72, 1.0, 0.72]
			for shot_index in offsets.size():
				var volley_shot := shot.duplicate(true)
				volley_shot.direction = direction.rotated(float(offsets[shot_index]))
				volley_shot.damage = float(shot.damage) * float(damage_scales[shot_index])
				_spawn_player_projectile(volley_shot)
		else:
			_spawn_player_projectile(shot)
		_spawn_burst(visual.position, visual.modulate, 7)
		_play_tone(350.0 if bool(catalog.content.weapons[str(effect.weapon)].get("lightning", false)) else 640.0, 0.075, "sawtooth" if str(effect.weapon) == "foudre" else "triangle")
		if is_instance_valid(visual):
			visual.queue_free()
		weapon_effects.remove_at(index)

func _update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[index]
		var node: Node2D = projectile.node
		if projectile.get("team", "player") == "enemy":
			node.position += projectile.velocity * delta
			projectile.life -= delta
			if node.position.distance_to(player.position) < float(projectile.radius) + 10.0:
				if player.invulnerability <= 0.0:
					_damage_player(float(projectile.damage))
				_remove_projectile(index)
				continue
			if float(projectile.life) <= 0.0 or _position_blocked(node.position, float(projectile.radius)):
				_remove_projectile(index)
			continue
		var step := float(projectile.speed) * delta
		if projectile.has("homing_target") and is_instance_valid(projectile.homing_target):
			projectile.direction = node.position.direction_to(projectile.homing_target.position)
		if node is ValombreProjectileVisual:
			node.rotation = projectile.direction.angle()
		node.position += projectile.direction * step
		projectile.remaining -= step
		var hit_target: ValombreEnemy
		for enemy in enemies:
			if projectile.get("hit_targets", []).has(enemy):
				continue
			if enemy.position.distance_to(node.position) <= enemy.radius + float(projectile.radius):
				hit_target = enemy
				break
		if hit_target:
			if projectile.explosive:
				_detonate_projectile(projectile, node.position)
				_remove_projectile(index)
				if state != "playing":
					return
				continue
			if projectile.frost:
				hit_target.slow_time = maxf(hit_target.slow_time, float(projectile.get("slow_duration", 1.25)))
				hit_target.slow_factor = float(projectile.get("slow_factor", 0.58))
			_damage_enemy(hit_target, float(projectile.damage), str(projectile.weapon))
			var impact_tint := (node as ValombreProjectileVisual).tint if node is ValombreProjectileVisual else node.modulate
			_spawn_burst(node.position, impact_tint, 5)
			if state != "playing":
				_remove_projectile(index)
				return
			if projectile.lightning:
				_chain_lightning(hit_target, projectile)
			if bool(projectile.get("piercing", false)):
				var hit_targets: Array = projectile.get("hit_targets", [])
				hit_targets.append(hit_target)
				projectile.hit_targets = hit_targets
				projectile.damage = float(projectile.damage) * 1.18
				continue
			_remove_projectile(index)
			continue
		if projectile.remaining <= 0.0 or _position_blocked(node.position, float(projectile.radius)):
			if projectile.explosive:
				_detonate_projectile(projectile, node.position)
			_remove_projectile(index)
			if state != "playing":
				return

func _chain_lightning(first: ValombreEnemy, projectile: Dictionary) -> void:
	var current := first
	var hit: Array[ValombreEnemy] = [first]
	var max_bounces := int(projectile.get("chain_targets", 1))
	for _bounce in max_bounces:
		var nearest: ValombreEnemy
		var nearest_distance := float(projectile.get("chain_range", 190.0))
		for enemy in enemies:
			if hit.has(enemy):
				continue
			var distance := current.position.distance_to(enemy.position)
			if distance <= nearest_distance:
				nearest = enemy
				nearest_distance = distance
		if not nearest:
			break
		hit.append(nearest)
		if is_instance_valid(combat_effects):
			combat_effects.add_lightning_arc(current.position, nearest.position)
		_damage_enemy(nearest, float(projectile.damage) * 0.72, str(projectile.weapon))
		if state != "playing":
			break
		current = nearest
	if state == "playing" and bool(projectile.get("storm_special", false)):
		damage_zones.append({"position": current.position, "radius": 34.0, "damage": float(projectile.damage) * 0.28, "weapon": str(projectile.weapon), "tick": 0.12, "interval": 0.3, "life": 1.2})
		_add_combat_effect({"kind": "lightning_zone", "position": current.position, "radius": 34.0, "life": 1.2, "max_life": 1.2})

func _update_damage_zones(delta: float) -> void:
	for index in range(damage_zones.size() - 1, -1, -1):
		var zone: Dictionary = damage_zones[index]
		zone.life = float(zone.life) - delta
		zone.tick = float(zone.tick) - delta
		if float(zone.tick) <= 0.0:
			for enemy in enemies.duplicate():
				if enemy.position.distance_to(zone.position) < float(zone.radius):
					_damage_enemy(enemy, float(zone.damage), str(zone.weapon))
					if state != "playing":
						break
			zone.tick = float(zone.tick) + float(zone.interval)
		if float(zone.life) <= 0.0:
			damage_zones.remove_at(index)
		else:
			damage_zones[index] = zone
		if state != "playing":
			return

func _detonate_projectile(projectile: Dictionary, center: Vector2) -> void:
	var radius := float(projectile.get("explosion_radius", 44.0))
	_play_tone(78.0 if bool(projectile.get("special_blast", false)) else 112.0, 0.18, "sawtooth")
	_spawn_burst(center, Color("ffe18a") if bool(projectile.get("special_blast", false)) else Color("ff9a4e"), 16)
	_add_combat_effect({"kind": "bomb_explosion", "position": center, "radius": radius, "special": bool(projectile.get("special_blast", false)), "life": 0.38, "max_life": 0.38})
	for enemy in enemies.duplicate():
		var offset := enemy.position - center
		var distance := offset.length()
		if distance <= radius + enemy.radius:
			_damage_enemy(enemy, float(projectile.damage), str(projectile.weapon))
			if is_instance_valid(enemy) and enemy.hp > 0.0 and distance > 0.0:
				_move_enemy_around_obstacles(enemy, offset.normalized() * 24.0)
		if state != "playing":
			break
	if bool(projectile.get("special_blast", false)):
		damage_zones.append({"position": center, "radius": radius * 0.78, "damage": float(projectile.damage) * 0.18, "weapon": str(projectile.weapon), "tick": 0.16, "interval": 0.2, "life": 0.82})
		_add_combat_effect({"kind": "bomb_burn", "position": center, "radius": radius * 0.78, "life": 0.82, "max_life": 0.82})

func _remove_projectile(index: int) -> void:
	var projectile: Dictionary = projectiles[index]
	if is_instance_valid(projectile.node):
		projectile.node.queue_free()
	projectiles.remove_at(index)

func _damage_enemy(enemy: ValombreEnemy, amount: float, _weapon: String) -> void:
	if not is_instance_valid(enemy):
		return
	if bool(enemy.get_meta("sabre_mark", false)):
		amount *= 1.5
		enemy.set_meta("sabre_mark", false)
	var damage := roundf(amount)
	var dealt := minf(damage, maxf(0.0, enemy.hp))
	enemy.hp -= damage
	if equipment_lifesteal > 0.0 and dealt > 0.0 and is_instance_valid(player):
		hp = minf(max_hp, hp + dealt * equipment_lifesteal)
	enemy.hit_flash = 0.18
	_spawn_damage_number(enemy.position, roundi(damage))
	if enemy.hp <= 0.0:
		var death_position := enemy.position
		var is_boss := enemy.kind == "boss"
		_play_tone(70.0 if is_boss else 320.0, 0.4 if is_boss else 0.08, "triangle")
		enemy.queue_free()
		enemies.erase(enemy)
		defeated += 1
		var new_bestiary_discovery := _record_bestiary_kill(enemy)
		if new_bestiary_discovery or defeated % 10 == 0:
			_save_profile()
		_progress_objective("kills")
		if enemy.elite:
			_progress_objective("elite")
		_on_enemy_killed(enemy, _weapon)
		var weapon_xp_multiplier := float(_synergy_data(_weapon).get("experienceMultiplier", 1.0)) if not _weapon.is_empty() else 1.0
		if is_boss:
			_spawn_burst(death_position, Color("d6ad68"), 32)
			_enemy_drop_xp(death_position, 1.0, weapon_xp_multiplier)
			if mode == "infinite":
				profile.shards = int(profile.shards) + 1
				_save_checkpoint(wave + 1)
				intermission = 3.0
			else:
				_finish_run("victory")
		else:
			_roll_enemy_item_drop(death_position)
			_spawn_burst(death_position, Color("9d5744") if enemy.kind == "brute" else Color("b99e68"), 9)
			_enemy_drop_xp(death_position, 1.5 if enemy.elite else 1.0, weapon_xp_multiplier)

func _spawn_damage_number(position: Vector2, damage: int) -> void:
	var label := Label.new()
	label.text = str(damage)
	label.position = position + Vector2(-24.0, -34.0)
	label.size = Vector2(48.0, 20.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("f5dda0"))
	label.add_theme_color_override("font_outline_color", Color("17130e"))
	label.add_theme_constant_override("outline_size", 3)
	label.z_index = 12
	arena.add_child(label)
	damage_numbers.append({"node": label, "life": 0.65, "max_life": 0.65})

func _spawn_burst(position: Vector2, tint: Color, count: int) -> void:
	if is_instance_valid(particle_layer):
		particle_layer.burst(position, tint, count, rng)

func _add_combat_effect(effect: Dictionary) -> void:
	if is_instance_valid(combat_effects):
		combat_effects.add_effect(effect)

func _update_damage_numbers(delta: float) -> void:
	for index in range(damage_numbers.size() - 1, -1, -1):
		var number: Dictionary = damage_numbers[index]
		var node: Variant = number.get("node")
		if not is_instance_valid(node):
			damage_numbers.remove_at(index)
			continue
		var label := node as Label
		number.life = float(number.life) - delta
		label.position.y -= 25.0 * delta
		var tint := label.modulate
		tint.a = clampf(float(number.life) / float(number.max_life), 0.0, 1.0)
		label.modulate = tint
		if float(number.life) <= 0.0:
			label.queue_free()
			damage_numbers.remove_at(index)

func _weapon_scale(id: String) -> float:
	var owned := _owned_weapon(id)
	if owned.is_empty():
		return damage_multiplier * equipment_damage * (1.0 + (level - 1) * 0.005)
	return damage_multiplier * equipment_damage * (1.0 + 0.18 * (int(owned.level) - 1)) * (1.5 if bool(owned.special) else 1.0) * float(_synergy_data(id).get("damageMultiplier", 1.0)) * (1.0 + (level - 1) * 0.005)

func _on_enemy_killed(enemy: ValombreEnemy, weapon: String) -> void:
	var death_position := enemy.position
	if weapon == "faux" and _synergy_active("faux"):
		scythe_souls = mini(5, scythe_souls + 1)
	if weapon == "dagues" and _synergy_active("dagues"):
		var targets: Array[ValombreEnemy] = []
		for candidate in enemies:
			if candidate != enemy and candidate.position.distance_to(death_position) <= 300.0:
				targets.append(candidate)
		targets.sort_custom(func(a: ValombreEnemy, b: ValombreEnemy) -> bool: return a.position.distance_to(death_position) < b.position.distance_to(death_position))
		for target in targets.slice(0, mini(3, targets.size())):
			var dagger := ValombreProjectileVisual.new()
			dagger.team = "player"
			dagger.radius = 6.0
			dagger.tint = Color("a9ffe1")
			dagger.rotation = death_position.direction_to(target.position).angle()
			dagger.position = death_position
			arena.add_child(dagger)
			projectiles.append({"node": dagger, "direction": death_position.direction_to(target.position), "speed": 620.0, "radius": 6.0, "damage": float(catalog.content.weapons.dagues.ghoulDamage) * _weapon_scale("dagues") * 1.4, "weapon": "", "remaining": 900.0, "homing_target": target, "explosive": false, "lightning": false, "frost": false, "hit_targets": []})
	if weapon == "givre" and enemy.slow_time > 0.0 and _synergy_active("givre"):
		_add_combat_effect({"kind": "frost_nova", "position": death_position, "radius": 124.0, "life": 0.42, "max_life": 0.42})
		for target in enemies.duplicate():
			if target == enemy or target.position.distance_to(death_position) > 124.0:
				continue
			target.slow_time = maxf(target.slow_time, 1.8)
			target.slow_factor = 0.35
			_damage_enemy(target, float(catalog.content.weapons.givre.ghoulDamage) * _weapon_scale("givre") * 1.35, "")

func _enemy_drop_xp(position: Vector2, value: float, weapon_xp_multiplier := 1.0) -> void:
	var node := Sprite2D.new()
	node.texture = load("res://assets/xp.svg")
	node.scale = Vector2(0.18, 0.18)
	node.position = _drop_spawn_position(position)
	arena.add_child(node)
	var xp_multiplier := equipment_xp * weapon_xp_multiplier
	var lifetime := float(catalog.content.config.drops.get("lifetime", 18.0))
	drops.append({"node": node, "type": "xp", "value": value * xp_multiplier, "life": lifetime})

func _drop_spawn_position(position: Vector2) -> Vector2:
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(12.0, 30.0)
	return Vector2(
		clampf(position.x + cos(angle) * distance, 12.0, WORLD_SIZE.x - 12.0),
		clampf(position.y + sin(angle) * distance, 12.0, WORLD_SIZE.y - 12.0)
	)

func _roll_enemy_item_drop(position: Vector2) -> void:
	var difficulty: Dictionary = catalog.content.difficulties.get(difficulty_id, {})
	var lifetime := float(catalog.content.config.drops.get("lifetime", 18.0))
	var drop_roll := rng.randf()
	var potion_chance := float(catalog.content.config.drops.get("potionChance", 0.08)) * float(difficulty.get("itemDrop", 1.0))
	var equipment_chance := float(catalog.content.config.drops.get("relicChance", 0.22)) * float(difficulty.get("itemDrop", 1.0))
	if drop_roll < potion_chance:
		var potion := Sprite2D.new()
		potion.texture = load("res://assets/relics/heart.svg")
		potion.scale = Vector2(0.17, 0.17)
		potion.position = _drop_spawn_position(position)
		arena.add_child(potion)
		drops.append({"node": potion, "type": "potion", "life": lifetime})
	elif drop_roll < potion_chance + equipment_chance:
		var weapon_choices: Array[String] = []
		for definition: GameDefinition in catalog.definitions.get("weapons", []):
			var id := str(definition.id)
			var owned := _owned_weapon(id)
			var allowed := (not single_weapon or id == weapon_id) and (not custom_drops or selected_drop_weapons.has(id))
			if allowed and (owned.is_empty() or not bool(owned.special)):
				weapon_choices.append(id)
		var relic_choices: Array[String] = []
		for relic: Dictionary in catalog.content.relics:
			var owned_relic := _owned_relic(str(relic.id))
			if (not custom_drops or selected_drop_relics.has(str(relic.id))) and (owned_relic.is_empty() or int(owned_relic.level) < 5):
				relic_choices.append(str(relic.id))
		var drop_types: Array[String] = []
		if not weapon_choices.is_empty():
			drop_types.append("weapon")
		if not relic_choices.is_empty():
			drop_types.append("relic")
		if not drop_types.is_empty():
			var loot_type := drop_types[rng.randi_range(0, drop_types.size() - 1)]
			var loot_choices := weapon_choices if loot_type == "weapon" else relic_choices
			var loot_id := loot_choices[rng.randi_range(0, loot_choices.size() - 1)]
			var loot_node := Sprite2D.new()
			loot_node.texture = load("res://assets/weapons/category.svg") if loot_type == "weapon" else load("res://assets/relics/category.svg")
			loot_node.scale = Vector2(0.17, 0.17)
			loot_node.position = _drop_spawn_position(position)
			arena.add_child(loot_node)
			drops.append({"node": loot_node, "type": loot_type, "id": loot_id, "life": lifetime})

func _update_drops(delta: float) -> void:
	var bomb_combo_pickups := 0
	for index in range(drops.size() - 1, -1, -1):
		var drop: Dictionary = drops[index]
		var node: Variant = drop.get("node")
		if not is_instance_valid(node):
			drops.remove_at(index)
			continue
		if not global_pickup:
			drop.life -= delta
		var distance: float = player.position.distance_to(node.position)
		if distance > 22.0 and (distance < pickup_range or global_pickup):
			var pull_speed := player.move_speed * movement_multiplier * equipment_speed * 1.2
			var step := minf(distance, pull_speed * delta)
			node.position += node.position.direction_to(player.position) * step
		if player.position.distance_to(node.position) <= 22.0:
			if global_pickup:
				bomb_combo_pickups += 1
			if str(drop.get("type", "xp")) == "weapon":
				_play_tone(790.0, 0.16, "triangle")
				_pick_weapon(str(drop.id))
			elif str(drop.get("type", "xp")) == "relic":
				_play_tone(790.0, 0.16, "triangle")
				_pick_relic(str(drop.id))
			elif str(drop.get("type", "xp")) == "potion":
				var potion_heal := float(catalog.content.config.drops.get("potionHeal", 32))
				hp = minf(max_hp, hp + potion_heal)
				_play_tone(620.0, 0.12)
				_show_notice("Fiole écarlate · +%d PV" % int(potion_heal), false)
			else:
				xp += float(drop.value)
				_play_tone(790.0, 0.12, "sine")
			drop.node.queue_free()
			drops.remove_at(index)
			if str(drop.get("type", "xp")) == "xp":
				_progress_objective("xp")
				while xp >= next_xp:
					xp -= next_xp
					level += 1
					next_xp += 3.0
					pending_upgrades += 1
				var old_max_hp := max_hp
				max_hp = base_hp * (1.0 + (level - 1) * 0.01) + bonus_max_hp + _relic_health()
				hp = minf(max_hp, hp + max_hp - old_max_hp)
				if pending_upgrades > 0:
					_show_level_up()
					return
			if state != "playing":
				return
		elif float(drop.life) <= 0.0:
			node.queue_free()
			drops.remove_at(index)
	if bomb_combo_pickups > 0 and state == "playing":
		var bomb_damage := float(catalog.content.weapons.bombe.ghoulDamage) * _weapon_scale("bombe") * minf(4.0, 1.4 + (bomb_combo_pickups - 1) * 0.55)
		_detonate_projectile({"radius": 92.0, "damage": bomb_damage, "weapon": "bombe"}, player.position)

func _show_level_up() -> void:
	_play_tone(460.0, 0.12, "sine")
	_set_state("levelUp")
	var column: VBoxContainer = menu_panel.get_child(0)
	for button in upgrade_buttons:
		if is_instance_valid(button):
			button.queue_free()
	upgrade_buttons.clear()
	_clear_loot_buttons()
	var choices: Array[GameDefinition] = []
	var pool: Array = catalog.definitions.upgrades.filter(func(item: GameDefinition) -> bool: return int(upgrade_ranks.get(str(item.id), 0)) < int(item.values.get("maxRanks", 10)))
	if pool.is_empty():
		pending_upgrades = 0
		_set_state("playing")
		return
	while choices.size() < 3 and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		choices.append(pool.pop_at(index))
	upgrade_choices = choices.duplicate()
	auto_pick_remaining = 3.0 if bool(profile.get("autoPickUpgrade", true)) else -1.0
	for definition in choices:
		var button := Button.new()
		button.text = "%s · %s\nRang %d/%d · prochain bonus %s" % [definition.display_name, definition.values.get("description", ""), upgrade_ranks.get(str(definition.id), 0), definition.values.get("maxRanks", 10), _format_upgrade_bonus(definition)]
		button.pressed.connect(_apply_upgrade.bind(definition))
		button.focus_entered.connect(_restart_auto_pick_timer)
		button.mouse_entered.connect(_restart_auto_pick_timer)
		column.add_child(button)
		upgrade_buttons.append(button)

func _apply_upgrade(definition: GameDefinition) -> void:
	auto_pick_remaining = -1.0
	_play_tone(790.0, 0.12)
	var values: Dictionary = definition.values
	var rank := int(upgrade_ranks.get(str(definition.id), 0))
	var bonus := float(values.get("bonus", 0.0)) / float(rank + 1)
	match str(definition.id):
		"damage": damage_multiplier *= 1.0 + bonus
		"attackSpeed": attack_speed_multiplier *= 1.0 + bonus
		"range": range_bonus += bonus
		"projectileSize": projectile_size_multiplier *= 1.0 + bonus
		"projectileSpeed": projectile_speed_multiplier *= 1.0 + bonus
		"movementSpeed":
			movement_multiplier *= 1.0 + bonus
			player.movement_multiplier = movement_multiplier
		"health":
			bonus_max_hp += bonus
			max_hp += bonus
			hp = minf(max_hp, hp + bonus)
		"defense": defense += bonus
		"pickupRange":
			pickup_range_multiplier *= 1.0 + bonus
			pickup_range *= 1.0 + bonus
	upgrade_ranks[str(definition.id)] = rank + 1
	_refresh_relic_stats()
	pending_upgrades -= 1
	if pending_upgrades > 0:
		_show_level_up()
	else:
		_set_state("playing")
		_clear_upgrade_buttons()

func _restart_auto_pick_timer() -> void:
	if state == "levelUp" and bool(profile.get("autoPickUpgrade", true)):
		auto_pick_remaining = 3.0

func _clear_upgrade_buttons() -> void:
	for button in upgrade_buttons:
		if is_instance_valid(button):
			button.queue_free()
	upgrade_buttons.clear()
	upgrade_choices.clear()

func _clear_loot_buttons() -> void:
	for button in loot_buttons:
		if is_instance_valid(button):
			button.queue_free()
	loot_buttons.clear()

func _show_loot_choices(item_name: String, description: String, group: String, item: Dictionary, candidates: Array[Dictionary]) -> void:
	_clear_upgrade_buttons()
	_clear_loot_buttons()
	var previous_synergies: Array[String] = []
	for synergy: Dictionary in catalog.content.synergies:
		if _synergy_active(str(synergy.weaponId)):
			previous_synergies.append(str(synergy.id))
	_set_state("loot")
	status_label.text = "%s : %s. Choisissez un objet à remplacer, ou passez." % [item_name, description]
	var items := weapon_inventory if group == "weapons" else relic_inventory
	for candidate in candidates:
		var item_id := str(candidate.id)
		var button := Button.new()
		if group == "weapons":
			var definition := _find_definition("weapons", item_id)
			var synergy_detail := _synergy_description(item_id)
			button.text = "Remplacer %s · niveau %d%s" % [definition.display_name if definition else item_id, int(candidate.level), " · " + synergy_detail if not synergy_detail.is_empty() else ""]
		else:
			var synergy_detail := _synergy_description(str(candidate.id))
			button.text = "Remplacer %s · niveau %d%s" % [str(candidate.get("name", item_id)), int(candidate.level), " · " + synergy_detail if not synergy_detail.is_empty() else ""]
		button.pressed.connect(func() -> void:
			var slot := items.find(candidate)
			if slot >= 0:
				var replaced_name := str(candidate.get("name", candidate.id)) if group == "relics" else str(_find_definition("weapons", item_id).display_name)
				items[slot] = item.duplicate(true)
				if group == "weapons":
					_mark_discovered("discoveredWeapons", str(item.id))
					if str(candidate.id) == weapon_id:
						weapon_id = str(item.id)
					weapon_cooldowns.erase(item_id)
					weapon_cooldowns[str(item.id)] = 0.0
				else:
					_mark_discovered("discoveredRelics", str(item.id))
				_refresh_relic_stats()
				_save_checkpoint(wave)
				_show_notice("%s remplace %s" % [item_name, replaced_name])
				var activated: Array[String] = []
				for synergy: Dictionary in catalog.content.synergies:
					if _synergy_active(str(synergy.weaponId)) and not previous_synergies.has(str(synergy.id)):
						activated.append(str(synergy.name))
				if not activated.is_empty():
					_show_notice("Synergie activée · %s" % activated[0])
			_set_state("playing")
			_clear_loot_buttons()
		)
		menu_column.add_child(button)
		loot_buttons.append(button)
	var pass_button := Button.new()
	pass_button.text = "Passer cet équipement"
	pass_button.pressed.connect(func() -> void:
		_set_state("playing")
		_clear_loot_buttons()
	)
	menu_column.add_child(pass_button)
	loot_buttons.append(pass_button)

func _synergy_description(item_id: String) -> String:
	for synergy: Dictionary in catalog.content.synergies:
		if str(synergy.weaponId) == item_id or str(synergy.relicId) == item_id:
			return str(synergy.get("description", ""))
	return ""

func _owned_weapon(id: String) -> Dictionary:
	for item in weapon_inventory:
		if str(item.id) == id:
			return item
	return {}

func _owned_relic(id: String) -> Dictionary:
	for item in relic_inventory:
		if str(item.id) == id:
			return item
	return {}

func _pick_weapon(id: String) -> void:
	var owned := _owned_weapon(id)
	if not owned.is_empty():
		if int(owned.level) < 5:
			owned.level = int(owned.level) + 1
		elif not bool(owned.special):
			owned.special = true
			_show_notice("%s spéciale obtenue !" % _find_definition("weapons", id).display_name)
		else:
			_show_notice("Cette arme est déjà au maximum")
			return
		weapon_cooldowns[id] = 0.0
		_mark_discovered("discoveredWeapons", id)
		_refresh_relic_stats()
		if int(owned.level) < 5:
			_show_notice("%s · niveau %d" % [_find_definition("weapons", id).display_name, int(owned.level)])
		elif bool(owned.special):
			_show_notice("%s spéciale obtenue !" % _find_definition("weapons", id).display_name)
		return
	var entry := {"id": id, "level": 1, "special": false, "locked": false}
	if uncapped_inventory or weapon_inventory.size() < 5:
		weapon_inventory.append(entry)
		_mark_discovered("discoveredWeapons", id)
		_refresh_relic_stats()
		_show_notice("%s ajoutée à l’arsenal · niveau 1" % _find_definition("weapons", id).display_name)
		return
	var choices: Array[Dictionary] = []
	for item in weapon_inventory:
		if not bool(item.get("locked", false)):
			choices.append(item)
	if choices.is_empty():
		_show_notice("Arsenal plein · toutes les armes sont verrouillées")
		return
	var definition := _find_definition("weapons", id)
	_show_loot_choices(definition.display_name if definition else id, str(definition.values.get("description", "")) if definition else "", "weapons", entry, choices)

func _pick_relic(id: String) -> void:
	var owned := _owned_relic(id)
	if not owned.is_empty():
		if int(owned.level) < 5:
			owned.level = int(owned.level) + 1
			_mark_discovered("discoveredRelics", id)
			_refresh_relic_stats()
			_show_notice("%s · niveau %d" % [str(owned.get("name", id)), int(owned.level)])
		else:
			_show_notice("%s niveau maximum" % str(owned.get("name", id)))
		return
	var entry: Dictionary = {}
	for relic: Dictionary in catalog.content.relics:
		if str(relic.id) == id:
			entry = relic.duplicate(true)
			break
	if entry.is_empty():
		return
	entry.level = 1
	entry.locked = false
	if uncapped_inventory or relic_inventory.size() < 5:
		relic_inventory.append(entry)
		_mark_discovered("discoveredRelics", id)
		_refresh_relic_stats()
		_show_notice("%s équipée · niveau 1" % str(entry.get("name", id)))
		return
	var choices: Array[Dictionary] = []
	for item in relic_inventory:
		if not bool(item.get("locked", false)):
			choices.append(item)
	if choices.is_empty():
		_show_notice("Sacoche pleine · toutes les reliques sont verrouillées")
		return
	_show_loot_choices(str(entry.get("name", id)), str(entry.get("description", "")), "relics", entry, choices)

func _refresh_relic_stats() -> void:
	equipment_damage = 1.0
	equipment_speed = 1.0
	equipment_range = 0.0
	equipment_defense = 0.0
	equipment_xp = 1.0
	equipment_lifesteal = 0.0
	var pickup_mult := 1.0
	var health_bonus := 0.0
	global_pickup = false
	for relic in relic_inventory:
		var value := float(relic.get("value", 0.0))
		var ranks := int(relic.get("level", 1))
		match str(relic.get("effect", "")):
			"damage": equipment_damage += value * ranks
			"speed": equipment_speed *= 1.0 + (value - 1.0) * ranks
			"range": equipment_range += value * ranks
			"defense": equipment_defense = minf(0.65, equipment_defense + value * ranks)
			"experience": equipment_xp *= 1.0 + (value - 1.0) * ranks
			"lifesteal": equipment_lifesteal += value * ranks
			"health": health_bonus += value * ranks
			"pickup": pickup_mult *= 1.0 + (value - 1.0) * ranks
	for synergy: Dictionary in catalog.content.synergies:
		var owned_weapon := _owned_weapon(str(synergy.weaponId))
		var owned_relic := _owned_relic(str(synergy.relicId))
		if not owned_weapon.is_empty() and int(owned_weapon.level) == 5 and bool(owned_weapon.special) and not owned_relic.is_empty() and int(owned_relic.level) == 5 and bool(synergy.get("globalPickup", false)):
			global_pickup = true
			_mark_discovered("discoveredSynergies", str(synergy.id))
	max_hp = base_hp * (1.0 + (level - 1) * 0.01) + bonus_max_hp + health_bonus
	hp = minf(max_hp, hp)
	pickup_range = 90.0 * pickup_range_multiplier * pickup_mult
	player.equipment_speed = equipment_speed

func _synergy_active(weapon: String) -> bool:
	for synergy: Dictionary in catalog.content.synergies:
		if str(synergy.weaponId) != weapon:
			continue
		var owned_weapon := _owned_weapon(weapon)
		var owned_relic := _owned_relic(str(synergy.relicId))
		if not owned_weapon.is_empty() and int(owned_weapon.level) == 5 and bool(owned_weapon.special) and not owned_relic.is_empty() and int(owned_relic.level) == 5:
			_mark_discovered("discoveredSynergies", str(synergy.id))
			return true
	return false

func _synergy_data(weapon: String) -> Dictionary:
	for synergy: Dictionary in catalog.content.synergies:
		if str(synergy.weaponId) == weapon and _synergy_active(weapon):
			return synergy
	return {}

func _inventory_summary() -> String:
	var lines: Array[String] = ["ARMES"]
	for item in weapon_inventory:
		lines.append("%s · niveau %d%s" % [_find_definition("weapons", str(item.id)).display_name, int(item.level), " · spéciale" if bool(item.special) else ""])
	lines.append("\nRELIQUES")
	for item in relic_inventory:
		lines.append("%s · niveau %d" % [str(item.get("name", item.id)), int(item.level)])
	lines.append("\nSYNERGIES ACTIVES")
	var found := false
	for synergy: Dictionary in catalog.content.synergies:
		if _synergy_active(str(synergy.weaponId)):
			lines.append(str(synergy.name))
			found = true
	if not found:
		lines.append("Aucune")
	return "\n".join(lines)

func _refresh_inventory_panel() -> void:
	if not is_instance_valid(inventory_list):
		return
	for child in inventory_list.get_children():
		child.queue_free()
	var weapon_heading := Label.new()
	weapon_heading.text = "ARMES · %d/%s" % [weapon_inventory.size(), "∞" if uncapped_inventory else "5"]
	inventory_list.add_child(weapon_heading)
	for index in weapon_inventory.size():
		var item: Dictionary = weapon_inventory[index]
		var definition := _find_definition("weapons", str(item.id))
		var row := HBoxContainer.new()
		var label := Label.new()
		var starting := " · DÉPART" if str(item.id) == weapon_id else ""
		var special := " · SPÉCIALE" if bool(item.get("special", false)) else ""
		label.text = "%s · niv. %d%s%s" % [definition.display_name if definition else str(item.id), int(item.level), starting, special]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var lock := CheckBox.new()
		lock.text = "Verrouiller"
		lock.button_pressed = bool(item.get("locked", false))
		lock.toggled.connect(func(enabled: bool) -> void: _set_inventory_lock("weapons", str(item.id), enabled))
		row.add_child(lock)
		inventory_list.add_child(row)
	var relic_heading := Label.new()
	relic_heading.text = "RELIQUES · %d/%s" % [relic_inventory.size(), "∞" if uncapped_inventory else "5"]
	inventory_list.add_child(relic_heading)
	for item in relic_inventory:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s · niv. %d" % [str(item.get("name", item.id)), int(item.level)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var lock := CheckBox.new()
		lock.text = "Verrouiller"
		lock.button_pressed = bool(item.get("locked", false))
		lock.toggled.connect(func(enabled: bool) -> void: _set_inventory_lock("relics", str(item.id), enabled))
		row.add_child(lock)
		inventory_list.add_child(row)
	var synergy_heading := Label.new()
	synergy_heading.text = "SYNERGIES · %d/9" % _active_synergy_count()
	inventory_list.add_child(synergy_heading)
	var active_count := 0
	for synergy: Dictionary in catalog.content.synergies:
		if _synergy_active(str(synergy.weaponId)):
			active_count += 1
			var label := Label.new()
			label.text = str(synergy.name)
			inventory_list.add_child(label)
	if active_count == 0:
		var empty_label := Label.new()
		empty_label.text = "Aucune active"
		inventory_list.add_child(empty_label)
	var objective_heading := Label.new()
	objective_heading.text = "OBJECTIF · %s %d/%d%s" % [objective_type, mini(objective_progress, objective_target), objective_target, " · terminé" if objective_complete else ""]
	inventory_list.add_child(objective_heading)
	for challenge in run_challenges:
		var label := Label.new()
		label.text = "%s · %s %d/%d · %s" % ["✓" if bool(challenge.complete) else "Défi", str(challenge.label), int(challenge.progress), int(challenge.target), str(challenge.reward)]
		inventory_list.add_child(label)

func _active_synergy_count() -> int:
	var count := 0
	for synergy: Dictionary in catalog.content.synergies:
		if _synergy_active(str(synergy.weaponId)):
			count += 1
	return count

func _mark_discovered(collection: String, item_id: String) -> void:
	if item_id.is_empty():
		return
	var records: Dictionary = profile.get(collection, {})
	if bool(records.get(item_id, false)):
		return
	records[item_id] = true
	profile[collection] = records
	_save_profile()

func _discover_bestiary(key: String, elite_id: String) -> void:
	var bestiary: Dictionary = profile.get("bestiary", {})
	var changed := false
	for entry_id in [key, "elite:%s" % elite_id if not elite_id.is_empty() else ""]:
		if str(entry_id).is_empty():
			continue
		var record: Dictionary = bestiary.get(entry_id, {"kills": 0, "discovered": false})
		if not bool(record.get("discovered", false)):
			record.discovered = true
			bestiary[entry_id] = record
			changed = true
	if changed:
		profile.bestiary = bestiary
		_save_profile()

func _record_bestiary_kill(enemy: ValombreEnemy) -> bool:
	var key := "boss:%s" % enemy.boss_id if enemy.kind == "boss" else enemy.kind
	var bestiary: Dictionary = profile.get("bestiary", {})
	var record: Dictionary = bestiary.get(key, {"kills": 0, "discovered": true})
	var new_discovery := int(record.get("kills", 0)) == 0
	record.kills = int(record.get("kills", 0)) + 1
	record.discovered = true
	bestiary[key] = record
	if enemy.elite:
		var elite_key := "elite:%s" % enemy.elite_id
		var elite_record: Dictionary = bestiary.get(elite_key, {"kills": 0, "discovered": true})
		if int(elite_record.get("kills", 0)) == 0:
			new_discovery = true
		elite_record.kills = int(elite_record.get("kills", 0)) + 1
		elite_record.discovered = true
		bestiary[elite_key] = elite_record
	profile.bestiary = bestiary
	return new_discovery

func _set_inventory_lock(group: String, item_id: String, enabled: bool) -> void:
	var item := _owned_weapon(item_id) if group == "weapons" else _owned_relic(item_id)
	if item.is_empty():
		return
	item.locked = enabled
	_save_checkpoint(wave)

func _show_notice(message: String, play_sound := true) -> void:
	notice_text = message
	notice_timer = 1.8
	if is_instance_valid(notice_label):
		notice_label.text = message
	if play_sound:
		_play_tone(510.0, 0.035)

func _build_pause_catalog() -> void:
	if not is_instance_valid(pause_catalog_list):
		return
	for child in pause_catalog_list.get_children():
		child.queue_free()
	var weapons: Dictionary = catalog.content.weapons
	var weapon_records: Dictionary = profile.get("discoveredWeapons", {})
	var owned_weapons: Dictionary = {}
	for item in weapon_inventory:
		owned_weapons[str(item.id)] = item
	_add_catalog_heading("ARMES · %d/%d" % [weapon_records.size(), weapons.size()])
	for id in weapons:
		var record: Dictionary = weapons[id]
		var owned: Dictionary = owned_weapons.get(str(id), {})
		var discovered := bool(weapon_records.get(str(id), false)) or not owned.is_empty()
		var detail := str(record.get("description", "")) if discovered else "Arme non découverte."
		var status := "Possédée · niveau %d%s" % [int(owned.get("level", 1)), " · spéciale" if bool(owned.get("special", false)) else ""] if not owned.is_empty() else "Découverte" if discovered else "Inconnue"
		_add_catalog_entry(str(record.get("name", record.get("displayName", id))) if discovered else "Inconnue", detail, status)
	var relic_records: Dictionary = profile.get("discoveredRelics", {})
	var owned_relics: Dictionary = {}
	for item in relic_inventory:
		owned_relics[str(item.id)] = item
	_add_catalog_heading("RELIQUES · %d/%d" % [relic_records.size(), catalog.content.relics.size()])
	for relic: Dictionary in catalog.content.relics:
		var id := str(relic.id)
		var owned: Dictionary = owned_relics.get(id, {})
		var discovered := bool(relic_records.get(id, false)) or not owned.is_empty()
		var detail := str(relic.get("description", "")) if discovered else "Relique non découverte."
		var status := "Possédée · niveau %d" % int(owned.get("level", 1)) if not owned.is_empty() else "Découverte" if discovered else "Inconnue"
		_add_catalog_entry(str(relic.get("name", id)) if discovered else "Inconnue", detail, status)
	var synergy_records: Dictionary = profile.get("discoveredSynergies", {})
	_add_catalog_heading("SYNERGIES · %d/9" % synergy_records.size())
	for synergy: Dictionary in catalog.content.synergies:
		var id := str(synergy.id)
		var discovered := bool(synergy_records.get(id, false)) or _synergy_active(str(synergy.weaponId))
		var detail := str(synergy.get("description", "")) if discovered else "Combo non découvert."
		var status := "Activée" if _synergy_active(str(synergy.weaponId)) else "Découverte · à réactiver" if discovered else "Inconnue"
		_add_catalog_entry(str(synergy.get("name", "Combo inconnu")) if discovered else "Combo inconnu", detail, status)
	var bestiary: Dictionary = profile.get("bestiary", {})
	_add_catalog_heading("BESTIAIRE")
	var bestiary_entries: Dictionary = catalog.content.bestiary.duplicate(true)
	for id in catalog.content.bosses:
		var boss: Dictionary = catalog.content.bosses[id]
		bestiary_entries["boss:%s" % id] = boss
	for id in bestiary_entries:
		var definition: Dictionary = bestiary_entries[id]
		var record: Dictionary = bestiary.get(str(id), {})
		var discovered := bool(record.get("discovered", false)) or int(record.get("kills", 0)) > 0
		var attack: String = str(definition.get("attack", definition.get("behavior", "")))
		var detail := "%s Attaque : %s" % [str(definition.get("description", "")), attack] if discovered else "Créature non rencontrée."
		_add_catalog_entry(str(definition.get("name", id)) if discovered else "Inconnu", detail, "Vaincus : %d" % int(record.get("kills", 0)) if discovered else "Non découvert")
	_add_catalog_heading("AFFIXES ÉLITES")
	for id in catalog.content.eliteAffixes:
		var definition: Dictionary = catalog.content.eliteAffixes[id]
		var record: Dictionary = bestiary.get("elite:%s" % id, {})
		var discovered := bool(record.get("discovered", false)) or int(record.get("kills", 0)) > 0
		var detail := "PV ×%s · vitesse ×%s · dégâts ×%s" % [str(definition.health), str(definition.speed), str(definition.damage)] if discovered else "Variante élite non rencontrée."
		_add_catalog_entry("Élite · %s" % str(definition.name) if discovered else "Élite inconnue", detail, "Vaincus : %d" % int(record.get("kills", 0)) if discovered else "Non découvert")

func _add_catalog_heading(title: String) -> void:
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 18)
	pause_catalog_list.add_child(heading)

func _add_catalog_entry(title: String, description: String, status: String) -> void:
	var label := Label.new()
	label.text = "%s — %s · %s" % [title, description, status]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_catalog_list.add_child(label)

func _relic_health() -> float:
	var total := 0.0
	for item in relic_inventory:
		if str(item.get("effect", "")) == "health":
			total += float(item.value) * int(item.level)
	return total

func _damage_player(amount: float) -> bool:
	if state != "playing" or player.invulnerability > 0.0 or cheat_infinite_life:
		return false
	_play_tone(90.0, 0.11, "square")
	var incoming := amount * (1.0 - minf(0.8, defense + equipment_defense))
	var absorbed := minf(player_shield, incoming)
	player_shield -= absorbed
	hp -= incoming - absorbed
	player.invulnerability = float(catalog.content.config.combat.playerInvulnerability)
	_spawn_burst(player.position, Color("bb493c"), 4)
	if hp <= 0.0:
		hp = 0.0
		_finish_run("defeat")
	return true

func _use_hero_skill() -> void:
	if skill_cooldown > 0.0:
		return
	var hero: Dictionary = catalog.content.heroes.get(hero_id, {})
	if str(hero.get("special", "")) != "charge":
		return
	_play_tone(105.0, 0.18, "sawtooth")
	skill_cooldown = float(hero.get("cooldown", 5.0))
	var forward := player.facing
	var charge_distance := float(hero.get("chargeDistance", 190.0))
	var start := player.position
	for step in range(12, int(charge_distance) + 1, 12):
		if _position_blocked(start + forward * float(step), 11.0):
			charge_distance = float(step - 12)
			break
	var hit_count := 0
	for enemy in enemies.duplicate():
		var offset := enemy.position - player.position
		var forward_distance := offset.dot(forward)
		var side_distance := absf(offset.cross(forward))
		if forward_distance > 0.0 and forward_distance < charge_distance and side_distance < float(hero.get("chargeWidth", 34.0)):
			_damage_enemy(enemy, float(hero.get("chargeDamage", 58.0)), "")
			hit_count += 1
	player.position = Vector2(
		clampf(start.x + forward.x * charge_distance, 35.0, WORLD_SIZE.x - 35.0),
		clampf(start.y + forward.y * charge_distance, 35.0, WORLD_SIZE.y - 35.0)
	)
	player.invulnerability = maxf(player.invulnerability, float(hero.get("chargeInvulnerability", 0.32)))
	_spawn_burst(player.position, Color("d5ae69"), 16)
	var notice := str(hero.get("specialName", "Capacité spéciale"))
	if hit_count > 0:
		notice += " · %d touché%s" % [hit_count, "s" if hit_count > 1 else ""]
	_show_notice(notice, false)
	_update_hud()

func _set_state(next_state: String) -> void:
	state = next_state
	var is_overlay := state != "playing"
	menu_panel.visible = is_overlay
	overlay_backdrop.visible = is_overlay
	if is_instance_valid(particle_layer):
		particle_layer.set_process(state == "playing")
	if is_instance_valid(combat_effects):
		combat_effects.set_process(state == "playing")
	if is_instance_valid(touch_controls):
		if state != "playing":
			touch_controls.release_all()
		touch_controls.visible = state == "playing" and DisplayServer.is_touchscreen_available()
	player.run_active = state == "playing"
	if is_instance_valid(cheat_button):
		cheat_button.visible = state == "playing"
		_update_cheat_button()
	_update_player_visuals()
	if state != "playing":
		inventory_open = false
		if is_instance_valid(inventory_panel):
			inventory_panel.visible = false
	if state != "loot":
		_clear_loot_buttons()
	match state:
		"title":
			title_label.text = "LES CENDRES DE VALOMBRE"
			var title_instructions := "Une run interrompue peut être reprise ou abandonnée." if profile.get("run") is Dictionary else "Choisissez votre héros, votre arme, le mode et la difficulté."
			status_label.text = "Victoires : %d · Éclats : %d · Meilleur score : %d créatures\n%s\nWASD / flèches · E capacité · Maj esquive · Échap pause" % [profile.wins, profile.shards, profile.bestKills, title_instructions]
			start_button.text = "Reprendre · vague %d" % int(profile.run.get("wave", 1)) if profile.get("run") is Dictionary else "Entrer dans la forêt"
		"paused":
			title_label.text = "LA CHASSE ATTEND"
			status_label.text = "Échap ou le bouton ci-dessous pour reprendre · Tab : arsenal"
			start_button.text = "Reprendre la chasse"
		"levelUp":
			title_label.text = "UNE NOUVELLE FORCE"
			status_label.text = "Choisissez une amélioration."
			start_button.visible = false
		"loot":
			title_label.text = "UN NOUVEL ÉQUIPEMENT"
			status_label.text = "Votre sac est plein. Choisissez un objet à remplacer, ou passez."
			start_button.visible = false
		"victory":
			title_label.text = "VALOMBRE EST LIBÉRÉE"
			status_label.text = _result_summary(true)
			start_button.text = "Rejouer"
		"defeat":
			title_label.text = "LA FORÊT VOUS REPREND"
			status_label.text = _result_summary(false)
			start_button.text = "Rejouer"
	if state not in ["levelUp", "loot"]:
		start_button.visible = true
		var show_setup := state == "title" and not (profile.get("run") is Dictionary)
		hero_picker.visible = show_setup
		weapon_picker.visible = show_setup
		mode_picker.visible = show_setup
		difficulty_picker.visible = show_setup
		single_weapon_toggle.visible = show_setup
		uncapped_inventory_toggle.visible = show_setup
		custom_drops_toggle.visible = show_setup
		auto_pick_toggle.visible = show_setup
		mute_toggle.visible = show_setup
		volume_slider.visible = show_setup
		reset_button.visible = show_setup
		drop_filter_row.visible = show_setup
		new_run_button.visible = state == "title" and (profile.get("run") is Dictionary)
		status_label.visible = state != "playing"
		for picker_label in picker_labels:
			picker_label.visible = show_setup
	if is_instance_valid(pause_catalog):
		pause_catalog.visible = state == "paused"
		if state == "paused":
			start_button.visible = true
			for child in menu_column.get_children():
				child.visible = child == pause_catalog or child == title_label or child == start_button
			_build_pause_catalog()
		else:
			for child in menu_column.get_children():
				child.visible = true
			title_label.visible = true
			status_label.visible = state != "playing"
			start_button.visible = state in ["title", "paused", "victory", "defeat"]
			var show_setup_after_pause := state == "title" and not (profile.get("run") is Dictionary)
			for picker_label in picker_labels:
				picker_label.visible = show_setup_after_pause
			for control in [hero_picker, weapon_picker, mode_picker, difficulty_picker, single_weapon_toggle, uncapped_inventory_toggle, custom_drops_toggle, auto_pick_toggle, mute_toggle, volume_slider, reset_button, drop_filter_row]:
				control.visible = show_setup_after_pause
			new_run_button.visible = state == "title" and (profile.get("run") is Dictionary)
	if state in ["levelUp", "loot"]:
		for child in menu_column.get_children():
			child.visible = child == title_label or child == status_label or child == start_button or (state == "levelUp" and child in upgrade_buttons) or (state == "loot" and child in loot_buttons)
	call_deferred("_focus_state_action", state)

func _focus_state_action(target_state: String) -> void:
	if state != target_state:
		return
	if target_state == "playing":
		get_viewport().gui_release_focus()
		return
	var target: Control
	match target_state:
		"levelUp":
			if not upgrade_buttons.is_empty():
				target = upgrade_buttons[0]
		"loot":
			if not loot_buttons.is_empty():
				target = loot_buttons[0]
		_:
			target = start_button
	if is_instance_valid(target) and target.is_visible_in_tree() and target.focus_mode != Control.FOCUS_NONE:
		target.grab_focus()

func _update_hud() -> void:
	if not is_instance_valid(hud):
		return
	if is_instance_valid(health_bar):
		health_bar.max_value = maxf(1.0, max_hp)
		health_bar.value = clampf(hp, 0.0, max_hp)
		shield_bar.max_value = maxf(1.0, max_hp)
		shield_bar.value = clampf(player_shield, 0.0, max_hp)
		xp_bar.max_value = maxf(1.0, next_xp)
		xp_bar.value = clampf(xp, 0.0, next_xp)
	var objective_names := {"kills": "Éliminations", "xp": "Orbes d’XP", "elite": "Élites"}
	var objective := "%s %d/%d" % [objective_names.get(objective_type, objective_type), mini(objective_progress, objective_target), objective_target]
	var challenge_text := "Défis terminés"
	for challenge in run_challenges:
		if not bool(challenge.complete):
			challenge_text = "%s %d/%d" % [challenge.label, int(challenge.progress), int(challenge.target)]
			break
	var difficulty_names := {"insane": "Insane", "nightmare": "Cauchemar", "cataclysm": "Cataclysme"}
	var capacity := 10.0 * float(catalog.content.difficulties[difficulty_id].spawnCapacity)
	if mode == "infinite":
		capacity = minf(200.0, 10.0 + floorf(elapsed / 60.0 * 24.0)) * float(catalog.content.difficulties[difficulty_id].spawnCapacity)
	var occupied := 0.0
	for enemy in enemies:
		occupied += float(enemy.get_meta("spawn_weight", 1.0))
	hud.text = "%s · PV %d/%d · Bouclier %d\nNiveau %d · XP %d/%d\nVague %d · %s · %s\nDéfi : %s\nEnnemis %0.1f/%0.0f · Éliminations %d\nArsenal %d/5 · Reliques %d/5" % ["LA SENTINELLE" if hero_id == "sentinel" else "LE PÈLERIN", ceili(hp), ceili(max_hp), ceili(player_shield), level, int(xp), int(next_xp), wave, difficulty_names.get(difficulty_id, difficulty_id), objective, challenge_text, occupied, capacity, defeated, weapon_inventory.size(), relic_inventory.size()]
	var dodge_text := "Prête" if player.dodge_cooldown <= 0.0 else "Recharge %0.1f s" % player.dodge_cooldown
	var ability_text := "Esquive · %s" % dodge_text
	if hero_id == "sentinel":
		ability_text += "    Charge de cendre · %s" % ("Prête" if skill_cooldown <= 0.0 else "Recharge %0.1f s" % skill_cooldown)
	ability_label.text = ability_text
	notice_label.text = notice_text if notice_timer > 0.0 else ""
	var active_boss: ValombreEnemy
	for enemy in enemies:
		if enemy.kind == "boss":
			active_boss = enemy
			break
	boss_bar.visible = active_boss != null
	boss_name_label.visible = active_boss != null
	if active_boss:
		boss_name_label.text = str(active_boss.get_meta("display_name", "Boss")).to_upper()
		boss_bar.max_value = active_boss.max_hp
		boss_bar.value = active_boss.hp

func _find_definition(group: String, target_id: String) -> GameDefinition:
	for definition: GameDefinition in catalog.definitions.get(group, []):
		if str(definition.id) == target_id:
			return definition
	return catalog.definitions[group][0]

func _format_upgrade_bonus(definition: GameDefinition) -> String:
	var value := float(definition.values.get("bonus", 0.0)) / float(int(upgrade_ranks.get(str(definition.id), 0)) + 1)
	match str(definition.values.get("kind", "")):
		"range": return "%0.1f portée" % value
		"health": return "%d PV max" % roundi(value)
		"defense": return "%0.1f %% défense" % (value * 100.0)
		"pickup": return "%d %% ramassage" % roundi(value * 100.0)
		_: return "%d %%" % roundi(value * 100.0)

func _progress_objective(target: String) -> void:
	if objective_type == target and not objective_complete:
		objective_progress = mini(objective_target, objective_progress + 1)
		if objective_progress >= objective_target:
			objective_complete = true
			hp = minf(max_hp, hp + ceili(max_hp * 0.18))
			status_label.text = "Objectif accompli · +18 % PV"
	_progress_challenges(target)
	if target == "kills" and defeated > 0 and defeated % 10 == 0:
		_save_checkpoint(wave)

func _progress_challenges(target: String) -> void:
	var challenge_id := "elites" if target == "elite" else target
	for challenge in run_challenges:
		if str(challenge.id) != challenge_id or bool(challenge.complete):
			continue
		challenge.progress = mini(int(challenge.target), int(challenge.progress) + 1)
		if int(challenge.progress) >= int(challenge.target):
			challenge.complete = true
			profile.shards = int(profile.shards) + 1
			if profile.get("run") is Dictionary:
				profile.run.runChallenges = run_challenges.duplicate(true)
				profile.run.waveObjective = {"type": objective_type, "target": objective_target, "progress": objective_progress, "complete": objective_complete}
			_save_checkpoint(wave)
			status_label.text = "Défi accompli · +1 Éclat"
		elif profile.get("run") is Dictionary:
			profile.run.runChallenges = run_challenges.duplicate(true)
			profile.run.waveObjective = {"type": objective_type, "target": objective_target, "progress": objective_progress, "complete": objective_complete}

func _finish_run(result: String) -> void:
	if result_recorded:
		return
	result_recorded = true
	profile.bestKills = maxi(int(profile.bestKills), defeated)
	if result == "victory":
		profile.wins = int(profile.wins) + 1
		profile.shards = int(profile.shards) + 1
	profile.run = null
	_save_profile()
	_set_state(result)

func _result_summary(victory: bool) -> String:
	var total_seconds := int(elapsed)
	var time_text := "%d min %02d s" % [int(total_seconds / 60), total_seconds % 60]
	var boss_result := "vaincu" if victory else "non vaincu"
	var reward := " · Récompense : 1 Éclat du Gardien" if victory else ""
	return "Durée : %s · Vague atteinte : %d/%d · Créatures vaincues : %d · Niveau : %d · Boss : %s · Reliques : %d%s\nVictoires : %d · Éclats : %d · Meilleur score : %d" % [time_text, wave, catalog.content.waves.size(), defeated, level, boss_result, relic_inventory.size(), reward, profile.wins, profile.shards, profile.bestKills]

func _load_profile() -> void:
	var all_weapons: Array[String] = []
	for id in catalog.content.weapons.keys():
		all_weapons.append(str(id))
	var all_relics: Array[String] = []
	for item: Dictionary in catalog.content.relics:
		all_relics.append(str(item.id))
	profile.dropWeapons = all_weapons.duplicate()
	profile.dropRelics = all_relics.duplicate()
	if not FileAccess.file_exists("user://save.json"):
		return
	var file := FileAccess.open("user://save.json", FileAccess.READ)
	if file == null:
		return
	var saved: Variant = JSON.parse_string(file.get_as_text())
	if not saved is Dictionary:
		return
	var saved_schema: Variant = saved.get("schema_version", 1)
	if not saved_schema is int or int(saved_schema) < 1 or int(saved_schema) > PROFILE_SCHEMA_VERSION:
		return
	saved = _migrate_profile(saved, int(saved_schema))
	var auto_pick: Variant = saved.get("autoPickUpgrade", true)
	if auto_pick is bool:
		profile.autoPickUpgrade = auto_pick
	for key in ["wins", "bestKills", "shards"]:
		var value: Variant = saved.get(key, 0)
		if value is int and value >= 0:
			profile[key] = value
	for key in ["singleWeapon", "uncappedInventory", "customDrops"]:
		var value: Variant = saved.get(key, false)
		if value is bool:
			profile[key] = value
	var saved_hero := str(saved.get("hero", profile.hero))
	if catalog.content.heroes.has(saved_hero):
		profile.hero = saved_hero
	var saved_weapon := str(saved.get("weapon", profile.weapon))
	if catalog.content.weapons.has(saved_weapon):
		profile.weapon = saved_weapon
	var saved_mode := str(saved.get("mode", profile.mode))
	if saved_mode in ["waves", "infinite"]:
		profile.mode = saved_mode
	var saved_difficulty := str(saved.get("difficulty", profile.difficulty))
	if catalog.content.difficulties.has(saved_difficulty):
		profile.difficulty = saved_difficulty
	var saved_muted: Variant = saved.get("muted", profile.muted)
	if saved_muted is bool:
		profile.muted = saved_muted
	var saved_volume: Variant = saved.get("volume", profile.volume)
	if (saved_volume is int or saved_volume is float) and is_finite(float(saved_volume)):
		profile.volume = clampf(float(saved_volume), 0.0, 1.0)
	var saved_bestiary: Variant = saved.get("bestiary", {})
	if saved_bestiary is Dictionary:
		profile.bestiary = _sanitize_bestiary(saved_bestiary)
	for key in ["discoveredWeapons", "discoveredRelics", "discoveredSynergies"]:
		var records: Variant = saved.get(key, {})
		if records is Dictionary:
			profile[key] = _sanitize_discoveries(key, records)
	profile.dropWeapons = _sanitize_ids(saved.get("dropWeapons", all_weapons), all_weapons)
	profile.dropRelics = _sanitize_ids(saved.get("dropRelics", all_relics), all_relics)
	var saved_run: Variant = saved.get("run")
	if _checkpoint_is_valid(saved_run):
		profile.run = saved_run

func _migrate_profile(saved_profile: Dictionary, from_version: int) -> Dictionary:
	var migrated := saved_profile.duplicate(true)
	if from_version == 1:
		for key in ["hero", "weapon", "mode", "difficulty", "muted", "volume", "autoPickUpgrade", "bestiary", "discoveredWeapons", "discoveredRelics", "discoveredSynergies", "singleWeapon", "uncappedInventory", "customDrops", "dropWeapons", "dropRelics"]:
			if not migrated.has(key):
				migrated[key] = profile[key]
		var run: Variant = migrated.get("run")
		if run is Dictionary and run.get("player") is Dictionary and not run.player.has("cheatInfiniteLife"):
			run.player.cheatInfiniteLife = false
		migrated["schema_version"] = 2
	return migrated

func _sanitize_ids(value: Variant, valid_ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return valid_ids.duplicate()
	for item in value:
		var id := str(item)
		if valid_ids.has(id) and not result.has(id):
			result.append(id)
	return result

func _sanitize_discoveries(collection: String, records: Dictionary) -> Dictionary:
	var allowed: Array[String] = []
	match collection:
		"discoveredWeapons":
			for id in catalog.content.weapons:
				allowed.append(str(id))
		"discoveredRelics":
			for relic: Dictionary in catalog.content.relics:
				allowed.append(str(relic.id))
		"discoveredSynergies":
			for synergy: Dictionary in catalog.content.synergies:
				allowed.append(str(synergy.id))
	var clean := {}
	for id in records:
		if allowed.has(str(id)) and records[id] is bool and records[id]:
			clean[str(id)] = true
	return clean

func _sanitize_bestiary(records: Dictionary) -> Dictionary:
	var valid_ids: Array[String] = []
	for id in catalog.content.bestiary:
		valid_ids.append(str(id))
	for id in catalog.content.bosses:
		valid_ids.append("boss:%s" % id)
	for id in catalog.content.eliteAffixes:
		valid_ids.append("elite:%s" % id)
	var clean := {}
	for id in records:
		if not valid_ids.has(str(id)) or not records[id] is Dictionary:
			continue
		var entry: Dictionary = records[id]
		var kills: Variant = entry.get("kills", 0)
		var discovered: Variant = entry.get("discovered", false)
		if kills is int and kills >= 0 and discovered is bool:
			clean[str(id)] = {"kills": kills, "discovered": discovered}
	return clean

func _checkpoint_is_valid(checkpoint: Variant) -> bool:
	if not checkpoint is Dictionary or not (checkpoint.get("version") is int) or int(checkpoint.version) != 1:
		return false
	var checkpoint_mode := str(checkpoint.get("mode", ""))
	var checkpoint_wave_value: Variant = checkpoint.get("wave", 0)
	var checkpoint_wave := int(checkpoint_wave_value) if checkpoint_wave_value is int else 0
	var checkpoint_player: Variant = checkpoint.get("player", {})
	if not (checkpoint.get("defeated", 0) is int) or int(checkpoint.get("defeated", 0)) < 0 or not (checkpoint.get("elapsedSeconds", 0) is int) or int(checkpoint.get("elapsedSeconds", 0)) < 0:
		return false
	if checkpoint_mode not in ["waves", "infinite"] or checkpoint_wave < 1 or (checkpoint_mode == "waves" and checkpoint_wave > catalog.content.waves.size()):
		return false
	if not catalog.content.difficulties.has(str(checkpoint.get("difficulty", ""))):
		return false
	if not checkpoint_player is Dictionary:
		return false
	if not catalog.content.heroes.has(str(checkpoint_player.get("hero", ""))) or not catalog.content.weapons.has(str(checkpoint_player.get("weapon", ""))):
		return false
	var weapons: Variant = checkpoint_player.get("weaponInventory", [])
	var relics: Variant = checkpoint_player.get("inventory", [])
	var saved_position: Variant = checkpoint_player.get("position", [])
	if not weapons is Array or not relics is Array or not saved_position is Array or saved_position.size() < 2:
		return false
	for coordinate in saved_position:
		if not _is_finite_number(coordinate):
			return false
	if not (checkpoint_player.get("upgradeRanks", {}) is Dictionary):
		return false
	for field in ["hp", "maxHp", "xp", "nextXp", "level", "damageMultiplier", "attackSpeedMultiplier", "rangeBonus", "movementMultiplier", "defense", "bonusMaxHp", "projectileSize", "projectileSpeed", "pickupRangeMultiplier", "shield", "scytheSouls"]:
		if checkpoint_player.has(field) and not _is_finite_number(checkpoint_player[field]):
			return false
	if checkpoint_player.has("level") and int(checkpoint_player.level) < 1:
		return false
	if checkpoint_player.has("maxHp") and float(checkpoint_player.maxHp) <= 0.0:
		return false
	if checkpoint_player.has("hp") and (float(checkpoint_player.hp) < 0.0 or (checkpoint_player.has("maxHp") and float(checkpoint_player.hp) > float(checkpoint_player.maxHp))):
		return false
	if checkpoint_player.has("facing"):
		var facing: Variant = checkpoint_player.facing
		if not facing is Array or facing.size() < 2 or not _is_finite_number(facing[0]) or not _is_finite_number(facing[1]):
			return false
	if checkpoint_player.has("cheatInfiniteLife") and not (checkpoint_player.cheatInfiniteLife is bool):
		return false
	if checkpoint_player.has("scytheSouls") and (int(checkpoint_player.scytheSouls) < 0 or int(checkpoint_player.scytheSouls) > 5):
		return false
	var challenges: Variant = checkpoint.get("runChallenges", [])
	if not challenges is Array:
		return false
	for key in ["singleWeapon", "uncappedInventory", "customDrops"]:
		if checkpoint.has(key) and not (checkpoint[key] is bool):
			return false
	var saved_weapon_drops: Variant = checkpoint.get("dropWeapons", [])
	var saved_relic_drops: Variant = checkpoint.get("dropRelics", [])
	if checkpoint.has("dropWeapons") and not saved_weapon_drops is Array:
		return false
	if checkpoint.has("dropRelics") and not saved_relic_drops is Array:
		return false
	for id in saved_weapon_drops:
		if not catalog.content.weapons.has(str(id)):
			return false
	for id in saved_relic_drops:
		if not catalog.content.relics.any(func(entry: Dictionary) -> bool: return str(entry.id) == str(id)):
			return false
	for challenge in challenges:
		if not challenge is Dictionary or not challenge.has("id") or not _is_finite_number(challenge.get("target")) or not _is_finite_number(challenge.get("progress")) or not (challenge.get("complete") is bool):
			return false
		if str(challenge.id) not in ["kills", "elites", "xp"]:
			return false
		if float(challenge.target) <= 0.0 or float(challenge.progress) < 0.0 or float(challenge.progress) > float(challenge.target):
			return false
	if checkpoint.has("waveObjective"):
		var objective: Variant = checkpoint.waveObjective
		if not objective is Dictionary or str(objective.get("type", "")) not in ["kills", "xp", "elite"] or not _is_finite_number(objective.get("target")) or not _is_finite_number(objective.get("progress")) or not (objective.get("complete") is bool):
			return false
		if float(objective.target) <= 0.0 or float(objective.progress) < 0.0 or float(objective.progress) > float(objective.target):
			return false
	for item in weapons:
		if not item is Dictionary or not catalog.content.weapons.has(str(item.get("id", ""))):
			return false
		if item.has("level") and (not _is_finite_number(item.level) or int(item.level) < 1 or int(item.level) > 5):
			return false
		if item.has("locked") and not (item.locked is bool):
			return false
		if item.has("special") and not (item.special is bool):
			return false
	for relic in relics:
		if not relic is Dictionary or not catalog.content.relics.any(func(entry: Dictionary) -> bool: return str(entry.id) == str(relic.get("id", ""))):
			return false
		if relic.has("level") and (not _is_finite_number(relic.level) or int(relic.level) < 1 or int(relic.level) > 5):
			return false
		if relic.has("locked") and not (relic.locked is bool):
			return false
	return true

func _normalize_upgrade_ranks(saved_player: Dictionary) -> Dictionary:
	var rank_keys := ["damage", "attackSpeed", "range", "projectileSize", "projectileSpeed", "movementSpeed", "health", "defense", "pickupRange"]
	var has_rank_dictionary: bool = saved_player.get("upgradeRanks", {}) is Dictionary
	var ranks: Dictionary = saved_player.get("upgradeRanks", {}) if has_rank_dictionary else {}
	if not has_rank_dictionary:
		ranks = {
			"damage": clampi(roundi(log(maxf(1.0, float(saved_player.get("damageMultiplier", 1.0)))) / log(1.2)), 0, 10),
			"attackSpeed": clampi(roundi(log(maxf(1.0, float(saved_player.get("attackSpeedMultiplier", 1.0)))) / log(1.2)), 0, 10),
			"range": clampi(roundi(float(saved_player.get("rangeBonus", 0.0)) / 18.0), 0, 10),
			"projectileSize": clampi(roundi(log(maxf(1.0, float(saved_player.get("projectileSize", 1.0)))) / log(1.25)), 0, 10),
			"projectileSpeed": clampi(roundi(log(maxf(1.0, float(saved_player.get("projectileSpeed", 1.0)))) / log(1.2)), 0, 10),
		}
	for key in rank_keys:
		var value: Variant = ranks.get(key, 0)
		ranks[key] = clampi(int(value), 0, 10) if _is_finite_number(value) and float(value) == float(int(value)) else 0
	return ranks

func _is_finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _save_profile() -> void:
	profile.schema_version = PROFILE_SCHEMA_VERSION
	var file := FileAccess.open("user://save.json", FileAccess.WRITE)
	if file == null:
		push_warning("Unable to save profile: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(profile))

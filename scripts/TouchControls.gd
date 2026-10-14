extends Control
class_name ValombreTouchControls

signal action_button_activated
signal attack_pressed

var player: ValombrePlayer
var joystick_finger := -1
var action_fingers: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_all()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if joystick_finger < 0 and _is_joystick_region(event.position):
				joystick_finger = event.index
				_update_joystick(event.position)
			else:
				var action := _action_at(event.position)
				if not action.is_empty():
					action_fingers[event.index] = action
					_send_action(action, true)
					if action == "attack":
						attack_pressed.emit()
					action_button_activated.emit()
			accept_event()
		else:
			if event.index == joystick_finger:
				joystick_finger = -1
				player.touch_move_vector = Vector2.ZERO
				queue_redraw()
			elif action_fingers.has(event.index):
				_send_action(str(action_fingers[event.index]), false)
				action_fingers.erase(event.index)
			accept_event()
	elif event is InputEventScreenDrag and event.index == joystick_finger:
		_update_joystick(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if joystick_finger < 0 and _is_joystick_region(event.position):
				joystick_finger = -2
				_update_joystick(event.position)
				accept_event()
			else:
				var action := _action_at(event.position)
				if not action.is_empty():
					action_fingers[-1] = action
					_send_action(action, true)
					if action == "attack":
						attack_pressed.emit()
					action_button_activated.emit()
					accept_event()
		else:
			if joystick_finger == -2:
				joystick_finger = -1
				player.touch_move_vector = Vector2.ZERO
				queue_redraw()
				accept_event()
			elif action_fingers.has(-1):
				_send_action(str(action_fingers[-1]), false)
				action_fingers.erase(-1)
				accept_event()
	elif event is InputEventMouseMotion and joystick_finger == -2:
		_update_joystick(event.position)
		accept_event()

func release_all() -> void:
	for action in action_fingers.values():
		_send_action(str(action), false)
	action_fingers.clear()
	joystick_finger = -1
	if is_instance_valid(player):
		player.touch_move_vector = Vector2.ZERO
	queue_redraw()

func _scale_factor() -> float:
	return clampf(minf(size.x / 960.0, size.y / 540.0), 0.65, 1.1)

func _joystick_center() -> Vector2:
	var scale_factor := _scale_factor()
	var compact := size.x <= 380.0
	var inset := (9.0 if compact else 14.0) * scale_factor
	var bottom_inset := (10.0 if compact else 13.0) * scale_factor
	var diameter := (72.0 if compact else 88.0) * scale_factor
	return Vector2(inset + diameter * 0.5, size.y - bottom_inset - diameter * 0.5)

func _is_joystick_region(position: Vector2) -> bool:
	var half_size := (36.0 if size.x <= 380.0 else 44.0) * _scale_factor()
	var offset := position - _joystick_center()
	return absf(offset.x) <= half_size and absf(offset.y) <= half_size

func _update_joystick(position: Vector2) -> void:
	var offset := position - _joystick_center()
	var max_offset := 32.0 * _scale_factor()
	if offset.length() > max_offset:
		offset = offset.normalized() * max_offset
	var vector := offset / max_offset
	player.touch_move_vector = vector
	queue_redraw()

func _action_layout() -> Array[Dictionary]:
	var scale_factor := _scale_factor()
	var compact := size.x <= 380.0
	var button_size := 38.0 if compact else 48.0
	var gap := 4.0 if compact else 8.0
	var side_inset := 9.0 if compact else 14.0
	var bottom_inset := 10.0 if compact else 13.0
	var center_y := size.y - (bottom_inset + button_size * 0.5) * scale_factor
	var right_center := size.x - (side_inset + button_size * 0.5) * scale_factor
	var stride := (button_size + gap) * scale_factor
	var button_radius := button_size * 0.5 * scale_factor
	return [
		{"action": "attack", "label": "⚔", "center": Vector2(right_center - stride * 3.0, center_y), "radius": button_radius},
		{"action": "special", "label": "E", "center": Vector2(right_center - stride * 2.0, center_y), "radius": button_radius},
		{"action": "dodge", "label": "⇧", "center": Vector2(right_center - stride, center_y), "radius": button_radius},
		{"action": "pause", "label": "II", "center": Vector2(right_center, center_y), "radius": button_radius},
	]

func _action_at(position: Vector2) -> String:
	var nearest_action := ""
	var nearest_distance := INF
	for pad in _action_layout():
		var distance: float = position.distance_to(pad.center)
		if distance <= float(pad.radius) and distance < nearest_distance:
			nearest_action = str(pad.action)
			nearest_distance = distance
	return nearest_action

func _send_action(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)

func _draw() -> void:
	var scale_factor := _scale_factor()
	var center := _joystick_center()
	var compact := size.x <= 380.0
	var outer_radius := (36.0 if compact else 44.0) * scale_factor
	draw_circle(center, outer_radius, Color(0.04, 0.05, 0.05, 0.30))
	draw_arc(center, outer_radius, 0.0, TAU, 40, Color(0.91, 0.83, 0.65, 0.58), 2.0 * scale_factor)
	var offset := player.touch_move_vector * 32.0 * scale_factor if is_instance_valid(player) else Vector2.ZERO
	var knob_radius := (12.0 if compact else 15.0) * scale_factor
	draw_circle(center + offset, knob_radius, Color(0.82, 0.72, 0.53, 0.52))
	draw_arc(center + offset, knob_radius, 0.0, TAU, 32, Color(1.0, 0.94, 0.78, 0.78), 1.5 * scale_factor)
	for pad in _action_layout():
		var action := str(pad.action)
		var pad_center: Vector2 = pad.center
		var radius := float(pad.radius)
		var active := action_fingers.values().has(action)
		var fill := Color(0.60, 0.48, 0.29, 0.72) if active else Color(0.04, 0.05, 0.05, 0.42)
		var edge := Color(1.0, 0.88, 0.61, 0.9) if active else Color(0.91, 0.83, 0.65, 0.62)
		draw_circle(pad_center, radius, fill)
		draw_arc(pad_center, radius, 0.0, TAU, 32, edge, 2.0 * scale_factor)
		var font_size := 14.0 if size.x <= 380.0 else 17.0
		draw_string(ThemeDB.fallback_font, pad_center + Vector2(-20.0 * scale_factor, 7.0 * scale_factor), str(pad.label), HORIZONTAL_ALIGNMENT_CENTER, 40.0 * scale_factor, int(font_size * scale_factor), Color("f1e4c5"))

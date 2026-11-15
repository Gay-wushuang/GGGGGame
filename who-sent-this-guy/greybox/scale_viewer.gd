extends Node3D
## Inspection controls only. The saved scene contains the actual editable geometry.

const Spec = preload("res://greybox/scale_spec.gd")
const RouteMapPreview = preload("res://greybox/route_map_preview.gd")
const EventPreview = preload("res://greybox/event_preview.gd")
const VIEW_NAMES := ["装载总览", "车侧正交", "后门正交", "后舱俯视", "全场俯视", "车外眼高", "舱内眼高"]
const LAYOUT_NAMES := ["地面对照", "六货三人", "鸡笼叠放", "空舱四人", "三人超宽", "六货装车"]

@onready var camera: Camera3D = $ViewCamera
@onready var observer: CharacterBody3D = $Observer
@onready var person_a: StaticBody3D = $PersonA
@onready var person_b: StaticBody3D = $PersonB
@onready var cargo: Node3D = $Cargo
@onready var people: Array[StaticBody3D] = [person_a, person_b, $PersonC, $PersonD, $PersonE]

var current_view := 0
var current_layout := 0
var crouched := false
var gate_open := true
var partition_open := true
var cutaway := false
var rulers_visible := true
var focus := Spec.TRUCK_POSITION + Vector3(0, Spec.TRUCK_SIZE.y * 0.45, 0.4)
var orbit_distance := 12.0
var orbit_yaw := 0.0
var orbit_pitch := 0.5
var eye_height := Spec.STANDING_EYE
var look_yaw := 0.0
var look_pitch := 0.0
var orbit_dragging := false
var view_buttons: Array[Button] = []
var layout_buttons: Array[Button] = []
var status_label: Label
var view_label: Label
var gate_button: Button
var partition_button: Button
var shell_button: Button
var posture_button: Button
var ui: Control
var event_preview: Node3D
var event_choice: OptionButton
var event_label: Label
var route_map: PanelContainer

func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().min_size = Vector2i(960, 640)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	event_preview = EventPreview.new()
	event_preview.name = "EventPreview"
	add_child(event_preview)
	_build_ui()
	_set_door_open($Truck/Geometry/RearPortal/Door, gate_open)
	_set_door_open($Truck/Geometry/PartitionPortal/Door, partition_open)
	set_layout(0)
	set_view(0)
	get_viewport().size_changed.connect(_resize_ui)
	_resize_ui()

func set_layout(index: int) -> void:
	current_layout = index
	if index == 4 and crouched:
		toggle_posture()
	for i in cargo.get_child_count():
		var item := cargo.get_child(i) as Node3D
		item.position = Spec.cargo_position(i, index)
		item.get_node("CargoLabel").visible = index in [0, 3, 4]
	for i in people.size():
		people[i].position = Spec.person_position(i, index)
		people[i].rotation.y = Spec.person_yaw(i, index)
	_restore_people()
	if current_view >= 5:
		_enter_eye_view(person_a if current_view == 5 else person_b)
	for i in layout_buttons.size():
		layout_buttons[i].set_pressed_no_signal(index == i)
	_update_shell()
	_update_annotations()
	_update_status()

func set_view(index: int) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	orbit_dragging = false
	_restore_people()
	current_view = index
	observer.velocity = Vector3.ZERO
	camera.h_offset = 1.3
	camera.fov = 60
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	match index:
		0:
			focus = Spec.TRUCK_POSITION + Vector3(0.3, Spec.TRUCK_SIZE.y * 0.45, 0.4)
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.look_at_from_position(Spec.TRUCK_POSITION + Vector3(11.0, 8.0, 14.0), focus)
		1:
			focus = Spec.TRUCK_POSITION + Vector3(0, Spec.TRUCK_SIZE.y / 2.0, 0)
			camera.size = 9.6
			camera.look_at_from_position(focus + Vector3(12, 0, 0), focus)
		2:
			focus = Spec.TRUCK_POSITION + Vector3(0, Spec.TRUCK_SIZE.y / 2.0, 1.0)
			camera.size = 8.5
			camera.look_at_from_position(focus + Vector3(0, Spec.TRUCK_SIZE.y / 2.0 + 0.1, 14), focus)
		3:
			focus = Spec.TRUCK_POSITION + Vector3(0, Spec.BED_FLOOR, Spec.RAMP_RUN / 2.0)
			camera.size = 15.0
			camera.h_offset = 1.2
			camera.look_at_from_position(focus + Vector3(0, 12, 0), focus, Vector3.FORWARD)
		4:
			focus = Vector3.ZERO
			camera.size = Spec.SITE_SIZE.y + 8
			camera.h_offset = 0
			camera.look_at_from_position(Vector3(0, 100, 0), focus, Vector3.FORWARD)
		5, 6:
			_enter_eye_view(person_a if index == 5 else person_b)
	var offset := camera.position - focus
	orbit_distance = offset.length()
	orbit_yaw = atan2(offset.x, offset.z)
	orbit_pitch = asin(clampf(offset.y / orbit_distance, -1.0, 1.0))
	for i in view_buttons.size():
		view_buttons[i].set_pressed_no_signal(index == i)
	view_label.text = "%02d  /  %s" % [index + 1, VIEW_NAMES[index]]
	_update_shell()
	_update_annotations()
	_update_status()
	_resize_ui()

func _restore_people() -> void:
	for i in people.size():
		var active := i < Spec.person_count(current_layout)
		people[i].visible = active
		people[i].collision_layer = 1 if active else 0

func _enter_eye_view(person: StaticBody3D) -> void:
	person.visible = false
	person.collision_layer = 0
	observer.position = person.position
	var height: float = person.get_meta("height_m")
	eye_height = person.get_meta("eye_height_m")
	var collider := observer.get_node("Collision") as CollisionShape3D
	(collider.shape as CapsuleShape3D).height = height
	collider.position.y = height / 2.0
	look_yaw = person.rotation.y
	look_pitch = 0.0
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 75.0
	camera.h_offset = 0
	_update_eye_camera()

func _physics_process(delta: float) -> void:
	if current_view < 5:
		return
	var movement := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var direction := Basis(Vector3.UP, look_yaw) * Vector3(movement.x, 0, movement.y).normalized()
	var speed := 4.0
	if current_view == 6 and crouched:
		speed = 2.0
	elif Input.is_physical_key_pressed(KEY_SHIFT):
		speed = 6.0
	var acceleration := 16.0 if not movement.is_zero_approx() else 20.0
	observer.velocity.x = move_toward(observer.velocity.x, direction.x * speed, acceleration * delta)
	observer.velocity.z = move_toward(observer.velocity.z, direction.z * speed, acceleration * delta)
	if observer.is_on_floor():
		observer.velocity.y = 0
	else:
		observer.velocity.y -= 9.8 * delta
	observer.move_and_slide()
	if observer.position.y < -4 or absf(observer.position.x) > Spec.SITE_SIZE.x / 2.0 or absf(observer.position.z) > Spec.SITE_SIZE.y / 2.0:
		_enter_eye_view(person_a if current_view == 5 else person_b)
		observer.velocity = Vector3.ZERO
	_update_eye_camera()

func _update_eye_camera() -> void:
	camera.position = observer.position + Vector3(0, eye_height, 0)
	camera.rotation = Vector3(look_pitch, look_yaw, 0)

func _input(event: InputEvent) -> void:
	# Releases must also work when the pointer crosses a UI panel during a drag.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		orbit_dragging = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_7:
			set_view(event.physical_keycode - KEY_1)
		match event.physical_keycode:
			KEY_N: route_map.visible = not route_map.visible
			KEY_8: set_preview_event((event_preview.selected + 1) % EventPreview.NAMES.size())
			KEY_9: set_preview_event(0)
			KEY_L: set_layout((current_layout + 1) % LAYOUT_NAMES.size())
			KEY_C: toggle_posture()
			KEY_T: toggle_gate()
			KEY_P: toggle_partition()
			KEY_O: toggle_shell()
			KEY_M: toggle_rulers()
			KEY_G: $Site/MeterGrid.visible = not $Site/MeterGrid.visible
			KEY_H: ui.visible = not ui.visible
			KEY_R: set_view(current_view)
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				orbit_dragging = false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if current_view >= 5:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
			else:
				orbit_dragging = event.pressed
		if current_view < 5 and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom(0.9)
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(1.1)
	if event is InputEventMouseMotion:
		if current_view >= 5 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			look_yaw -= deg_to_rad(event.relative.x * 0.12)
			look_pitch = clampf(look_pitch - deg_to_rad(event.relative.y * 0.12), deg_to_rad(-85), deg_to_rad(85))
		elif orbit_dragging:
			orbit_yaw -= event.relative.x * 0.007
			orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.007, 0.015, PI / 2.0 - 0.01)
			_orbit()

func _zoom(factor: float) -> void:
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.size = clampf(camera.size * factor, 2.8, 200)
	else:
		orbit_distance = clampf(orbit_distance * factor, 4.0, 100)
		_orbit()

func _orbit() -> void:
	var offset := Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch)) * orbit_distance
	camera.look_at_from_position(focus + offset, focus)

func toggle_gate() -> void:
	gate_open = not gate_open
	_set_door_open($Truck/Geometry/RearPortal/Door, gate_open)
	gate_button.text = "T  后部装卸门  /  %s" % ("打开" if gate_open else "关闭")
	_update_status()

func toggle_partition() -> void:
	partition_open = not partition_open
	_set_door_open($Truck/Geometry/PartitionPortal/Door, partition_open)
	partition_button.text = "P  前后舱隔断门  /  %s" % ("打开" if partition_open else "关闭")
	_update_status()

func _set_door_open(door: StaticBody3D, opened: bool) -> void:
	door.visible = not opened
	door.collision_layer = 0 if opened else 1

func toggle_shell() -> void:
	cutaway = not cutaway
	_update_shell()
	_update_annotations()
	_update_status()

func _update_shell() -> void:
	$Truck/Geometry/RoofReference.visible = not cutaway and current_view != 3
	$Truck/Geometry/SideRight/Mesh.visible = not cutaway
	# The over-width study needs an unobstructed rear elevation of all complete models.
	for wall in [$Truck/Geometry/RearPortal/JambLeft/Mesh, $Truck/Geometry/RearPortal/JambRight/Mesh, $Truck/Geometry/RearPortal/Header/Mesh]:
		wall.visible = not (cutaway and current_layout == 4)
	shell_button.text = "O  外壳剖视  /  %s" % ("开启" if cutaway else "关闭")

func toggle_rulers() -> void:
	rulers_visible = not rulers_visible
	_update_annotations()

func _update_annotations() -> void:
	for rulers in get_tree().get_nodes_in_group("scale_rulers"):
		if $Site.is_ancestor_of(rulers):
			rulers.visible = rulers_visible and current_view == 4
		elif $Truck.is_ancestor_of(rulers):
			rulers.visible = rulers_visible and current_view < 4
			for measure in rulers.get_children():
				measure.visible = current_view in measure.get_meta("views", [])
				if measure.name == "FivePersonWidth":
					measure.visible = measure.visible and current_layout == 4
				if current_layout == 4 and cutaway and current_view == 2:
					measure.visible = measure.visible and measure.get_meta("width_study", false)
		elif rulers.get_parent() == self:
			rulers.visible = rulers_visible and current_view == 2
		else:
			var sample_visible := rulers.get_parent() == person_a or cutaway and current_layout in [0, 5]
			rulers.visible = rulers_visible and current_view == 1 and sample_visible and current_layout != 4
	for label in get_tree().get_nodes_in_group("scale_labels"):
		var pixel_size: float = label.get_meta("base_pixel_size")
		label.pixel_size = pixel_size * 1.4 if current_view == 3 else pixel_size
		if $Site.is_ancestor_of(label):
			label.visible = current_view == 4 or label == $Site/LoadingZone/Label and current_view == 0
			label.pixel_size = maxf(pixel_size * 5, 0.038) if current_view == 4 else pixel_size
		elif $Cargo.is_ancestor_of(label):
			label.visible = current_layout in [0, 3, 4] and current_view == 0
		elif label.name == "PersonLabel":
			var side_sample := label.get_parent() == person_a or label.get_parent() == person_b and cutaway and current_layout in [0, 5]
			label.visible = current_view < 4 and (current_view != 1 or side_sample)

func toggle_posture() -> void:
	crouched = not crouched
	var height: float = Spec.CROUCH_HEIGHT if crouched else Spec.PERSON_HEIGHT
	var eye: float = Spec.CROUCHING_EYE if crouched else Spec.STANDING_EYE
	var profile: Dictionary = Spec.person_profile(crouched)
	var body := person_b.get_node("Body") as MeshInstance3D
	(body.mesh as CapsuleMesh).height = profile.body_height
	body.position.y = profile.body_y
	person_b.get_node("Head").position.y = profile.head_y
	for suffix in ["Left", "Right"]:
		var arm := person_b.get_node("Arm" + suffix) as MeshInstance3D
		(arm.mesh as CapsuleMesh).height = profile.arm_height
		arm.position.y = profile.arm_y
		person_b.get_node("Hand" + suffix).position.y = profile.hand_y
		var leg := person_b.get_node("Leg" + suffix) as MeshInstance3D
		(leg.mesh as CapsuleMesh).height = profile.leg_height
		leg.position.y = profile.leg_y
	person_b.get_node("FrontMarker").position.y = profile.body_y
	person_b.get_node("EyePoint").position.y = eye
	var collider := person_b.get_node("Collision") as CollisionShape3D
	(collider.shape as CapsuleShape3D).height = height
	collider.position.y = height / 2.0
	person_b.set_meta("height_m", height)
	person_b.set_meta("eye_height_m", eye)
	var measure := person_b.get_node("Dimensions/HeightMeasure")
	var height_line := measure.get_node("Line") as MeshInstance3D
	(height_line.mesh as CylinderMesh).height = height
	height_line.position.y = height / 2.0
	measure.get_node("Line3").position.y = height
	measure.get_node("Label").position.y = height + 0.15
	measure.get_node("Label").text = "%.2f m" % height
	var eye_measure := person_b.get_node("Dimensions/EyeMeasure") as Node3D
	eye_measure.position.y = eye
	eye_measure.get_node("Label").text = "眼高 %.2f m" % eye
	var title := person_b.get_node("PersonLabel") as Label3D
	title.position.y = height + 0.3
	title.text = "B"
	posture_button.text = "C  人物 B  /  %s" % ("蹲姿 0.85 m" if crouched else "站姿 1.20 m")
	if current_view == 6:
		_enter_eye_view(person_b)
	_update_status()

func set_preview_event(index: int) -> void:
	event_preview.show_event(index)
	event_choice.select(index)
	event_label.text = EventPreview.NOTES[index]
	if index > 0:
		set_layout(1)
		set_view(0)
		focus = Spec.TRUCK_POSITION + Vector3(0, 3.5, 0)
		var event_camera := Vector3(15, 10, 18)
		if index == 3:
			focus = Spec.TRUCK_POSITION + Vector3(1, 1.8, 3.0)
			event_camera = Vector3(10, 5, 14)
		elif index == 5:
			focus = Spec.TRUCK_POSITION + Vector3(0, 0.9, 0)
			event_camera = Vector3(9, 3.5, 10)
		camera.look_at_from_position(Spec.TRUCK_POSITION + event_camera, focus)
		var offset := camera.position - focus
		orbit_distance = offset.length()
		orbit_yaw = atan2(offset.x, offset.z)
		orbit_pitch = asin(offset.y / orbit_distance)
		view_label.text = "事件预览 / " + EventPreview.NAMES[index]
	else:
		set_view(current_view)

func _update_status() -> void:
	if not is_instance_valid(status_label):
		return
	var text := "空舱与人物 / 六货在地面\n后舱净底面积 %.2f m²\nB 在驾驶区，可步行通过隔断门" % (Spec.BED_SIZE.x * Spec.BED_SIZE.y)
	if current_layout == 1:
		text = "后舱 3 人 + 6 货 / 196 kg\n中央通路最窄 1.15 m\n视觉宽0.96 m / 碰撞 Ø0.80 m"
	elif current_layout == 2:
		text = "两个鸡笼叠高 1.40 m\n鱼缸与炸弹保持落地\n堆放只作空间对照，非玩法许可"
	elif current_layout == 3:
		text = "空舱 4 人 / 六货移回地面\n静态占位与眼高步行对照\n正式支持 1～4 人"
	elif current_layout == 4:
		text = "三人横排超宽测试\n3 × 0.96 = 2.88 > 净宽2.70 m\n此预置故意显示0.18 m超宽，不可用布局\n3 后门视角 + O 剖视看完整轮廓"
	elif current_layout == 5:
		text = "六货全部装车 / 196 kg\n后舱无人，A 车外、B 驾驶区\n两侧错配装载，中央通路最窄1.15 m"
	text += "\n隔断门 %s / 后门 %s" % ["开" if partition_open else "关", "开" if gate_open else "关"]
	text += "\n道路总宽6 m，单道3 m与车等宽\n直道单侧余宽0，弯道需借对向空间\n关卡需设会车湾，禁止常规双车硬挤"
	if cutaway or current_view == 3:
		text += "\n剖视只隐藏显示，墙体碰撞保留"
	status_label.text = text

func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _text(parent: Node, text: String, font_size := 14, color := Color("e4ece9")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable, toggle := false) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = toggle
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 33
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "InspectionUI"
	add_child(layer)
	ui = Control.new()
	ui.name = "Interface"
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var theme := Theme.new()
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	theme.default_font = system_font
	theme.default_font_size = 14
	theme.set_stylebox("panel", "PanelContainer", _panel_style(Color(0.09, 0.16, 0.2, 0.94)))
	theme.set_stylebox("normal", "Button", _panel_style(Color("304b58")))
	theme.set_stylebox("hover", "Button", _panel_style(Color("476774")))
	theme.set_stylebox("pressed", "Button", _panel_style(Color("177d78")))
	theme.set_color("font_color", "Button", Color("eef5ef"))
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	ui.theme = theme
	var header := PanelContainer.new()
	header.position = Vector2(18, 18)
	header.custom_minimum_size.x = 330
	ui.add_child(header)
	var header_box := VBoxContainer.new()
	header.add_child(header_box)
	_text(header_box, "D E L I V E R Y   /   0 4", 12, Color("94c8bd"))
	_text(header_box, "这货谁送的？", 25)
	_text(header_box, "1 单位 = 1 米  ·  Y 向上  ·  前向 -Z", 13)
	_text(header_box, "送货重构 · 比例与事件概念 · 2026-11-15", 12, Color("acbfbe"))
	var panel := PanelContainer.new()
	panel.name = "FactsPanel"
	ui.add_child(panel)
	panel.anchor_left = 1
	panel.anchor_right = 1
	panel.anchor_bottom = 1
	panel.offset_left = -298
	panel.offset_right = -18
	panel.offset_top = 18
	panel.offset_bottom = -124
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	view_label = _text(box, "", 19)
	_button(box, "N  查看路线抉择草案", func(): route_map.visible = not route_map.visible)
	_text(box, "人物与车辆", 13, Color("94c8bd"))
	_text(box, "人物  高1.20 / 蹲高0.85 m · 1.5头身\n视觉宽0.96 m / 碰撞 Ø0.80 m\n头径0.80 m · 眼高1.02 / 0.70 m\n车身  长8.80 × 宽3.00 × 高3.50 m\n后舱  净长5.80 × 净宽2.70 × 净高2.68 m\n地板0.70 m · 实体顶棚0.12 m\n隔断门1.10 × 1.90 / 后门1.80 × 2.00 m", 13)
	_text(box, "六件货物 / 各2件 / 总196 kg", 13, Color("94c8bd"))
	_text(box, "鸡笼  .80 × .70 × .60 m / 18 kg\n鱼缸  .90 × .75 × .65 m / 35 kg\n炸弹  .65 m立方包络 / 45 kg\n尺寸按宽 × 高 × 长", 13)
	_text(box, "突发事件概念演示", 13, Color("94c8bd"))
	event_choice = OptionButton.new()
	for title in EventPreview.NAMES:
		event_choice.add_item(title)
	event_choice.item_selected.connect(set_preview_event)
	box.add_child(event_choice)
	event_label = _text(box, EventPreview.NOTES[0], 12, Color("efd396"))
	_button(box, "8  下一个事件  /  9  清除", func(): set_preview_event((event_preview.selected + 1) % EventPreview.NAMES.size()))
	_text(box, "动画仅用于预览构图与辨识；订单、驾驶、事件反制和经营系统待实现。", 12, Color("acbfbe"))
	var layouts := GridContainer.new()
	layouts.columns = 2
	box.add_child(layouts)
	for i in LAYOUT_NAMES.size():
		var button := _button(layouts, LAYOUT_NAMES[i], set_layout.bind(i), true)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_stylebox_override("normal", _compact_style(Color("304b58")))
		button.add_theme_stylebox_override("hover", _compact_style(Color("476774")))
		button.add_theme_stylebox_override("pressed", _compact_style(Color("177d78")))
		layout_buttons.append(button)
	status_label = _text(box, "", 13, Color("efd396"))
	gate_button = _button(box, "T  后部装卸门  /  打开", toggle_gate)
	partition_button = _button(box, "P  前后舱隔断门  /  打开", toggle_partition)
	shell_button = _button(box, "O  外壳剖视  /  关闭", toggle_shell)
	posture_button = _button(box, "C  人物 B  /  站姿 1.20 m", toggle_posture)
	_button(box, "M  尺寸标记开关", toggle_rulers)
	_text(box, "场地100 × 80 m · 装卸区各14 × 14 m\n直路30 m · 总宽6 m / 单道3 m\n左右弯中线R20 m · 凸起0.12 m", 13)
	_text(box, "构造占位\n轮距2.70 m / 轴距5.80 m / 轮半径0.35 m\n后斜板伸出2.10 m，板后至标线约1.00 m\n切向车身框用于静态转弯空间对照", 12, Color("acbfbe"))
	var bottom := PanelContainer.new()
	ui.add_child(bottom)
	bottom.anchor_top = 1
	bottom.anchor_right = 1
	bottom.anchor_bottom = 1
	bottom.offset_left = 18
	bottom.offset_right = -18
	bottom.offset_top = -108
	bottom.offset_bottom = -18
	var controls := VBoxContainer.new()
	bottom.add_child(controls)
	var views := HBoxContainer.new()
	controls.add_child(views)
	for i in VIEW_NAMES.size():
		var button := _button(views, "%d  %s" % [i + 1, VIEW_NAMES[i]], set_view.bind(i), true)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", _compact_style(Color("304b58")))
		button.add_theme_stylebox_override("hover", _compact_style(Color("476774")))
		button.add_theme_stylebox_override("pressed", _compact_style(Color("177d78")))
		view_buttons.append(button)
	_text(controls, "右键环绕 / 眼高观察 · 滚轮缩放 · WASD 步行 · Shift 加速 · L 摆放 · 8 事件 · 9 清除 · P 隔断门 · T 后门 · O 剖视 · G 网格 · R 复位 · H 界面 · Esc 释放鼠标", 12, Color("acbfbe"))

	route_map = RouteMapPreview.new()
	ui.add_child(route_map)
	route_map.visible = false

func _compact_style(color: Color) -> StyleBoxFlat:
	var style := _panel_style(color)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _resize_ui() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var width := viewport_size.x
	for i in view_buttons.size():
		view_buttons[i].text = str(i + 1) if width < 1100 else "%d  %s" % [i + 1, VIEW_NAMES[i]]
		view_buttons[i].tooltip_text = VIEW_NAMES[i]
	if current_view == 1:
		camera.size = maxf(9.6, (Spec.TRUCK_SIZE.z + 2.0) * viewport_size.y / maxf(width - 350.0, 400.0))
		camera.h_offset = 150.0 * camera.size / viewport_size.y
	if current_view == 3:
		camera.size = maxf(15.0, (Spec.TRUCK_SIZE.z + Spec.RAMP_RUN + 1.0) * viewport_size.y / maxf(viewport_size.y - 200.0, 400.0))
		camera.h_offset = 150.0 * camera.size / viewport_size.y
	if current_view == 4:
		var usable_width := maxf(width - 350.0, 400.0)
		var usable_height := maxf(viewport_size.y - 200.0, 400.0)
		camera.size = maxf((Spec.SITE_SIZE.y + 8.0) * viewport_size.y / usable_height,
			(Spec.SITE_SIZE.x + 8.0) * viewport_size.y / usable_width)
		camera.h_offset = 150.0 * camera.size / viewport_size.y

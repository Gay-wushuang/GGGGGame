extends Node3D
## Art-direction loops only: no cargo damage, physics authority, economy or event AI.
const Spec = preload("res://greybox/scale_spec.gd")
const NAMES := ["无事件", "UFO 低重力", "龙卷风", "骑牛飞车党", "母牛雨", "哈吉米吸轮胎"]
const NOTES := [
	"比例观察模式。事件按钮播放概念演示，尚未接入正式玩法。",
	"预兆：光束与低频声。母牛被吸走；正式玩法施加向上外力减轻车重，质量与惯量保留。反制：减速固定关键货，驶离光束或进入遮蔽。",
	"预兆：风向、尘带与警报。母牛沿风柱被卷飞。反制：避开风眼、靠掩体停车并固定货物。",
	"预兆：牛铃和后视警报。骑牛盗贼靠近车尾，拔红色车销后尝试偷货。反制：鸣笛打断接近，停车复位车销、关门固定。",
	"预兆：地面落点光圈。母牛分波落下。反制：看落点绕行，或进入棚下等待。",
	"预兆：路边喵声。哈吉米靠近后吸附轮胎。正式每次最多两只。反制：停车抱走，或用鱼干诱离。",
]
var selected := 0
var elapsed := 0.0
var content: Node3D
var actors: Array[Node3D] = []
var material_cache: Dictionary = {}
var vehicle_lift := 0.0

func _ready() -> void:
	position = Spec.TRUCK_POSITION
	content = Node3D.new()
	content.name = "ConceptGeometry"
	add_child(content)

func _mat(color: Color) -> StandardMaterial3D:
	var key := str(color)
	if not material_cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.75
		if color.a < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		material_cache[key] = mat
	return material_cache[key]

func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = _mat(color)
	parent.add_child(node)
	return node

func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, at, color)

func _ball(parent: Node3D, radius: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _mesh(parent, mesh, at, color)

func _cone(parent: Node3D, bottom: float, top: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 32
	return _mesh(parent, mesh, at, color)

func _cow(parent: Node3D) -> Node3D:
	var cow := Node3D.new()
	parent.add_child(cow)
	_box(cow, Vector3(0.72, 0.62, 1.35), Vector3(0, 0.78, 0), Color("f2f0df"))
	_box(cow, Vector3(0.44, 0.04, 0.58), Vector3(0.1, 1.10, 0.16), Color("343841"))
	_box(cow, Vector3(0.03, 0.34, 0.48), Vector3(0.37, 0.8, -0.18), Color("343841"))
	for x in [-0.23, 0.23]:
		for z in [-0.42, 0.42]:
			_box(cow, Vector3(0.16, 0.48, 0.17), Vector3(x, 0.24, z), Color("343841"))
	_box(cow, Vector3(0.58, 0.54, 0.6), Vector3(0, 1.02, -0.75), Color("f2f0df"))
	_box(cow, Vector3(0.62, 0.23, 0.22), Vector3(0, 0.9, -1.04), Color("e2a8a0"))
	for x in [-0.3, 0.3]:
		_cone(cow, 0.08, 0.0, 0.28, Vector3(x, 1.38, -0.73), Color("e9c178"))
		_ball(cow, 0.045, Vector3(x * 0.65, 1.13, -1.055), Color("263139"))
	return cow

func _cat(parent: Node3D) -> Node3D:
	var cat := Node3D.new()
	parent.add_child(cat)
	_ball(cat, 0.24, Vector3(0, 0.24, 0), Color("e6aa58"))
	for x in [-0.15, 0.15]:
		_cone(cat, 0.12, 0.0, 0.24, Vector3(x, 0.48, 0), Color("e6aa58"))
		_ball(cat, 0.035, Vector3(x * 0.7, 0.29, 0.215), Color("263139"))
	_ball(cat, 0.032, Vector3(0, 0.2, 0.24), Color("d37677"))
	return cat

func show_event(index: int) -> void:
	if vehicle_lift > 0:
		get_parent().get_node("Truck").position = Spec.TRUCK_POSITION
		get_parent().set_layout(get_parent().current_layout)
	vehicle_lift = 0.0
	selected = clampi(index, 0, 5)
	elapsed = 0.0
	actors.clear()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	match selected:
		1:
			_cone(content, 2.3, 1.0, 0.55, Vector3(0, 7.1, 0), Color("7a8a9e"))
			_ball(content, 1.05, Vector3(0, 7.5, 0), Color(0.3, 0.8, 0.9, 0.65)).scale.y = 0.5
			_cone(content, 3.0, 0.4, 6.6, Vector3(0, 3.6, 0), Color(0.25, 0.95, 0.7, 0.14))
			for i in 2:
				actors.append(_cow(content))
		2:
			var funnel := Node3D.new()
			funnel.position = Vector3(5.0, 0, 0)
			content.add_child(funnel)
			for i in 10:
				_cone(funnel, 0.3 + i * 0.19, 0.5 + i * 0.19, 0.52,
					Vector3(0, 0.4 + i * 0.58, 0), Color(0.42, 0.47, 0.52, 0.5))
			for i in 3:
				actors.append(_cow(content))
		3:
			var cow := _cow(content)
			actors.append(cow)
			_box(cow, Vector3(0.35, 0.25, 0.35), Vector3(0, 1.23, 0), Color("8e5eaa"))
			_ball(cow, 0.32, Vector3(0, 1.63, 0), Color("f2f0df"))
			_box(cow, Vector3(0.7, 0.08, 0.08), Vector3(-0.35, 1.25, 0), Color("8e5eaa"))
			var pin := _box(content, Vector3(0.55, 0.12, 0.12), Vector3(0.5, 1.25, 4.52), Color("ed6459"))
			actors.append(pin)
			var stolen := _box(content, Vector3(0.7, 0.6, 0.6), Vector3(0, 0, 0), Color("d89d35"))
			actors.append(stolen)
		4:
			for i in 8:
				actors.append(_cow(content))
				_cone(content, 0.95, 0.95, 0.025, Vector3(-4.5 + (i % 4) * 3.0, 0.04, -4.0 + (i / 4) * 7.0), Color(1, 0.55, 0.25, 0.35))
		5:
			for i in 2:
				actors.append(_cat(content))

func _process(delta: float) -> void:
	elapsed += delta
	match selected:
		1:
			# Pure visual lift; real mass, inertia and physics forces are not simulated here.
			vehicle_lift = 0.12 + 0.18 * (sin(elapsed * 0.8) + 1.0)
			var viewer = get_parent()
			viewer.get_node("Truck").position = Spec.TRUCK_POSITION + Vector3.UP * vehicle_lift
			for i in viewer.cargo.get_child_count():
				var base := Spec.cargo_position(i, viewer.current_layout)
				viewer.cargo.get_child(i).position = base + (Vector3.UP * vehicle_lift if viewer.current_layout in [1, 2, 5] else Vector3.ZERO)
			for i in viewer.people.size():
				var base := Spec.person_position(i, viewer.current_layout)
				viewer.people[i].position = base + (Vector3.UP * vehicle_lift if base.y >= Spec.BED_FLOOR else Vector3.ZERO)
			for i in actors.size():
				var phase := fmod(elapsed * 0.17 + i * 0.45, 1.0)
				actors[i].position = Vector3(2.2 * cos(i * PI), 0.2 + phase * 5.4, 0.7)
				actors[i].rotation = Vector3(0, elapsed * 0.5, phase * 0.6)
		2:
			for i in actors.size():
				var phase := elapsed * 1.3 + i * TAU / 3.0
				var y := 1.4 + fmod(elapsed * 0.6 + i * 1.7, 4.5)
				actors[i].position = Vector3(5 + cos(phase) * 2, y, sin(phase) * 2)
				actors[i].rotation = Vector3(phase * 0.5, -phase, 0.6)
		3:
			var phase := fmod(elapsed, 9.0)
			actors[0].position = Vector3(2.6, 0.04, lerpf(-4, 4.7, minf(phase / 4.0, 1.0)))
			actors[0].rotation.y = PI
			actors[1].position.x = 0.5 + clampf((phase - 4.0) / 1.8, 0, 1) * 1.8
			actors[2].visible = phase > 5.8
			actors[2].position = Vector3(2.4 + maxf(phase - 6, 0) * 0.6, 1.3, 4.8)
		4:
			for i in actors.size():
				var phase := fmod(elapsed * 0.23 + i * 0.13, 1.0)
				actors[i].position = Vector3(-4.5 + (i % 4) * 3.0, maxf(0.05, 9.5 * (1.0 - phase * phase * 1.25)), -4.0 + (i / 4) * 7.0)
				actors[i].rotation = Vector3(phase * 1.4, i * 0.7, phase * 0.5)
		5:
			for i in actors.size():
				var side := -1.0 if i % 2 == 0 else 1.0
				var target := Vector3(side * (Spec.TRACK / 2.0 + Spec.TIRE_WIDTH / 2.0 + 0.12), 0.14, Spec.FRONT_AXLE_Z if i < 2 else Spec.FRONT_AXLE_Z + Spec.WHEELBASE)
				var start := target + Vector3(side * 3.0, 0, 1.0)
				actors[i].position = start.lerp(target, clampf(fmod(elapsed, 8.0) / 2.4, 0, 1))
				actors[i].rotation.y = side * PI / 2.0

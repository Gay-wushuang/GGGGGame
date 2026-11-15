extends SceneTree
## Run headless for geometry checks, or with -- --capture to save rendered review images.
const Spec = preload("res://greybox/scale_spec.gd")
var failures: Array[String] = []
var checks := 0
var capture := false
var output := ""

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	output = ProjectSettings.globalize_path("res://../previews/v0.4")
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func body_bounds(body: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in body.get_children():
		if child is MeshInstance3D:
			var box: AABB = child.transform * child.get_aabb()
			result = box if first else result.merge(box)
			first = false
	return result

func meshes_bounds(node: Node3D, relative_to: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = relative_to.global_transform.affine_inverse() * child.global_transform * child.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

func shot(name: String) -> void:
	if capture:
		await process_frame
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png(output.path_join(name + ".png"))
		check(result == OK, "Save screenshot " + name)

func doorway_hits(scene: Node3D, z: float) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = Spec.PERSON_DIAMETER / 2.0 - 0.01
	shape.height = Spec.PERSON_HEIGHT - 0.04
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, Spec.TRUCK_POSITION + Vector3(0, Spec.BED_FLOOR + Spec.PERSON_HEIGHT / 2.0 + 0.01, z))
	query.collision_mask = 1
	var exclusions: Array[RID] = []
	for person in scene.people:
		exclusions.append(person.get_rid())
	query.exclude = exclusions
	return scene.get_world_3d().direct_space_state.intersect_shape(query)

func _run() -> void:
	var packed := load("res://greybox/scale_validation.tscn") as PackedScene
	check(packed != null, "Scene loads")
	if packed == null:
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	check(is_equal_approx(Spec.TRUCK_SIZE.x, 3.0), "Truck specification width 3 m")
	check(is_equal_approx(Spec.ROAD_WIDTH, 6.0), "Road specification total width 6 m")
	check(is_equal_approx(Spec.PERSON_HEIGHT / Spec.HEAD_DIAMETER, 1.5), "Character 1.5 heads")
	var truck: Node3D = scene.get_node("Truck")
	var geometry: Node3D = truck.get_node("Geometry")
	var truck_bounds := meshes_bounds(geometry, truck)
	check(is_equal_approx(truck_bounds.size.x, 3.0), "Actual truck geometry including wheels is 3 m wide")
	check(is_equal_approx(truck_bounds.end.y, 3.5), "Actual roof top is 3.5 m")
	var person: Node3D = scene.get_node("PersonA")
	var visual := body_bounds(person)
	check(absf(visual.size.y - 1.2) < 0.001, "Actual standing visual height 1.2 m")
	check(absf(visual.size.x - 0.96) < 0.001, "Actual standing visual width .96 m")
	check(absf(visual.position.y) < 0.001, "Character feet on ground")
	var cargo: Node3D = scene.get_node("Cargo")
	check(cargo.get_child_count() == 6, "Six cargo instances")
	var total := 0.0
	for item in cargo.get_children():
		total += float(item.get_meta("mass_kg"))
		var size: Vector3 = item.get_meta("size_m")
		var box: AABB = body_bounds(item) if item.get_node_or_null("Geometry") is MeshInstance3D else meshes_bounds(item, item)
		check(box.size.x <= size.x + 0.01 and box.size.y <= size.y + 0.01 and box.size.z <= size.z + 0.01, "Cargo fits advertised envelope: " + item.name)
	check(is_equal_approx(total, 196), "Cargo total mass 196 kg")
	for layout in 6:
		scene.set_layout(layout)
		check(scene.current_layout == layout, "Layout selection " + str(layout))
		for i in 5:
			var sample: StaticBody3D = scene.people[i]
			check(sample.visible == (i < Spec.person_count(layout)), "Layout participant visibility %d/%d" % [layout, i])
		if layout in [1, 5]:
			var boxes: Array[AABB] = []
			for item in cargo.get_children():
				var size: Vector3 = item.get_meta("size_m")
				var box := AABB(item.position - Spec.TRUCK_POSITION - Vector3(size.x / 2, 0, size.z / 2), size)
				check(box.position.x >= -Spec.BED_SIZE.x / 2 - 0.001 and box.end.x <= Spec.BED_SIZE.x / 2 + 0.001, "Cargo inside cabin width " + item.name)
				check(box.position.z >= Spec.BED_FRONT and box.end.z <= Spec.BED_REAR, "Cargo inside cabin length " + item.name)
				for other in boxes:
					check(not box.intersects(other), "Cargo separated in layout " + str(layout))
				boxes.append(box)
			if layout == 1:
				for i in [1, 2, 3]:
					var sample: Node3D = scene.people[i]
					var box := truck.global_transform.affine_inverse() * sample.global_transform * body_bounds(sample)
					for other in boxes:
						check(not box.intersects(other), "Crew avoids cargo in loaded layout: " + sample.name)
	scene.set_layout(0)
	scene.toggle_posture()
	check(absf(body_bounds(scene.person_b).size.y - 0.85) < 0.001, "Actual crouch height .85 m")
	check(is_equal_approx(float(scene.person_b.get_meta("eye_height_m")), 0.70), "Crouched eye .70 m")
	scene.toggle_posture()
	check(absf(body_bounds(scene.person_b).size.y - 1.2) < 0.001, "Standing restored")
	check(is_equal_approx(scene.observer.get_node("Collision").shape.radius, 0.4), "Observer uses .8 m collision diameter")
	await physics_frame
	check(doorway_hits(scene, Spec.PARTITION_Z).is_empty(), "Standing body fits open partition door")
	check(doorway_hits(scene, Spec.TRUCK_SIZE.z / 2.0 - Spec.WALL_THICKNESS / 2.0).is_empty(), "Standing body fits open rear door")
	scene.toggle_partition()
	scene.toggle_gate()
	await physics_frame
	check(not doorway_hits(scene, Spec.PARTITION_Z).is_empty(), "Closed partition door blocks body")
	check(not doorway_hits(scene, Spec.TRUCK_SIZE.z / 2.0 - Spec.WALL_THICKNESS / 2.0).is_empty(), "Closed rear door blocks body")
	scene.toggle_partition()
	scene.toggle_gate()
	for window_size in [Vector2i(1440, 900), Vector2i(960, 640)]:
		root.size = window_size
		await process_frame
		for view in 7:
			scene.set_view(view)
			check(scene.camera.position.is_finite(), "Finite camera %s/%d" % [window_size, view])
			check(scene.camera.size > 0, "Positive framing %s/%d" % [window_size, view])
	root.size = Vector2i(1440, 900)
	scene.set_layout(1)
	scene.set_view(3)
	await shot("01_loaded_cabin")
	scene.set_layout(0)
	scene.set_view(1)
	await shot("02_character_scale")
	for event in range(1, 6):
		scene.set_preview_event(event)
		scene.event_preview.elapsed = 4.5
		scene.event_preview._process(0)
		check(scene.event_preview.selected == event, "Event selection " + str(event))
		check(scene.event_preview.actors.size() > 0, "Event has animated actors " + str(event))
		if event == 1:
			check(scene.event_preview.vehicle_lift > 0, "UFO visual vehicle lift")
			check(truck.position.y > Spec.TRUCK_POSITION.y, "UFO preview lifts truck geometry")
		for actor in scene.event_preview.actors:
			check(actor.position.is_finite(), "Finite event actor " + str(event))
		await shot("0%d_event_%d" % [event + 2, event])
	scene.set_preview_event(0)
	check(scene.event_preview.content.get_child_count() == 0, "Clear event removes preview geometry")
	check(truck.position.is_equal_approx(Spec.TRUCK_POSITION), "Event clear restores truck pose")
	scene.route_map.visible = true
	scene.route_map._select(1)
	await process_frame
	check(scene.route_map.selected == 1, "Route concept selection")
	check(scene.route_map.nodes.size() == 8, "Route graph has eight nodes")
	await shot("08_route_choices")
	root.size = Vector2i(960, 640)
	await shot("09_route_small_window")
	var report := "# v0.4 场景验证\n\nGodot: %s\n\n检查：%d；失败：%d。\n\n范围：实际人物/车辆/货物包络，六预置，装载分离，站蹲，门洞通行与开关阻挡，双窗口七视角，五事件循环与清除，路线草案选择。\n\n这些检查不证明完整驾驶、订单、经济、联机和事件 AI 已实现。\n" % [Engine.get_version_info().string, checks, failures.size()]
	for failure in failures:
		report += "\n- " + failure
	var file := FileAccess.open(output.path_join("validation.md"), FileAccess.WRITE)
	if file:
		file.store_string(report)
	print("GREYBOX CHECKS: %d; FAILURES: %d; report: %s" % [checks, failures.size(), output])
	quit(0 if failures.is_empty() else 1)

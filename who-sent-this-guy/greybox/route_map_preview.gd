extends PanelContainer
## Reviewable route topology; deliberately separate from an implemented order session.
const ROUTES := [
	["外环农场", "路程较长 · UFO 风险\n鸡笼：注意惊吓\n补给较少"],
	["峡谷近路", "路程较短 · 龙卷风风险\n鱼缸：注意晃动\n无维修点"],
	["公路补给", "绕路补给 · 骑牛盗贼风险\n可修车 / 买油\n补给消耗预算"],
]
var graph: Control
var nodes: Array[Button] = []
var details: Label
var selected := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 50
	offset_right = -50
	offset_top = 115
	offset_bottom = -130
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142b39")
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	add_child(box)
	var heading := Label.new()
	heading.text = "班次路线草案  /  货物决定怎样选路"
	heading.add_theme_font_size_override("font_size", 24)
	box.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "概念预览：点击第一层节点查看取舍。正式订单、购买和计时尚未接入。"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(subtitle)
	graph = Control.new()
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.custom_minimum_size.y = 235
	box.add_child(graph)
	graph.draw.connect(_draw_edges)
	graph.resized.connect(_place_nodes)
	for i in 8:
		var node := Button.new()
		node.focus_mode = Control.FOCUS_NONE
		node.custom_minimum_size = Vector2(140, 44)
		graph.add_child(node)
		nodes.append(node)
	nodes[0].text = "仓库 / 装货出发"
	for i in 3:
		nodes[i + 1].text = ROUTES[i][0]
		nodes[i + 1].toggle_mode = true
		nodes[i + 1].pressed.connect(_select.bind(i))
	nodes[4].text = "农场交付 / 母牛雨"
	nodes[5].text = "补给站 / 修车买油"
	nodes[6].text = "城区交付 / 哈吉米"
	nodes[7].text = "终点 / 工资结算"
	for i in [0, 4, 5, 6, 7]:
		nodes[i].mouse_filter = Control.MOUSE_FILTER_IGNORE
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.y = 72
	details.text = "每层只选相连的下一节点，预先显示道路、事件风险和服务。首关在终点统一交付结算，超时按规则扣工资。"
	box.add_child(details)
	var close := Button.new()
	close.text = "N  关闭路线草案"
	close.pressed.connect(func(): visible = false)
	box.add_child(close)
	_place_nodes.call_deferred()

func _select(index: int) -> void:
	selected = index
	for i in 3:
		nodes[i + 1].set_pressed_no_signal(i == index)
	details.text = "预选：%s\n%s\n完整数值与连线校验规则见玩法文档；此处不产生交易或真实路线承诺。" % [ROUTES[index][0], ROUTES[index][1]]
	graph.queue_redraw()

func _place_nodes() -> void:
	if nodes.size() != 8:
		return
	var w := graph.size.x
	var h := graph.size.y
	var centers := [Vector2(0.08, 0.5), Vector2(0.35, 0.14), Vector2(0.35, 0.5), Vector2(0.35, 0.86), Vector2(0.64, 0.14), Vector2(0.64, 0.5), Vector2(0.64, 0.86), Vector2(0.92, 0.5)]
	for i in nodes.size():
		nodes[i].size = Vector2(minf(170, w * 0.21), 44)
		nodes[i].position = centers[i] * Vector2(w, h) - nodes[i].size / 2.0
	graph.queue_redraw()

func _draw_edges() -> void:
	if nodes.size() != 8:
		return
	var edges := [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 4), Vector2i(1, 5), Vector2i(2, 4), Vector2i(2, 6), Vector2i(3, 5), Vector2i(3, 6), Vector2i(4, 7), Vector2i(5, 7), Vector2i(6, 7)]
	for edge in edges:
		var color := Color("4b6977")
		if selected >= 0 and ((edge.x == 0 and edge.y == selected + 1) or edge.x == selected + 1):
			color = Color("e5bd70")
		graph.draw_line(nodes[edge.x].position + nodes[edge.x].size / 2.0, nodes[edge.y].position + nodes[edge.y].size / 2.0, color, 3, true)

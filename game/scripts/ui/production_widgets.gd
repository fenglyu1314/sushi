extends RefCounted
class_name ProductionWidgets
## 生产链白盒拖放组件（决策阶段与营业阶段复用，见 tasks 4.3 / 5.3）
## 提供三类控件：
##   - BufferItem：出餐台上的一份成品（可拖动源）
##   - ShelfCell：货架的一格（放置目标：接收出餐台成品上架）
##   - TrashBin：垃圾桶（放置目标：备货=取消退料 / 营业=作废，由 GameSession 按阶段分流）
## 拖放成功后调用 GameSession 接口；状态变更经 EventBus(buffer_changed/shelf_changed) 广播，
## 面板据此整体重绘，组件自身无需持有刷新逻辑。
## 拖放反馈（tasks 4.4）：放置目标在 _can_drop_data 时按合法/非法着色高亮，拖放结束复位；
## 非法放置 Godot 默认不触发 _drop_data，源与目标状态均不变（自动回弹）。

const COL_EMPTY := Color(0.18, 0.20, 0.24, 1.0)   # 空格 / 空位底色
const COL_ITEM := Color(0.30, 0.45, 0.55, 1.0)    # 成品底色
const COL_TRASH := Color(0.30, 0.16, 0.16, 1.0)   # 垃圾桶底色
const HL_OK := Color(1.3, 1.6, 1.3, 1.0)          # 合法高亮（提亮偏绿）
const HL_BAD := Color(1.6, 1.1, 1.1, 1.0)         # 非法提示（提亮偏红）


## —— 出餐台成品（可拖动源）——
class BufferItem:
	extends Panel
	var session: Node
	var index: int
	var recipe_id: StringName

	func setup(s: Node, i: int, rid: StringName, text: String) -> void:
		session = s
		index = i
		recipe_id = rid
		custom_minimum_size = Vector2(96, 40)
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "拖动到货架空格=上架；拖到垃圾桶=备货退料/营业作废"
		var bg := ColorRect.new()
		bg.color = ProductionWidgets.COL_ITEM
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		var l := Label.new()
		l.text = text
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)

	func _get_drag_data(_pos: Vector2) -> Variant:
		var data := {"from": &"buffer", "index": index, "recipe_id": recipe_id}
		var preview := Label.new()
		preview.text = "▤ " + String(recipe_id)
		preview.modulate = Color(1, 1, 1, 0.85)
		set_drag_preview(preview)
		return data


## —— 货架格（放置目标：出餐台成品 → 空格上架）——
class ShelfCell:
	extends Panel
	var session: Node
	var index: int
	var occupied: bool

	func setup(s: Node, i: int, occupied_by: String) -> void:
		session = s
		index = i
		occupied = occupied_by != ""
		custom_minimum_size = Vector2(96, 56)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var bg := ColorRect.new()
		bg.color = ProductionWidgets.COL_ITEM if occupied else ProductionWidgets.COL_EMPTY
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		var l := Label.new()
		l.text = occupied_by if occupied else "（空格 %d）" % (i + 1)
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		var ok: bool = typeof(data) == TYPE_DICTIONARY and data.get("from") == &"buffer" and not occupied
		self_modulate = ProductionWidgets.HL_OK if ok else ProductionWidgets.HL_BAD
		return ok

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		self_modulate = Color.WHITE
		if session != null and data.get("from") == &"buffer":
			session.request_stock(int(data.get("index", -1)), index)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			self_modulate = Color.WHITE


## —— 垃圾桶（放置目标：备货退料 / 营业作废）——
class TrashBin:
	extends Panel
	var session: Node

	func setup(s: Node, hint: String) -> void:
		session = s
		custom_minimum_size = Vector2(200, 56)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var bg := ColorRect.new()
		bg.color = ProductionWidgets.COL_TRASH
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		var l := Label.new()
		l.text = hint
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		var ok: bool = typeof(data) == TYPE_DICTIONARY and (data.get("from") == &"buffer" or data.get("from") == &"shelf")
		self_modulate = ProductionWidgets.HL_OK if ok else ProductionWidgets.HL_BAD
		return ok

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		self_modulate = Color.WHITE
		if session == null:
			return
		var idx := int(data.get("index", -1))
		if data.get("from") == &"buffer":
			session.request_discard_buffer(idx)
		elif data.get("from") == &"shelf":
			session.request_discard_shelf(idx)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			self_modulate = Color.WHITE

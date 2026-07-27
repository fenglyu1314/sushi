extends Control
## 结算阶段 UI（settlement-ui）
## 订阅 day_settled，展示营收/采购/租金/浪费/净利与结算后现金（盈亏用不同颜色白盒区分），
## 逐款列出售出/作废/流失明细，明确区分「流失=机会成本不扣钱」与「浪费=沉没成本实亏」。
## 提供"进入下一天"入口；预留"流言"等后续内容占位区。
## 白盒占位：脚本自建全部内部节点，用户只需创建一个挂本脚本的 Control 节点。

const DC = preload("res://scripts/core/day_cycle.gd")

var _session: Node
var _summary_box: VBoxContainer
var _net_rect: ColorRect
var _net_label: Label
var _detail_box: VBoxContainer
var _built: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_background(Color(0.15, 0.13, 0.10, 1.0))  # 结算：暗棕底
	EventBus.day_settled.connect(_on_day_settled)


func _add_background(c: Color) -> void:
	var bg := ColorRect.new()
	bg.color = c
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _resolve_session() -> bool:
	if _session == null:
		_session = get_tree().get_first_node_in_group("game_session")
	return _session != null


func _ensure_built() -> void:
	if _built:
		return

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.position = Vector2(16, 16)
	root.custom_minimum_size = Vector2(560, 0)
	add_child(root)

	var title := Label.new()
	title.text = "== 结算阶段：当日复盘 =="
	root.add_child(title)

	# 6.1 盈亏结构
	var summary_title := Label.new()
	summary_title.text = "— 盈亏结构 —"
	root.add_child(summary_title)
	_summary_box = VBoxContainer.new()
	root.add_child(_summary_box)

	# 净利彩条（盈绿 / 亏红）
	_net_rect = ColorRect.new()
	_net_rect.custom_minimum_size = Vector2(540, 32)
	root.add_child(_net_rect)
	_net_label = Label.new()
	_net_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_net_label.position = Vector2(8, 4)
	_net_rect.add_child(_net_label)

	# 6.2 各款明细
	var detail_title := Label.new()
	detail_title.text = "— 各款明细（售出 / 作废 / 流失）—"
	root.add_child(detail_title)
	var legend := Label.new()
	legend.text = "说明：流失=顾客想要却无货（机会成本，不扣钱）；作废=没卖掉倒掉（沉没成本，实亏）"
	root.add_child(legend)
	_detail_box = VBoxContainer.new()
	root.add_child(_detail_box)

	# 6.3 占位区（后续里程碑内容，如「流言」）
	var placeholder := Label.new()
	placeholder.text = "【流言】（后续里程碑内容占位，暂无数据）"
	placeholder.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	root.add_child(placeholder)

	# 6.3 进入下一天
	var next_btn := Button.new()
	next_btn.text = "▶ 进入下一天"
	next_btn.pressed.connect(_on_next_day)
	root.add_child(next_btn)

	_built = true


func _on_day_settled(review: Dictionary) -> void:
	_ensure_built()
	_populate(review)


func _populate(review: Dictionary) -> void:
	var revenue := float(review.get("revenue", 0.0))
	var purchase := float(review.get("purchase_cost", 0.0))
	var rent := float(review.get("rent_cost", 0.0))
	var waste := float(review.get("waste_cost", 0.0))
	var net := float(review.get("net_profit", 0.0))
	var cash_after := float(review.get("cash_after", 0.0))

	# 盈亏结构
	for c in _summary_box.get_children():
		c.queue_free()
	_add_summary_line("营收：+¥%.1f" % revenue)
	_add_summary_line("采购成本：−¥%.1f" % purchase)
	_add_summary_line("租金：−¥%.1f" % rent)
	_add_summary_line("浪费额（作废沉没成本，已在采购时扣钱，此处仅复盘）：¥%.1f" % waste)
	_add_summary_line("结算后现金：¥%.1f" % cash_after)

	# 净利彩条：盈绿 / 亏红
	_net_label.text = "净利：%s¥%.1f" % ["+" if net >= 0.0 else "−", abs(net)]
	_net_rect.color = Color(0.15, 0.45, 0.15) if net >= 0.0 else Color(0.5, 0.15, 0.15)

	# 各款明细
	for c in _detail_box.get_children():
		c.queue_free()
	var sold: Dictionary = review.get("sold_by_recipe", {})
	var wasted: Dictionary = review.get("wasted_by_recipe", {})
	var lost: Dictionary = review.get("lost_by_recipe", {})
	var ids := {}
	for k in sold: ids[k] = true
	for k in wasted: ids[k] = true
	for k in lost: ids[k] = true
	if ids.is_empty():
		var none := Label.new()
		none.text = "（无成交 / 作废 / 流失记录）"
		_detail_box.add_child(none)
	else:
		for id in ids:
			var line := Label.new()
			line.text = "%s：售出 %d ｜ 作废 %d ｜ 流失 %d" % [
				id, int(sold.get(id, 0)), int(wasted.get(id, 0)), int(lost.get(id, 0))]
			_detail_box.add_child(line)


func _add_summary_line(text: String) -> void:
	var l := Label.new()
	l.text = text
	_summary_box.add_child(l)


func _on_next_day() -> void:
	if _resolve_session():
		_session.start_next_day()

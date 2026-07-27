extends Control
## 模拟阶段 UI（simulation-ui）
## 订阅 tick_advanced 更新进度与各款成品剩余份数；订阅 sale_made/customer_lost
## 累计成交/流失/实时营收，并向滚动日志追加单条记录。
## 白盒占位：脚本自建全部内部节点，用户只需创建一个挂本脚本的 Control 节点。

const DC = preload("res://scripts/core/day_cycle.gd")
const LOG_MAX := 60  # 日志最多保留条数

var _session: Node
var _progress_label: Label
var _stats_label: Label
var _finished_box: VBoxContainer
var _log_box: VBoxContainer
var _log_scroll: ScrollContainer
var _fin_labels: Dictionary = {}   # recipe_id -> Label

var _sales_count: int = 0
var _loss_count: int = 0
var _revenue: float = 0.0
var _built: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_background(Color(0.10, 0.11, 0.16, 1.0))  # 模拟：暗蓝底
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.sale_made.connect(_on_sale_made)
	EventBus.customer_lost.connect(_on_customer_lost)


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


func _on_phase_changed(phase: int) -> void:
	if phase == DC.Phase.SIMULATION:
		_ensure_built()
		_reset()
		_update_progress(0)
		_update_finished()


func _ensure_built() -> void:
	if _built or not _resolve_session():
		return

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.position = Vector2(16, 16)
	root.custom_minimum_size = Vector2(560, 0)
	add_child(root)

	var title := Label.new()
	title.text = "== 模拟阶段：营业中 =="
	root.add_child(title)

	_progress_label = Label.new()
	root.add_child(_progress_label)

	_stats_label = Label.new()
	root.add_child(_stats_label)

	var fin_title := Label.new()
	fin_title.text = "— 成品余量 —"
	root.add_child(fin_title)
	_finished_box = VBoxContainer.new()
	root.add_child(_finished_box)
	for recipe in _session.get_recipes():
		var l := Label.new()
		_fin_labels[recipe.id] = l
		_finished_box.add_child(l)

	var log_title := Label.new()
	log_title.text = "— 成交 / 流失 日志 —"
	root.add_child(log_title)
	_log_scroll = ScrollContainer.new()
	_log_scroll.custom_minimum_size = Vector2(540, 220)
	root.add_child(_log_scroll)
	_log_box = VBoxContainer.new()
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.add_child(_log_box)

	_built = true


func _reset() -> void:
	_sales_count = 0
	_loss_count = 0
	_revenue = 0.0
	if _log_box != null:
		for c in _log_box.get_children():
			c.queue_free()
	_update_stats()


# ===== 5.1 进度与成品余量 =====

func _on_tick_advanced(tick_index: int) -> void:
	if DayCycle.current_phase != DC.Phase.SIMULATION:
		return
	_ensure_built()
	_update_progress(tick_index)
	_update_finished()


func _update_progress(tick_index: int) -> void:
	if _progress_label != null:
		_progress_label.text = "进度：tick %d / %d" % [tick_index, DC.TICKS_PER_DAY]


func _update_finished() -> void:
	if not _resolve_session():
		return
	for recipe in _session.get_recipes():
		var l: Label = _fin_labels.get(recipe.id)
		if l != null:
			l.text = "%s：剩余 %d 份" % [recipe.display_name, _session.get_finished_count(recipe.id)]


# ===== 5.2 成交 / 流失反馈 =====

func _on_sale_made(recipe_id: StringName, revenue: float) -> void:
	_sales_count += 1
	_revenue += revenue
	_update_stats()
	_update_finished()
	_append_log("成交　%s　+¥%.1f" % [recipe_id, revenue])


func _on_customer_lost(recipe_id: StringName) -> void:
	_loss_count += 1
	_update_stats()
	_append_log("流失　%s（无货，不扣钱）" % recipe_id)


func _update_stats() -> void:
	if _stats_label != null:
		_stats_label.text = "成交 %d ｜ 流失 %d ｜ 实时营收 ¥%.1f" % [_sales_count, _loss_count, _revenue]


func _append_log(text: String) -> void:
	if _log_box == null:
		return
	var l := Label.new()
	l.text = text
	_log_box.add_child(l)
	# 限制日志条数
	while _log_box.get_child_count() > LOG_MAX:
		var first := _log_box.get_child(0)
		_log_box.remove_child(first)
		first.queue_free()
	# 自动滚到底部
	if _log_scroll != null:
		_log_scroll.set_deferred("scroll_vertical", 1_000_000)

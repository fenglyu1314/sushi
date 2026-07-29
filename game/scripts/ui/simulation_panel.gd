extends Control
## 模拟阶段 UI（simulation-ui，营业）
## 生产交互为「加入制作队列」：单线程队列自动逐个制作、进度条实时推进、出餐台满时提示暂停。
## 展示出餐台（占用/容量）与货架 N×N 格（替代原「剩余成品份数」），支持拖放补货（出餐台→货架空格）
## 与作废（拖到垃圾桶，沉没成本、不返料）——复用第 4 节拖放组件。
## 订阅成交/流失更新统计与滚动日志。

const DC = preload("res://scripts/core/day_cycle.gd")
const PW = preload("res://scripts/ui/production_widgets.gd")
const LOG_MAX := 60

var _session: Node
var _progress_label: Label
var _stats_label: Label
var _craft_label: Label
var _craft_bar: ProgressBar
var _queue_rows: Dictionary = {}   # recipe_id -> {enqueue, count_label}
var _buffer_title: Label
var _buffer_box: HBoxContainer
var _shelf_grid: GridContainer
var _log_box: VBoxContainer
var _log_scroll: ScrollContainer

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
	# 生产链信号
	EventBus.craft_started.connect(func(rid): _append_log("开始制作　%s" % _name_of(rid)))
	EventBus.craft_progress.connect(_on_craft_progress)
	EventBus.craft_finished.connect(_on_craft_finished)
	EventBus.craft_skipped.connect(func(rid): _append_log("料不足跳过　%s" % _name_of(rid)))
	EventBus.crafting_paused.connect(_on_crafting_paused)
	EventBus.crafting_resumed.connect(_on_crafting_resumed)
	EventBus.buffer_changed.connect(_on_container_changed)
	EventBus.shelf_changed.connect(_on_container_changed)
	EventBus.sushi_wasted.connect(_on_sushi_wasted)


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


func _name_of(recipe_id: StringName) -> String:
	if _resolve_session():
		return _session.get_recipe_display_name(recipe_id)
	return String(recipe_id)


func _on_phase_changed(phase: int) -> void:
	if phase == DC.Phase.SIMULATION:
		_ensure_built()
		_reset()
		_update_progress()
		_refresh_all()


func _ensure_built() -> void:
	if _built or not _resolve_session():
		return

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.custom_minimum_size = Vector2(560, 0)
	scroll.add_child(root)

	var title := Label.new()
	title.text = "== 模拟阶段：营业中 =="
	root.add_child(title)

	_progress_label = Label.new()
	root.add_child(_progress_label)

	_stats_label = Label.new()
	root.add_child(_stats_label)

	# 制作队列区
	var q_title := Label.new()
	q_title.text = "— 制作队列（点击加入队列，单线程逐个自动制作）—"
	root.add_child(q_title)
	for recipe in _session.get_recipes():
		root.add_child(_make_queue_row(recipe))

	# 当前制作进度
	_craft_label = Label.new()
	root.add_child(_craft_label)
	_craft_bar = ProgressBar.new()
	_craft_bar.custom_minimum_size = Vector2(400, 18)
	_craft_bar.min_value = 0.0
	_craft_bar.max_value = 1.0
	_craft_bar.value = 0.0
	root.add_child(_craft_bar)

	# 出餐台
	_buffer_title = Label.new()
	root.add_child(_buffer_title)
	_buffer_box = HBoxContainer.new()
	_buffer_box.add_theme_constant_override("separation", 6)
	root.add_child(_buffer_box)

	# 货架 N×N（补货：出餐台→空格）
	var shelf_title := Label.new()
	shelf_title.text = "— 货架（把出餐台成品拖到空格补货；顾客只买货架上的）—"
	root.add_child(shelf_title)
	_shelf_grid = GridContainer.new()
	_shelf_grid.columns = max(1, _session.get_shelf_size())
	_shelf_grid.add_theme_constant_override("h_separation", 6)
	_shelf_grid.add_theme_constant_override("v_separation", 6)
	root.add_child(_shelf_grid)

	# 垃圾桶（营业 = 作废，沉没成本）
	var trash: PW.TrashBin = PW.TrashBin.new()
	trash.setup(_session, "🗑 垃圾桶（营业=作废，沉没成本、不返料）")
	root.add_child(trash)

	# 成交 / 流失日志
	var log_title := Label.new()
	log_title.text = "— 制作 / 成交 / 流失 日志 —"
	root.add_child(log_title)
	_log_scroll = ScrollContainer.new()
	_log_scroll.custom_minimum_size = Vector2(540, 180)
	root.add_child(_log_scroll)
	_log_box = VBoxContainer.new()
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.add_child(_log_box)

	_built = true


func _make_queue_row(recipe: Recipe) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(280, 0)
	name_label.text = "%s（耗时 %.1fs）" % [recipe.display_name, recipe.craft_time]
	row.add_child(name_label)

	var enqueue := Button.new()
	enqueue.text = "加入队列"
	enqueue.pressed.connect(func(): _on_enqueue(recipe.id))
	row.add_child(enqueue)

	var count_label := Label.new()
	count_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(count_label)

	_queue_rows[recipe.id] = {"enqueue": enqueue, "count_label": count_label}
	return row


func _on_enqueue(recipe_id: StringName) -> void:
	if _session.request_enqueue(recipe_id):
		_append_log("入队　%s" % _name_of(recipe_id))
		_update_queue()


func _reset() -> void:
	_sales_count = 0
	_loss_count = 0
	_revenue = 0.0
	if _log_box != null:
		for c in _log_box.get_children():
			c.queue_free()
	_update_stats()


# ===== 进度 / 队列 / 容器 =====

func _on_tick_advanced(_tick_index: int) -> void:
	if DayCycle.current_phase != DC.Phase.SIMULATION:
		return
	_ensure_built()


## 每帧刷新营业倒计时（比 tick 更平滑），仅营业阶段生效。
func _process(_delta: float) -> void:
	if DayCycle.current_phase == DC.Phase.SIMULATION:
		_update_progress()


func _update_progress() -> void:
	if _progress_label == null:
		return
	var remaining := DayCycle.get_day_remaining()
	var total := DC.DAY_DURATION_SEC
	_progress_label.text = "营业剩余：%.0f / %.0f 秒" % [remaining, total]


func _refresh_all() -> void:
	_update_queue()
	_update_craft()
	_rebuild_containers()


func _update_queue() -> void:
	if not _resolve_session():
		return
	var counts: Dictionary = _session.get_queue_counts()
	for rid in _queue_rows:
		var n: int = int(counts.get(rid, 0))
		_queue_rows[rid]["count_label"].text = "队列中 %d 份" % n


func _update_craft() -> void:
	if _craft_label == null:
		return
	var rid: StringName = _session.get_current_craft_recipe_id()
	if rid == &"":
		_craft_label.text = "当前制作：（空闲）"
		_craft_bar.value = 0.0
		return
	var ratio: float = _session.get_current_craft_ratio()
	_craft_bar.value = ratio
	var suffix := "（出餐台满，暂停落台）" if _session.is_crafting_paused() else ""
	_craft_label.text = "当前制作：%s　%d%%%s" % [_name_of(rid), int(ratio * 100.0), suffix]


func _on_craft_progress(_rid: StringName, _ratio: float) -> void:
	if DayCycle.current_phase == DC.Phase.SIMULATION:
		_update_craft()


func _on_craft_finished(rid: StringName) -> void:
	_append_log("完成　%s → 出餐台" % _name_of(rid))
	_update_queue()
	_update_craft()


func _on_crafting_paused() -> void:
	_append_log("⏸ 出餐台已满，制作暂停（请补货腾位）")
	_update_craft()


func _on_crafting_resumed() -> void:
	_append_log("▶ 出餐台出空位，制作恢复")
	_update_craft()


func _on_container_changed() -> void:
	if DayCycle.current_phase == DC.Phase.SIMULATION and _built:
		_rebuild_containers()
		_update_craft()


func _on_sushi_wasted(rid: StringName, source: StringName) -> void:
	if source != &"settlement":
		_append_log("作废　%s（来自%s，沉没成本）" % [_name_of(rid), "出餐台" if source == &"buffer" else "货架"])


func _rebuild_containers() -> void:
	if _buffer_box == null or _shelf_grid == null:
		return
	var items: Array = _session.get_buffer_items()
	_buffer_title.text = "— 出餐台（%d / %d）拖到货架空格=补货，拖到垃圾桶=作废 —" % [
		items.size(), _session.get_buffer_capacity()]
	for c in _buffer_box.get_children():
		c.queue_free()
	for i in items.size():
		var it: Dictionary = items[i]
		var w: PW.BufferItem = PW.BufferItem.new()
		w.setup(_session, i, it.get("recipe_id", &""), _name_of(it.get("recipe_id", &"")))
		_buffer_box.add_child(w)
	if items.is_empty():
		var l := Label.new()
		l.text = "（出餐台空）"
		_buffer_box.add_child(l)

	var shelf: Array = _session.get_shelf_items()
	for c in _shelf_grid.get_children():
		c.queue_free()
	for i in shelf.size():
		var cell = shelf[i]
		var occ := "" if cell == null else _name_of(cell.get("recipe_id", &""))
		var sc: PW.ShelfCell = PW.ShelfCell.new()
		sc.setup(_session, i, occ)
		_shelf_grid.add_child(sc)


# ===== 成交 / 流失 =====

func _on_sale_made(recipe_id: StringName, revenue: float) -> void:
	_sales_count += 1
	_revenue += revenue
	_update_stats()
	_append_log("成交　%s　+¥%.1f" % [_name_of(recipe_id), revenue])


func _on_customer_lost(recipe_id: StringName) -> void:
	_loss_count += 1
	_update_stats()
	_append_log("流失　%s（货架无货，不扣钱）" % _name_of(recipe_id))


func _update_stats() -> void:
	if _stats_label != null:
		_stats_label.text = "成交 %d ｜ 流失 %d ｜ 实时营收 ¥%.1f" % [_sales_count, _loss_count, _revenue]


func _append_log(text: String) -> void:
	if _log_box == null:
		return
	var l := Label.new()
	l.text = text
	_log_box.add_child(l)
	while _log_box.get_child_count() > LOG_MAX:
		var first := _log_box.get_child(0)
		_log_box.remove_child(first)
		first.queue_free()
	if _log_scroll != null:
		_log_scroll.set_deferred("scroll_vertical", 1_000_000)

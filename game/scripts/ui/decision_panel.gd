extends Control
## 决策阶段 UI（decision-ui，备货）
## 绑定 GameSession：展示现金/各食材库存/各配方；提供采购与「即时生产一份到出餐台」交互，
## 展示出餐台（占用/容量）与货架 N×N 格，支持拖放上架（出餐台→货架空格）与取消退料（拖到垃圾桶）。
## 白盒占位：脚本动态生成每种食材/配方一行，出餐台/货架/垃圾桶用纯色块 + 文字。

const DC = preload("res://scripts/core/day_cycle.gd")
const PW = preload("res://scripts/ui/production_widgets.gd")

var _session: Node
var _cash_label: Label
var _feedback_label: Label
var _empty_label: Label
var _buffer_title: Label
var _buffer_box: HBoxContainer
var _shelf_grid: GridContainer
var _ing_rows: Dictionary = {}     # ing_id -> {ing, spin, price}
var _recipe_rows: Dictionary = {}  # recipe_id -> {recipe, name, produce}
var _built: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_background(Color(0.10, 0.14, 0.10, 1.0))  # 决策：暗绿底
	EventBus.day_started.connect(func(_d): _refresh())
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.buffer_changed.connect(_on_container_changed)
	EventBus.shelf_changed.connect(_on_container_changed)
	EventBus.ingredients_returned.connect(_on_ingredients_returned)


func _on_phase_changed(phase: int) -> void:
	if phase == DC.Phase.DECISION:
		_refresh()


func _on_container_changed() -> void:
	if DayCycle.current_phase == DC.Phase.DECISION and _built:
		_refresh()


func _on_ingredients_returned(recipe_id: StringName) -> void:
	if _feedback_label != null:
		_feedback_label.text = "已退还食材：%s（未记沉没成本）" % _name_of(recipe_id)


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


# ===== UI 构建（首次刷新时惰性构建，确保 GameSession 已就绪） =====

func _build_ui() -> void:
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
	title.text = "== 决策阶段：采购 & 备货生产 =="
	root.add_child(title)

	_cash_label = Label.new()
	root.add_child(_cash_label)

	_empty_label = Label.new()
	_empty_label.text = "（未加载到内容资源：请在 res://data 的 ingredients/recipes 目录下创建 .tres）"
	_empty_label.visible = false
	root.add_child(_empty_label)

	# 采购区
	var buy_title := Label.new()
	buy_title.text = "— 采购食材（数量 = 原料单位数）—"
	root.add_child(buy_title)
	for ing in _session.get_ingredients():
		root.add_child(_make_ingredient_row(ing))

	# 生产区（即时生产：点击立刻产一份到出餐台）
	var prod_title := Label.new()
	prod_title.text = "— 备货生产（点击即产一份到出餐台，无耗时）—"
	root.add_child(prod_title)
	for recipe in _session.get_recipes():
		root.add_child(_make_recipe_row(recipe))

	# 出餐台展示区
	_buffer_title = Label.new()
	root.add_child(_buffer_title)
	_buffer_box = HBoxContainer.new()
	_buffer_box.add_theme_constant_override("separation", 6)
	root.add_child(_buffer_box)

	# 货架展示区（N×N）
	var shelf_title := Label.new()
	shelf_title.text = "— 货架（把出餐台成品拖到空格上架）—"
	root.add_child(shelf_title)
	_shelf_grid = GridContainer.new()
	_shelf_grid.columns = max(1, _session.get_shelf_size())
	_shelf_grid.add_theme_constant_override("h_separation", 6)
	_shelf_grid.add_theme_constant_override("v_separation", 6)
	root.add_child(_shelf_grid)

	# 垃圾桶（备货 = 取消退料）
	var trash: PW.TrashBin = PW.TrashBin.new()
	trash.setup(_session, "🗑 垃圾桶（备货=取消退料，返还食材）")
	root.add_child(trash)

	# 开摊
	var open_btn := Button.new()
	open_btn.text = "▶ 开摊（进入营业，成品不可再退料）"
	open_btn.pressed.connect(func(): _session.open_stall())
	root.add_child(open_btn)

	_feedback_label = Label.new()
	root.add_child(_feedback_label)

	var has_content: bool = not _session.get_ingredients().is_empty() or not _session.get_recipes().is_empty()
	_empty_label.visible = not has_content

	_built = true


func _make_ingredient_row(ing: Ingredient) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(180, 0)
	name_label.text = "%s（¥%.1f / %.0f料）" % [ing.display_name, ing.base_price, ing.unit_amount]
	row.add_child(name_label)

	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 99
	spin.value = 1
	row.add_child(spin)

	var price := Label.new()
	price.custom_minimum_size = Vector2(200, 0)
	row.add_child(price)

	var buy := Button.new()
	buy.text = "采购"
	row.add_child(buy)

	spin.value_changed.connect(func(_v): _update_ing_row(ing.id))
	buy.pressed.connect(func(): _on_buy(ing.id))

	_ing_rows[ing.id] = {"ing": ing, "spin": spin, "price": price}
	return row


func _make_recipe_row(recipe: Recipe) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(360, 0)
	row.add_child(name_label)

	var cost := Label.new()
	cost.custom_minimum_size = Vector2(120, 0)
	cost.text = "单份成本 ¥%.2f" % recipe.cost_per_serving()
	row.add_child(cost)

	var produce := Button.new()
	produce.text = "生产一份"
	row.add_child(produce)

	produce.pressed.connect(func(): _on_produce(recipe.id))

	_recipe_rows[recipe.id] = {"recipe": recipe, "name": name_label, "produce": produce}
	return row


# ===== 采购交互 =====

func _on_buy(ing_id: StringName) -> void:
	var qty := int(_ing_rows[ing_id]["spin"].value)
	var ok: bool = _session.request_buy(ing_id, qty)
	if ok:
		_feedback_label.text = "采购成功：%s x%d" % [ing_id, qty]
	else:
		_feedback_label.text = "采购失败：现金不足或非决策阶段"
	_refresh()


# ===== 即时生产交互（4.1） =====

func _on_produce(recipe_id: StringName) -> void:
	if _session.is_buffer_full():
		_feedback_label.text = "出餐台已满（%d/%d），请先上架或退料" % [
			_session.get_buffer_items().size(), _session.get_buffer_capacity()]
		return
	var ok: bool = _session.request_produce_one(recipe_id)
	if ok:
		_feedback_label.text = "已生产一份 %s → 出餐台" % _name_of(recipe_id)
	else:
		_feedback_label.text = "生产失败：食材不足或出餐台已满"
	_refresh()


# ===== 刷新展示 =====

func _refresh() -> void:
	if not _built:
		_build_ui()
	if not _built:
		return
	_cash_label.text = "现金：¥%.2f" % _session.get_cash()
	for id in _ing_rows:
		_update_ing_row(id)
	var full: bool = _session.is_buffer_full()
	for id in _recipe_rows:
		var row = _recipe_rows[id]
		var maxs: int = _session.get_max_servings(id)
		var made: int = _session.get_finished_count(id)
		row["name"].text = "%s  可做上限:%d  已备:%d" % [row["recipe"].display_name, maxs, made]
		# 4.1 出餐台满或料不足禁用并提示
		row["produce"].disabled = maxs <= 0 or full
	_rebuild_containers()


func _rebuild_containers() -> void:
	# 出餐台
	var items: Array = _session.get_buffer_items()
	_buffer_title.text = "— 出餐台（%d / %d）拖成品到货架空格=上架，拖到垃圾桶=退料 —" % [
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

	# 货架
	var shelf: Array = _session.get_shelf_items()
	for c in _shelf_grid.get_children():
		c.queue_free()
	for i in shelf.size():
		var cell = shelf[i]
		var occ := "" if cell == null else _name_of(cell.get("recipe_id", &""))
		var sc: PW.ShelfCell = PW.ShelfCell.new()
		sc.setup(_session, i, occ)
		_shelf_grid.add_child(sc)


func _update_ing_row(ing_id: StringName) -> void:
	var row = _ing_rows[ing_id]
	var ing: Ingredient = row["ing"]
	var qty := int(row["spin"].value)
	row["price"].text = "小计 ¥%.1f ｜ 现有库存 %.0f" % [ing.base_price * qty, _session.get_stock(ing_id)]

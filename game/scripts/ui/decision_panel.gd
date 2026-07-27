extends Control
## 决策阶段 UI（decision-ui）
## 绑定 GameSession，展示现金/各食材库存/各配方可做份数；提供采购与生产交互、"开摊"入口。
## 白盒占位：脚本按内容集动态生成每种食材/配方一行（Label + SpinBox + Button），
## 用户只需创建一个挂本脚本的 Control 节点，无需手工搭建每一行（符合「加内容不改代码」）。

const DC = preload("res://scripts/core/day_cycle.gd")

var _session: Node
var _cash_label: Label
var _feedback_label: Label
var _empty_label: Label
var _ing_rows: Dictionary = {}     # ing_id -> {ing, spin, price}
var _recipe_rows: Dictionary = {}  # recipe_id -> {recipe, spin, name, produce}
var _built: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_background(Color(0.10, 0.14, 0.10, 1.0))  # 决策：暗绿底
	EventBus.day_started.connect(func(_d): _refresh())
	EventBus.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(phase: int) -> void:
	if phase == DC.Phase.DECISION:
		_refresh()


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


# ===== 4.1 UI 构建（首次刷新时惰性构建，确保 GameSession 已就绪） =====

func _build_ui() -> void:
	if _built or not _resolve_session():
		return

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.position = Vector2(16, 16)
	root.custom_minimum_size = Vector2(560, 0)
	add_child(root)

	var title := Label.new()
	title.text = "== 决策阶段：采购 & 生产 =="
	root.add_child(title)

	_cash_label = Label.new()
	root.add_child(_cash_label)

	# 7.4 无内容占位提示
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

	# 生产区
	var prod_title := Label.new()
	prod_title.text = "— 生产寿司 —"
	root.add_child(prod_title)
	for recipe in _session.get_recipes():
		root.add_child(_make_recipe_row(recipe))

	# 4.4 开摊
	var open_btn := Button.new()
	open_btn.text = "▶ 开摊（进入模拟）"
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
	name_label.custom_minimum_size = Vector2(300, 0)
	row.add_child(name_label)

	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 999
	spin.value = 1
	row.add_child(spin)

	var cost := Label.new()
	cost.custom_minimum_size = Vector2(120, 0)
	cost.text = "单份成本 ¥%.2f" % recipe.cost_per_serving()
	row.add_child(cost)

	var produce := Button.new()
	produce.text = "生产"
	row.add_child(produce)

	produce.pressed.connect(func(): _on_produce(recipe.id))

	_recipe_rows[recipe.id] = {"recipe": recipe, "spin": spin, "name": name_label, "produce": produce}
	return row


# ===== 4.2 采购交互 =====

func _on_buy(ing_id: StringName) -> void:
	var qty := int(_ing_rows[ing_id]["spin"].value)
	var ok: bool = _session.request_buy(ing_id, qty)
	if ok:
		_feedback_label.text = "采购成功：%s x%d" % [ing_id, qty]
	else:
		_feedback_label.text = "采购失败：现金不足或非决策阶段"
	_refresh()


# ===== 4.3 生产交互 =====

func _on_produce(recipe_id: StringName) -> void:
	var want := int(_recipe_rows[recipe_id]["spin"].value)
	var made: int = _session.request_produce(recipe_id, want)
	_feedback_label.text = "生产 %s：请求 %d → 实做 %d 份" % [recipe_id, want, made]
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
	for id in _recipe_rows:
		var row = _recipe_rows[id]
		var maxs: int = _session.get_max_servings(id)
		var made: int = _session.get_finished_count(id)
		row["name"].text = "%s  可做上限:%d  已备:%d" % [row["recipe"].display_name, maxs, made]
		row["produce"].disabled = maxs <= 0  # 4.3 可做份数为 0 时禁用


func _update_ing_row(ing_id: StringName) -> void:
	var row = _ing_rows[ing_id]
	var ing: Ingredient = row["ing"]
	var qty := int(row["spin"].value)
	row["price"].text = "小计 ¥%.1f ｜ 现有库存 %.0f" % [ing.base_price * qty, _session.get_stock(ing_id)]

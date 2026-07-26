extends Node
## M1 核心循环验证脚本（挂载于 res://scenes/test_m1.tscn）
## 运行：godot --headless res://scenes/test_m1.tscn
##
## 目的：不依赖白盒 UI，用代码内联的占位数据串起「采购→生产→售卖→作废→结算」，
## 跑通完整一天并连跑多天，验证：
##   7.1 完整一天闭环跑通；
##   7.2 两类「亏」正确区分：流失不扣钱且食材留存、作废按沉没成本实亏；
##   7.3 连跑多天：库存跨天结转、现金随盈亏正确累积。
##
## 以场景形式在完整引擎环境运行：project.godot 的 autoload（EventBus 等）正常加载，
## 业务代码沿用地道的全局 `EventBus` 引用，无需为测试改动产品代码。
##
## 数据为占位初值（同 openspec/changes/m1-core-loop/content-manifest.md），仅验证机制、不代表平衡数值。

const DC = preload("res://scripts/core/day_cycle.gd")

var _content: Dictionary
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260727  # 固定种子，结果可复现
	_content = _build_content()

	var state := RunState.new()
	state.cash = 200.0
	print("=== M1 核心循环命令行验证 ===")
	print("初始现金：%.1f" % state.cash)

	_connect_events()

	# Day 1：故意超量生产 → 制造作废（演示「浪费/实亏」）
	_run_day(state, 1, {&"salmon": 4, &"tuna": 2, &"rice": 3, &"nori": 1},
		{&"salmon_nigiri": 30, &"tuna_nigiri": 15})

	# Day 2：不采购，使用 Day1 结转库存生产（演示「库存跨天结转」）
	_run_day(state, 2, {},
		{&"salmon_nigiri": 8, &"tuna_nigiri": 4})

	# Day 3：不生产（成品为 0）→ 全部顾客流失（演示「流失：不扣钱、不耗料」）
	var stock_before_day3 := state.ingredient_stock.duplicate(true)
	var cash_before_sales_day3 := 0.0
	cash_before_sales_day3 = _run_day(state, 3, {}, {})
	_check_loss_semantics(state, stock_before_day3, cash_before_sales_day3)

	print("\n=== 验证结束 ===")
	get_tree().quit()


## 跑完整一天，返回「进入模拟阶段前」的现金（供流失语义校验）
func _run_day(state: RunState, day: int, buy_plan: Dictionary, produce_plan: Dictionary) -> float:
	var loc: Location = _content["location"]
	var ings: Dictionary = _content["ingredients"]
	var recipes: Array[Recipe] = _content["recipes"]

	state.reset_daily_stats()
	print("\n──────── Day %d ────────" % day)
	print("[开局] 现金=%.1f  库存=%s  成品=%d" % [state.cash, _fmt_stock(state), state.finished_sushi.size()])

	# —— 决策阶段：采购 ——
	for ing_id in buy_plan.keys():
		var qty: int = buy_plan[ing_id]
		var ok := Procurement.buy(state, ings[ing_id], qty, DC.Phase.DECISION)
		print("[采购] %s x%d → %s" % [ing_id, qty, "成功" if ok else "失败(现金不足/阶段限制)"])

	# 反例：模拟阶段禁止采购（应失败）
	var illegal := Procurement.buy(state, ings[&"salmon"], 1, DC.Phase.SIMULATION)
	if illegal:
		push_error("[BUG] 模拟阶段竟允许采购！")

	# —— 决策阶段：生产 ——
	for rid in produce_plan.keys():
		var want: int = produce_plan[rid]
		var recipe := _find_recipe(recipes, rid)
		var made := Production.produce(state, recipe, want, DC.Phase.DECISION)
		print("[生产] %s 请求%d → 实做%d 份" % [rid, want, made])

	print("[开摊前] 现金=%.1f  库存=%s  成品=%d" % [state.cash, _fmt_stock(state), state.finished_sushi.size()])
	var cash_before_sales := state.cash

	# —— 模拟阶段：按 tick 售卖 ——
	var sales := Sales.new(recipes, _rng)
	for t in range(1, DC.TICKS_PER_DAY + 1):
		sales.process_tick(state, loc, t, DC.TICKS_PER_DAY)

	# —— 结算阶段 ——
	var review := Settlement.settle(state, loc)
	_print_review(review, state)
	return cash_before_sales


func _check_loss_semantics(state: RunState, stock_before: Dictionary, _cash_before_sales: float) -> void:
	# 库存不因流失变化
	var stock_unchanged := true
	for k in stock_before.keys():
		if not is_equal_approx(float(stock_before[k]), state.get_stock(k)):
			stock_unchanged = false
	var stats := state.daily_stats
	var no_revenue := is_equal_approx(float(stats["revenue"]), 0.0)
	var had_loss := int(stats["loss_count"]) > 0
	print("\n[校验-流失语义] 流失次数=%d 营收=%.1f 食材未因流失变化=%s"
		% [int(stats["loss_count"]), float(stats["revenue"]), str(stock_unchanged)])
	if had_loss and no_revenue and stock_unchanged:
		print("  ✓ 流失只计机会成本：不产生营收、不消耗食材")
	else:
		push_error("  ✗ 流失语义校验未通过")


# ============ 事件监听（验证 event-bus 广播）============

## 完整引擎环境下 autoload 已加载，直接监听全局 EventBus 的信号。
func _connect_events() -> void:
	EventBus.day_settled.connect(func(review: Dictionary):
		print("[事件] day_settled 已广播：净利=%.1f" % float(review.get("net_profit", 0.0)))
	)


# ============ 内联占位内容（同 content-manifest.md）============

func _build_content() -> Dictionary:
	var ings := {
		&"salmon": _ing(&"salmon", "三文鱼", 8.0, 300.0, Ingredient.Category.MAIN),
		&"tuna": _ing(&"tuna", "金枪鱼", 10.0, 300.0, Ingredient.Category.MAIN),
		&"tamago": _ing(&"tamago", "玉子", 5.0, 250.0, Ingredient.Category.MAIN),
		&"rice": _ing(&"rice", "米饭", 3.0, 1000.0, Ingredient.Category.SUB),
		&"nori": _ing(&"nori", "紫菜", 2.0, 500.0, Ingredient.Category.SUB),
	}

	var salmon_nigiri := _recipe(&"salmon_nigiri", "三文鱼握寿司", 12.0,
		[_ri(ings[&"salmon"], 30.0), _ri(ings[&"rice"], 20.0)],
		[&"fish", &"salmon", &"classic"])
	var tuna_nigiri := _recipe(&"tuna_nigiri", "金枪鱼握寿司", 14.0,
		[_ri(ings[&"tuna"], 30.0), _ri(ings[&"rice"], 20.0)],
		[&"fish", &"tuna"])
	var tamago_nigiri := _recipe(&"tamago_nigiri", "玉子握寿司", 8.0,
		[_ri(ings[&"tamago"], 25.0), _ri(ings[&"rice"], 20.0), _ri(ings[&"nori"], 5.0)],
		[&"sweet", &"tamago", &"veggie"])
	var recipes: Array[Recipe] = [salmon_nigiri, tuna_nigiri, tamago_nigiri]

	var loc := Location.new()
	loc.id = &"school_street"
	loc.display_name = "学校街"
	loc.foot_traffic = 20
	loc.spending_power = 0.9
	loc.rent = 30.0
	var mix: Array[CustomerWeight] = [
		_cw(_customer(&"student_fish", "爱吃鱼的学生", {&"fish": 2.0, &"salmon": 1.0}, 3.0), 3.0),
		_cw(_customer(&"student_tuna", "金枪鱼党学生", {&"tuna": 2.0, &"fish": 1.0}, 2.0), 2.0),
		_cw(_customer(&"student_sweet", "嗜甜学生", {&"sweet": 2.0, &"tamago": 1.0}, 1.0), 1.0),
	]
	loc.customer_mix = mix

	return {"ingredients": ings, "recipes": recipes, "location": loc}


func _ing(id: StringName, name: String, price: float, unit: float, cat: int) -> Ingredient:
	var i := Ingredient.new()
	i.id = id
	i.display_name = name
	i.base_price = price
	i.unit_amount = unit
	i.category = cat
	return i


func _ri(ing: Ingredient, amt: float) -> RecipeIngredient:
	var ri := RecipeIngredient.new()
	ri.ingredient = ing
	ri.amount_per_serving = amt
	return ri


func _recipe(id: StringName, name: String, price: float, ri_list: Array, tags: Array) -> Recipe:
	var r := Recipe.new()
	r.id = id
	r.display_name = name
	r.price = price
	var arr: Array[RecipeIngredient] = []
	for x in ri_list:
		arr.append(x)
	r.ingredients = arr
	var tag_arr: Array[StringName] = []
	for t in tags:
		tag_arr.append(t)
	r.flavor_tags = tag_arr
	return r


func _customer(id: StringName, name: String, prefs: Dictionary, weight: float) -> CustomerType:
	var c := CustomerType.new()
	c.id = id
	c.display_name = name
	c.preference_tags = prefs
	c.appear_weight = weight
	return c


func _cw(ctype: CustomerType, weight: float) -> CustomerWeight:
	var cw := CustomerWeight.new()
	cw.customer_type = ctype
	cw.weight = weight
	return cw


# ============ 辅助打印 ============

func _find_recipe(recipes: Array[Recipe], id: StringName) -> Recipe:
	for r in recipes:
		if r.id == id:
			return r
	return null


func _fmt_stock(state: RunState) -> String:
	var parts: Array[String] = []
	for k in state.ingredient_stock.keys():
		parts.append("%s=%.0f" % [k, state.get_stock(k)])
	return "{" + ", ".join(parts) + "}"


func _print_review(review: Dictionary, state: RunState) -> void:
	print("[结算] 成交=%d 流失=%d | 营收=%.1f 采购=%.1f 租金=%.1f 浪费=%.1f → 净利=%.1f"
		% [int(review["sales_count"]), int(review["loss_count"]),
			float(review["revenue"]), float(review["purchase_cost"]),
			float(review["rent_cost"]), float(review["waste_cost"]),
			float(review["net_profit"])])
	print("       售出明细=%s  作废明细=%s" % [str(review["sold_by_recipe"]), str(review["wasted_by_recipe"])])
	print("[收摊] 现金=%.1f  结转库存=%s" % [state.cash, _fmt_stock(state)])

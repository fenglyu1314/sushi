extends RefCounted
class_name Settlement
## 日结算逻辑（day-settlement）— 模拟层纯逻辑
## 收摊结算：作废未售成品（实亏 = 食材采购沉没成本）→ 扣租金 → 汇总盈亏 → 产出并广播复盘数据。
##
## 现金/盈亏口径：采购已在决策阶段扣现金、营收已在售卖时加现金，故结算只需再扣租金。
## 净利 = 营收 − 采购成本 − 租金。浪费额是采购成本中未卖出回收的部分，作为复盘指标呈现、不重复扣钱。


## 执行结算并返回复盘数据。结算发生在 day-cycle 的结算阶段。
static func settle(state: RunState, location: Location) -> Dictionary:
	if state == null or location == null:
		return {}

	# 1. 作废未售成品：按沉没成本计当日浪费
	while not state.finished_sushi.is_empty():
		var item: Dictionary = state.finished_sushi.pop_back()
		var rid: StringName = item.get("recipe_id", &"")
		var cost := float(item.get("cost", 0.0))
		state.record_waste(rid, cost)
		EventBus.sushi_discarded.emit(rid, cost)

	# 2. 扣租金
	var rent := location.rent
	state.daily_stats["rent_cost"] = rent
	state.cash -= rent

	# 3. 汇总盈亏
	var revenue := float(state.daily_stats["revenue"])
	var purchase := float(state.daily_stats["purchase_cost"])
	var waste := float(state.daily_stats["waste_cost"])
	var net := revenue - purchase - rent

	var review := {
		"revenue": revenue,
		"purchase_cost": purchase,
		"rent_cost": rent,
		"waste_cost": waste,
		"net_profit": net,
		"sales_count": int(state.daily_stats["sales_count"]),
		"loss_count": int(state.daily_stats["loss_count"]),
		"sold_by_recipe": (state.daily_stats["sold_by_recipe"] as Dictionary).duplicate(true),
		"wasted_by_recipe": (state.daily_stats["wasted_by_recipe"] as Dictionary).duplicate(true),
		"lost_by_recipe": (state.daily_stats["lost_by_recipe"] as Dictionary).duplicate(true),
		"cash_after": state.cash,
	}

	# 4. 广播复盘数据
	EventBus.day_settled.emit(review)
	return review

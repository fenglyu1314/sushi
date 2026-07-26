extends RefCounted
class_name RunState
## 运行状态（模拟层纯数据对象）
## 聚合当天可变状态：现金、食材库存（含辅料）、成品寿司、当日统计。
## 用 RefCounted 而非 Node，不挂场景树，便于命令行验证与后续接入存档。
##
## 现金流约定：采购在决策阶段扣现金、售卖成交即时加现金、租金在结算阶段扣现金；
## 「作废浪费」是采购沉没成本，已在采购时扣过现金，结算只作为复盘指标呈现、不重复扣。

## 现金
var cash: float = 0.0

## 食材库存：ingredient_id(StringName) → 剩余原料总量(float)。主料与辅料统一存放。
var ingredient_stock: Dictionary = {}

## 成品寿司：每份一项 { "recipe_id": StringName, "cost": float }
## cost = 该份的食材采购成本（沉没成本），供作废时核算浪费。
var finished_sushi: Array = []

## 当日统计
var daily_stats: Dictionary = {}


func _init() -> void:
	reset_daily_stats()


## 重置当日统计（每个回合开始调用；现金与库存跨天保留）
func reset_daily_stats() -> void:
	daily_stats = {
		"revenue": 0.0,
		"purchase_cost": 0.0,
		"rent_cost": 0.0,
		"waste_cost": 0.0,
		"sales_count": 0,
		"loss_count": 0,
		"sold_by_recipe": {},
		"wasted_by_recipe": {},
		"lost_by_recipe": {},
	}


## 库存查询
func get_stock(ingredient_id: StringName) -> float:
	return float(ingredient_stock.get(ingredient_id, 0.0))


## 库存增减（delta 可正可负）
func add_stock(ingredient_id: StringName, delta: float) -> void:
	ingredient_stock[ingredient_id] = get_stock(ingredient_id) + delta


## 成品入列，并记录其沉没成本
func add_finished(recipe_id: StringName, cost: float) -> void:
	finished_sushi.append({"recipe_id": recipe_id, "cost": cost})


## 当前某款成品的份数
func finished_count(recipe_id: StringName) -> int:
	var n := 0
	for item in finished_sushi:
		if item.get("recipe_id") == recipe_id:
			n += 1
	return n


## 移除一份指定款式成品；成功返回该份的沉没成本，失败返回 -1
func remove_one_finished(recipe_id: StringName) -> float:
	for i in finished_sushi.size():
		if finished_sushi[i].get("recipe_id") == recipe_id:
			var cost: float = float(finished_sushi[i].get("cost", 0.0))
			finished_sushi.remove_at(i)
			return cost
	return -1.0


func _bump(dict_key: String, recipe_id: StringName, amount: int = 1) -> void:
	var d: Dictionary = daily_stats[dict_key]
	d[recipe_id] = int(d.get(recipe_id, 0)) + amount


func record_sale(recipe_id: StringName, revenue: float) -> void:
	daily_stats["revenue"] = float(daily_stats["revenue"]) + revenue
	daily_stats["sales_count"] = int(daily_stats["sales_count"]) + 1
	_bump("sold_by_recipe", recipe_id)


func record_loss(recipe_id: StringName) -> void:
	daily_stats["loss_count"] = int(daily_stats["loss_count"]) + 1
	_bump("lost_by_recipe", recipe_id)


func record_waste(recipe_id: StringName, cost: float) -> void:
	daily_stats["waste_cost"] = float(daily_stats["waste_cost"]) + cost
	_bump("wasted_by_recipe", recipe_id)


## 纯数据化（供存档）
func to_dict() -> Dictionary:
	return {
		"cash": cash,
		"ingredient_stock": ingredient_stock.duplicate(true),
		"finished_sushi": finished_sushi.duplicate(true),
		"daily_stats": daily_stats.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	cash = float(data.get("cash", 0.0))
	ingredient_stock = (data.get("ingredient_stock", {}) as Dictionary).duplicate(true)
	finished_sushi = (data.get("finished_sushi", []) as Array).duplicate(true)
	daily_stats = (data.get("daily_stats", {}) as Dictionary).duplicate(true)
	if daily_stats.is_empty():
		reset_daily_stats()

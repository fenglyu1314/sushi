extends RefCounted
class_name Procurement
## 采购逻辑（procurement）— 模拟层纯逻辑
## 开摊前（决策阶段）用现金采购食材入库存；开摊后（模拟/结算阶段）禁止补料。
## 未消耗的食材由 RunState.ingredient_stock 天然跨天结转（reset_daily_stats 不清库存）。

const DayCycleScript = preload("res://scripts/core/day_cycle.gd")


## 采购某食材 quantity 个原料单位。
## 成功返回 true 并扣现金、入库存；phase 非决策阶段或现金不足则返回 false 且状态不变。
static func buy(state: RunState, ingredient: Ingredient, quantity: int, phase: int) -> bool:
	if state == null or ingredient == null or quantity <= 0:
		return false
	# 开摊后不可补料（GDD §5.1）
	if phase != DayCycleScript.Phase.DECISION:
		return false
	var total_cost := ingredient.base_price * quantity
	# 现金不足：拒绝，状态不变
	if state.cash < total_cost:
		return false
	state.cash -= total_cost
	state.add_stock(ingredient.id, ingredient.unit_amount * quantity)
	state.daily_stats["purchase_cost"] = float(state.daily_stats["purchase_cost"]) + total_cost
	return true

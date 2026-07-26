extends RefCounted
class_name Production
## 生产逻辑（sushi-production）— 模拟层纯逻辑
## 决策阶段按配方即时生产（无制作时间）：扣减主料/辅料库存 → 成品入列。
## 份数受库存与辅料上限共同约束，禁止负库存；辅料不足会限制相关配方的可做份数。

const DayCycleScript = preload("res://scripts/core/day_cycle.gd")


## 生产某配方 servings 份。返回实际生产份数（可能因库存/辅料不足而少于请求值）。
## phase 非决策阶段一律不生产。
static func produce(state: RunState, recipe: Recipe, servings: int, phase: int) -> int:
	if state == null or recipe == null or servings <= 0:
		return 0
	if phase != DayCycleScript.Phase.DECISION:
		return 0
	# 受所有所需食材（含辅料）共同约束的最大份数
	var max_possible := SushiMath.max_servings_for_recipe(recipe, state.ingredient_stock)
	var actual: int = min(servings, max_possible)
	if actual <= 0:
		return 0
	# 扣减食材（不会产生负库存，因 actual ≤ max_possible）
	for ri in recipe.ingredients:
		if ri == null or ri.ingredient == null:
			continue
		state.add_stock(ri.ingredient.id, -ri.amount_per_serving * actual)
	# 成品入列，记录单份沉没成本
	var cost := recipe.cost_per_serving()
	for _i in actual:
		state.add_finished(recipe.id, cost)
	return actual

extends RefCounted
class_name SushiMath
## 份数转化工具（game-data-model）
## 「原料总量 ÷ 每份消耗量 → 可做份数（向下取整）」。
## 一种食材可被多个配方以不同每份消耗量引用，各配方独立换算、互不影响。

## 某食材可支持某「每份消耗量」制作的最大份数
static func servings_from(total_amount: float, amount_per_serving: float) -> int:
	if amount_per_serving <= 0.0:
		return 0
	return int(floor(total_amount / amount_per_serving))


## 在给定库存下，某配方可制作的最大份数（受所有所需食材共同约束，取最小值）
## stock: Dictionary  ingredient_id(StringName) → 剩余原料总量(float)
static func max_servings_for_recipe(recipe: Recipe, stock: Dictionary) -> int:
	if recipe == null or recipe.ingredients.is_empty():
		return 0
	var limit := -1
	for ri in recipe.ingredients:
		if ri == null or ri.ingredient == null:
			continue
		var available: float = float(stock.get(ri.ingredient.id, 0.0))
		var possible := servings_from(available, ri.amount_per_serving)
		if limit < 0 or possible < limit:
			limit = possible
	return max(limit, 0)

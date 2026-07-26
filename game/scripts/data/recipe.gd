extends Resource
class_name Recipe
## 配方数据资源（game-data-model）
## 描述一款寿司的用料、售价与占格（占格本阶段仅记录、不施加空间约束）。

## 唯一 id
@export var id: StringName = &""

## 显示名称
@export var display_name: String = ""

## 所需食材及每份消耗量（含主料与辅料）
@export var ingredients: Array[RecipeIngredient] = []

## 售价（结算 / 售卖时结合地点消费力计算实际营收）
@export var price: float = 0.0

## 成品占货架格数（本阶段仅记录，暂不做空间约束）
@export var shelf_slots: int = 1

## 口味标签：供顾客按喜好标签匹配「想要哪款寿司」（sales 需求判定的桥接字段）
@export var flavor_tags: Array[StringName] = []


## 单份成品的食材采购成本（沉没成本核算依据）
func cost_per_serving() -> float:
	var total := 0.0
	for ri in ingredients:
		if ri == null or ri.ingredient == null:
			continue
		total += ri.ingredient.unit_cost() * ri.amount_per_serving
	return total

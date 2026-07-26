extends Resource
class_name RecipeIngredient
## 配方中的一项食材消耗（内嵌资源）
## 强类型引用某食材，并记录「每做一份该配方」消耗的原料量。

## 引用的食材资源
@export var ingredient: Ingredient

## 每份消耗量（从该食材的原料总量中扣减）
@export var amount_per_serving: float = 0.0

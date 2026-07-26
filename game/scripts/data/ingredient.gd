extends Resource
class_name Ingredient
## 食材数据资源（game-data-model）
## 以 .tres 承载具体食材实例；逻辑不得硬编码具体食材。
## 主料与辅料统一用本类型描述，靠 category 区分：
##   - 主料（MAIN）：如三文鱼、金枪鱼等，摆摊阶段放「冰箱」（本 change 简化为数值库存，暂不做占格）。
##   - 辅料（SUB）：如米饭、紫菜、醋等，以数值上限管理、不占格。

enum Category { MAIN, SUB }

## 唯一 id（运行时库存/映射均以此为 key）
@export var id: StringName = &""

## 显示名称
@export var display_name: String = ""

## 基础价格：采购「一个原料单位」的价格
@export var base_price: float = 0.0

## 原料总量单位：一次采购获得的原料总量（配方按「每份消耗量」从中扣减）
@export var unit_amount: float = 1.0

## 主料 / 辅料
@export var category: Category = Category.MAIN


## 单位原料价格（每 1 原料量的采购成本），供沉没成本核算使用
func unit_cost() -> float:
	if unit_amount <= 0.0:
		return 0.0
	return base_price / unit_amount


func is_sub() -> bool:
	return category == Category.SUB

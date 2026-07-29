extends RefCounted
class_name Production
## 生产逻辑（sushi-production）— 模拟层纯逻辑（薄封装）
## 本轮生产链核心已下沉到 RunState：
## - 备货阶段即时生产 → RunState.produce_instant(recipe)（受出餐台容量约束）。
## - 营业阶段单线程制作队列 → RunState.enqueue_craft / advance_crafting。
## 本类保留 produce() 供既有命令行验证脚本调用：仅在决策阶段按出餐台容量逐份即时生产。

const DayCycleScript = preload("res://scripts/core/day_cycle.gd")


## 备货阶段即时生产 servings 份。返回实际落出餐台份数（受库存/辅料/出餐台容量约束）。
## 非决策阶段一律不生产。
static func produce(state: RunState, recipe: Recipe, servings: int, phase: int) -> int:
	if state == null or recipe == null or servings <= 0:
		return 0
	if phase != DayCycleScript.Phase.DECISION:
		return 0
	var made := 0
	for _i in servings:
		if not state.produce_instant(recipe):
			break  # 出餐台满或食材不足
		made += 1
	return made

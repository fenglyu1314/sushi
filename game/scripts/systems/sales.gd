extends RefCounted
class_name Sales
## 售卖逻辑（sales）— 模拟层纯逻辑（有状态：持有配方索引与随机源）
## 模拟阶段按 tick 推进：依地点人流量生成到达顾客 → 抽取顾客类型 → 依喜好标签定需求款式
## → 有货成交（加营收）/ 无货流失（记机会成本，不扣钱不耗料）。

var recipes: Array[Recipe] = []
var rng: RandomNumberGenerator

## 标签 → 配方列表（顾客喜好标签匹配到具体寿司款式）
var _tag_to_recipes: Dictionary = {}


func _init(recipe_list: Array[Recipe] = [], random: RandomNumberGenerator = null) -> void:
	recipes = recipe_list
	rng = random if random != null else RandomNumberGenerator.new()
	_build_tag_index()


func _build_tag_index() -> void:
	_tag_to_recipes = {}
	for r in recipes:
		if r == null:
			continue
		for tag in r.flavor_tags:
			if not _tag_to_recipes.has(tag):
				_tag_to_recipes[tag] = [] as Array[Recipe]
			(_tag_to_recipes[tag] as Array).append(r)


## 本 tick 到达的顾客数：把地点全天人流量均摊到各 tick，余数分配到靠前的 tick。
## tick_index 为 1-based，total_ticks 为一天的总 tick 数。
static func arrivals_this_tick(foot_traffic: int, tick_index: int, total_ticks: int) -> int:
	if total_ticks <= 0 or foot_traffic <= 0:
		return 0
	var base := foot_traffic / total_ticks
	var rem := foot_traffic % total_ticks
	return base + (1 if tick_index <= rem else 0)


## 推进一个 tick：生成到达顾客并逐一处理成交/流失。
func process_tick(state: RunState, location: Location, tick_index: int, total_ticks: int) -> void:
	if state == null or location == null:
		return
	var count := arrivals_this_tick(location.foot_traffic, tick_index, total_ticks)
	for _i in count:
		var ctype := _pick_customer_type(location)
		if ctype == null:
			continue
		var wanted := _pick_wanted_recipe(ctype)
		if wanted == null:
			continue
		_serve(state, location, wanted)


func _serve(state: RunState, location: Location, recipe: Recipe) -> void:
	if state.shelf_count_of(recipe.id) > 0:
		# 货架有货成交（出餐台成品不参与售卖）
		state.remove_one_from_shelf(recipe.id)
		var revenue := recipe.price * location.spending_power
		state.cash += revenue
		state.record_sale(recipe.id, revenue)
		EventBus.sale_made.emit(recipe.id, revenue)
	else:
		# 货架无货流失：不扣钱、不耗料（即使出餐台里有也不算）
		state.record_loss(recipe.id)
		EventBus.customer_lost.emit(recipe.id)


## 按客群构成权重抽取一个顾客类型
func _pick_customer_type(location: Location) -> CustomerType:
	var total := 0.0
	for cw in location.customer_mix:
		if cw != null and cw.customer_type != null:
			total += cw.weight
	if total <= 0.0:
		return null
	var roll := rng.randf() * total
	var acc := 0.0
	for cw in location.customer_mix:
		if cw == null or cw.customer_type == null:
			continue
		acc += cw.weight
		if roll < acc:
			return cw.customer_type
	return null


## 依顾客喜好标签抽取一个标签，再匹配到具体寿司款式
func _pick_wanted_recipe(ctype: CustomerType) -> Recipe:
	var tags := ctype.preference_tags
	if tags.is_empty():
		return null
	var total := 0.0
	for w in tags.values():
		total += float(w)
	if total <= 0.0:
		return null
	var roll := rng.randf() * total
	var acc := 0.0
	var chosen_tag: StringName = &""
	for tag in tags.keys():
		acc += float(tags[tag])
		if roll < acc:
			chosen_tag = tag
			break
	var candidates: Array = _tag_to_recipes.get(chosen_tag, [])
	if candidates.is_empty():
		return null
	return candidates[rng.randi() % candidates.size()]

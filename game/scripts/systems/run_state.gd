extends RefCounted
class_name RunState
## 运行状态（模拟层纯数据对象）
## 聚合当天可变状态：现金、食材库存（含辅料）、成品（出餐台 buffer + 货架 shelf）、
## 营业阶段制作队列、当日统计。
## 用 RefCounted 而非 Node，不挂场景树，便于命令行验证与后续接入存档。
##
## 现金流约定：采购在决策阶段扣现金、售卖成交即时加现金、租金在结算阶段扣现金；
## 「作废浪费」是采购沉没成本，已在采购时扣过现金，结算只作为复盘指标呈现、不重复扣。
##
## 成品容器（本轮生产链）：
## - buffer（出餐台）：有序成品列表，容量上限 buffer_capacity；制作完成先落此处。
## - shelf（货架）：N×N 网格（展平数组），每格 1 份，sales 只从货架售卖。
## 成品项统一形状：{ "recipe_id": StringName, "cost": float, "recipe": Recipe }
## cost = 该份食材采购成本（沉没成本），recipe 供退料时按每份消耗量原额返还。

## 现金
var cash: float = 0.0

## 食材库存：ingredient_id(StringName) → 剩余原料总量(float)。主料与辅料统一存放。
var ingredient_stock: Dictionary = {}

## 出餐台（buffer）：有序成品列表
var buffer: Array = []
## 出餐台容量上限（初始 4，留升级接口 upgrade_buffer_capacity）
var buffer_capacity: int = 4

## 货架边长 N（N×N 格；建议 3）
var shelf_size: int = 3
## 货架：展平为长度 shelf_size*shelf_size 的数组，每格为 null（空）或成品项
var shelf: Array = []

## 营业阶段制作队列：有序 Recipe 列表（索引 0 为当前制作项）
var craft_queue: Array = []
## 当前制作项累计进度（秒）
var craft_elapsed: float = 0.0
## 因出餐台满而暂停（冻结落台：进度已满、成品悬停等待空位）
var crafting_paused: bool = false
## 当前制作项是否已发过 craft_started（避免重复发信号）
var _craft_started: bool = false

## 当日统计
var daily_stats: Dictionary = {}


func _init() -> void:
	reset_daily_stats()
	_init_shelf()


## 初始化 / 重置货架为全空
func _init_shelf() -> void:
	shelf.clear()
	shelf.resize(shelf_size * shelf_size)  # resize 以 null 填充


## 重置当日统计（每天开始调用；现金与库存跨天保留）
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


# ===== 库存 =====

func get_stock(ingredient_id: StringName) -> float:
	return float(ingredient_stock.get(ingredient_id, 0.0))


## 库存增减（delta 可正可负）
func add_stock(ingredient_id: StringName, delta: float) -> void:
	ingredient_stock[ingredient_id] = get_stock(ingredient_id) + delta


func _consume_ingredients(recipe: Recipe) -> void:
	for ri in recipe.ingredients:
		if ri == null or ri.ingredient == null:
			continue
		add_stock(ri.ingredient.id, -ri.amount_per_serving)


func _return_ingredients(recipe: Recipe) -> void:
	if recipe == null:
		return
	for ri in recipe.ingredients:
		if ri == null or ri.ingredient == null:
			continue
		add_stock(ri.ingredient.id, ri.amount_per_serving)
	EventBus.ingredients_returned.emit(recipe.id)


func _make_item(recipe: Recipe) -> Dictionary:
	return {"recipe_id": recipe.id, "cost": recipe.cost_per_serving(), "recipe": recipe}


# ===== 出餐台（buffer） =====

func buffer_count() -> int:
	return buffer.size()


func is_buffer_full() -> bool:
	return buffer.size() >= buffer_capacity


## 出餐台容量升级接口（本轮不实装 UI，仅留接口）
func upgrade_buffer_capacity(delta: int) -> void:
	buffer_capacity = max(1, buffer_capacity + delta)


func _push_buffer(item: Dictionary) -> void:
	buffer.append(item)
	EventBus.buffer_changed.emit()


# ===== 货架（shelf） =====

func shelf_slot_count() -> int:
	return shelf.size()


func shelf_used_count() -> int:
	var n := 0
	for cell in shelf:
		if cell != null:
			n += 1
	return n


## 第一个空格索引；无空格返回 -1
func first_empty_shelf_index() -> int:
	for i in shelf.size():
		if shelf[i] == null:
			return i
	return -1


func has_empty_shelf_slot() -> bool:
	return first_empty_shelf_index() >= 0


## 货架上某款成品的份数（sales 判定用）
func shelf_count_of(recipe_id: StringName) -> int:
	var n := 0
	for cell in shelf:
		if cell != null and cell.get("recipe_id") == recipe_id:
			n += 1
	return n


# ===== 2.2 备货阶段即时生产 =====
## 即时生产一份：校验食材足够 + 出餐台未满 → 瞬间扣料并落出餐台。
## 成功返回 true；出餐台满或食材不足则拒绝（返回 false，不改任何状态）。
func produce_instant(recipe: Recipe) -> bool:
	if recipe == null:
		return false
	if is_buffer_full():
		return false
	if SushiMath.max_servings_for_recipe(recipe, ingredient_stock) <= 0:
		return false
	_consume_ingredients(recipe)
	_push_buffer(_make_item(recipe))
	return true


# ===== 2.3 营业阶段制作队列 =====
## 入队一份某配方（可重复入队叠加数量）
func enqueue_craft(recipe: Recipe) -> void:
	if recipe == null:
		return
	craft_queue.append(recipe)


## 从队尾出队一份指定配方（撤销入队）；成功返回 true
func dequeue_craft_last(recipe_id: StringName) -> bool:
	for i in range(craft_queue.size() - 1, -1, -1):
		if craft_queue[i].id == recipe_id:
			# 若移除的是队首（正在制作），重置当前进度
			if i == 0:
				_reset_head()
			craft_queue.remove_at(i)
			return true
	return false


func queue_size() -> int:
	return craft_queue.size()


func current_craft_recipe() -> Recipe:
	if craft_queue.is_empty():
		return null
	return craft_queue[0]


## 当前制作项进度比（0→1）
func current_craft_ratio() -> float:
	var r := current_craft_recipe()
	if r == null:
		return 0.0
	return clampf(craft_elapsed / maxf(r.craft_time, 0.0001), 0.0, 1.0)


## 队列中各款待制作份数汇总：recipe_id → count
func queue_counts() -> Dictionary:
	var d := {}
	for r in craft_queue:
		d[r.id] = int(d.get(r.id, 0)) + 1
	return d


func _reset_head() -> void:
	_craft_started = false
	craft_elapsed = 0.0


# ===== 2.8 纯逻辑推进制作时钟（由 day_cycle 在 SIMULATION 每帧驱动） =====
## 推进当前制作项进度 delta 秒：累加进度 / 完成落台 / 出餐台满则暂停 / 取队列下一项。
## 无引擎依赖（除全局 EventBus 广播），可命令行手动喂步长步进。
func advance_crafting(delta: float) -> void:
	if craft_queue.is_empty():
		return
	# 暂停中（出餐台满、冻结落台）：尝试出空位后落台恢复
	if crafting_paused:
		_try_settle_head()
		return
	var recipe: Recipe = craft_queue[0]
	if not _craft_started:
		_craft_started = true
		craft_elapsed = 0.0
		EventBus.craft_started.emit(recipe.id)
	craft_elapsed += delta
	EventBus.craft_progress.emit(recipe.id, current_craft_ratio())
	if craft_elapsed >= recipe.craft_time:
		_try_settle_head()


# ===== 2.4 落台与「满则暂停 / 出空位恢复」 =====
## 队首进度已满，尝试落台：出餐台满→暂停；有空位→（校验食材后）扣料落台或跳过。
func _try_settle_head() -> void:
	if craft_queue.is_empty():
		return
	var recipe: Recipe = craft_queue[0]
	# 出餐台满：冻结落台、暂停制作
	if is_buffer_full():
		if not crafting_paused:
			crafting_paused = true
			EventBus.crafting_paused.emit()
		return
	# 有空位：若此前处于暂停，先恢复
	if crafting_paused:
		crafting_paused = false
		EventBus.crafting_resumed.emit()
	# 完成瞬间校验食材，不足则跳过该项并提示
	if SushiMath.max_servings_for_recipe(recipe, ingredient_stock) <= 0:
		craft_queue.pop_front()
		_reset_head()
		EventBus.craft_skipped.emit(recipe.id)
		return
	# 扣料落台
	_consume_ingredients(recipe)
	_push_buffer(_make_item(recipe))
	craft_queue.pop_front()
	_reset_head()
	EventBus.craft_finished.emit(recipe.id)


# ===== 2.5 成品转移 =====
## 出餐台某份 → 货架指定空格；非法转移不改任何状态。成功返回 true。
func move_buffer_to_shelf(buffer_index: int, shelf_index: int) -> bool:
	if buffer_index < 0 or buffer_index >= buffer.size():
		return false
	if shelf_index < 0 or shelf_index >= shelf.size():
		return false
	if shelf[shelf_index] != null:
		return false  # 目标格非空
	var item: Dictionary = buffer[buffer_index]
	buffer.remove_at(buffer_index)
	shelf[shelf_index] = item
	EventBus.buffer_changed.emit()
	EventBus.shelf_changed.emit()
	return true


## 便捷：把出餐台某份放到货架第一个空格（无空格则失败）
func stock_buffer_to_shelf(buffer_index: int) -> bool:
	var si := first_empty_shelf_index()
	if si < 0:
		return false
	return move_buffer_to_shelf(buffer_index, si)


# ===== 2.6 垃圾桶动作按阶段分流 =====
## refund=true（备货）→ 取消退料：原额返还食材、不记沉没成本；
## refund=false（营业）→ 作废：记 record_waste（沉没成本）、不返料。
func discard_from_buffer(index: int, refund: bool) -> bool:
	if index < 0 or index >= buffer.size():
		return false
	var item: Dictionary = buffer[index]
	buffer.remove_at(index)
	_apply_trash(item, refund, &"buffer")
	EventBus.buffer_changed.emit()
	return true


func discard_from_shelf(index: int, refund: bool) -> bool:
	if index < 0 or index >= shelf.size() or shelf[index] == null:
		return false
	var item: Dictionary = shelf[index]
	shelf[index] = null
	_apply_trash(item, refund, &"shelf")
	EventBus.shelf_changed.emit()
	return true


func _apply_trash(item: Dictionary, refund: bool, source: StringName) -> void:
	var rid: StringName = item.get("recipe_id", &"")
	if refund:
		_return_ingredients(item.get("recipe"))
	else:
		var cost := float(item.get("cost", 0.0))
		record_waste(rid, cost)
		EventBus.sushi_wasted.emit(rid, source)


# ===== 2.7 sales 取货源：仅从货架扣减 =====
## 移除货架上一份指定款式；成功返回该份沉没成本，失败返回 -1。
func remove_one_from_shelf(recipe_id: StringName) -> float:
	for i in shelf.size():
		var cell = shelf[i]
		if cell != null and cell.get("recipe_id") == recipe_id:
			var cost := float(cell.get("cost", 0.0))
			shelf[i] = null
			EventBus.shelf_changed.emit()
			return cost
	return -1.0


## 出餐台 + 货架某款成品总份数（供决策阶段「已备」展示）
func finished_count(recipe_id: StringName) -> int:
	var n := 0
	for item in buffer:
		if item.get("recipe_id") == recipe_id:
			n += 1
	n += shelf_count_of(recipe_id)
	return n


# ===== 2.9 结算清算：出餐台 / 货架剩余成品一律作废 =====
func settle_waste_all() -> void:
	for item in buffer:
		record_waste(item.get("recipe_id", &""), float(item.get("cost", 0.0)))
		EventBus.sushi_wasted.emit(item.get("recipe_id", &""), &"settlement")
	for cell in shelf:
		if cell != null:
			record_waste(cell.get("recipe_id", &""), float(cell.get("cost", 0.0)))
			EventBus.sushi_wasted.emit(cell.get("recipe_id", &""), &"settlement")
	buffer.clear()
	_init_shelf()
	reset_crafting()
	EventBus.buffer_changed.emit()
	EventBus.shelf_changed.emit()


## 清空制作队列与制作进度（进入结算 / 新一天时）
func reset_crafting() -> void:
	craft_queue.clear()
	craft_elapsed = 0.0
	crafting_paused = false
	_craft_started = false


# ===== 当日统计 =====

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


# ===== 存档（run_state 结构已变更：buffer/shelf 仅存 recipe_id+cost，不存 Recipe 引用） =====
## 注：正常存档点（结算后）出餐台/货架已清空；此处仅保证结构完整、加载不崩溃。

func to_dict() -> Dictionary:
	return {
		"cash": cash,
		"ingredient_stock": ingredient_stock.duplicate(true),
		"buffer_capacity": buffer_capacity,
		"shelf_size": shelf_size,
		"buffer": _items_to_plain(buffer),
		"shelf": _items_to_plain(shelf),
		"daily_stats": daily_stats.duplicate(true),
	}


func _items_to_plain(arr: Array) -> Array:
	var out: Array = []
	for it in arr:
		if it == null:
			out.append(null)
		else:
			out.append({"recipe_id": it.get("recipe_id", &""), "cost": float(it.get("cost", 0.0))})
	return out


func from_dict(data: Dictionary) -> void:
	cash = float(data.get("cash", 0.0))
	ingredient_stock = (data.get("ingredient_stock", {}) as Dictionary).duplicate(true)
	buffer_capacity = int(data.get("buffer_capacity", 4))
	shelf_size = int(data.get("shelf_size", 3))
	# 成品项无法完整恢复 Recipe 引用（结构变更），白盒阶段接受成品重置。
	buffer = []
	_init_shelf()
	craft_queue = []
	reset_crafting()
	daily_stats = (data.get("daily_stats", {}) as Dictionary).duplicate(true)
	if daily_stats.is_empty():
		reset_daily_stats()

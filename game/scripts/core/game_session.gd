extends Node
class_name GameSession
## 会话编排（game-session）— UI 与系统之间的唯一中枢
## 持有 RunState / ContentDB 内容集 / 当前 Location / Sales / RNG，
## 监听 DayCycle/EventBus 协调各阶段调用对应系统逻辑，并向 UI 暴露玩家动作与只读查询。
## 挂在主场景（main_game.tscn），暂不做 Autoload（避免与后续存档流程过早耦合）。

const DC = preload("res://scripts/core/day_cycle.gd")

## 初始现金
@export var starting_cash: float = 200.0
## 当前地点 id（缺失时兜底取第一个地点）
@export var location_id: StringName = &"school_street"
## 随机种子（0 = 每次随机；非 0 = 可复现）
@export var rng_seed: int = 0

var content: ContentDB
var state: RunState
var location: Location
var sales: Sales
var rng: RandomNumberGenerator


func _ready() -> void:
	# 供 UI 面板通过分组查找本会话
	add_to_group("game_session")

	rng = RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	# 3.1 载入内容、初始化运行状态、选定地点、创建售卖实例
	content = ContentDB.new()
	content.load_all()

	state = RunState.new()
	state.cash = starting_cash

	# 注入运行状态给 DayCycle，作为营业阶段制作时钟的推进目标（2b.1）
	DayCycle.set_run_state(state)

	location = content.get_location(location_id)
	if location == null:
		location = content.get_first_location()
	if location == null:
		push_warning("[GameSession] 未找到任何地点资源，售卖/结算将无法进行")

	sales = Sales.new(content.get_recipes(), rng)

	# 3.2 / 3.3 监听日周期
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.phase_changed.connect(_on_phase_changed)

	# 3.6 会话启动：延迟到下一帧，确保各 UI 面板先完成 _ready 与信号连接，
	# 能接收到首个 day_started / phase_changed(DECISION)
	call_deferred("_start_session")


func _start_session() -> void:
	DayCycle.start_new_day()


# ===== 阶段编排 =====

## 3.2 模拟阶段每 tick 推进售卖
func _on_tick_advanced(tick_index: int) -> void:
	if DayCycle.current_phase != DC.Phase.SIMULATION:
		return
	if location == null:
		return
	sales.process_tick(state, location, tick_index, DayCycle.get_ticks_per_day())


## 3.3 进入结算阶段触发日结算（Settlement 内部广播 day_settled）；不改动 DayCycle._settle
func _on_phase_changed(phase: int) -> void:
	if phase == DC.Phase.SETTLEMENT and location != null:
		Settlement.settle(state, location)


# ===== 3.4 玩家动作 =====

## 采购某食材 qty 个原料单位；成功返回 true
func request_buy(ingredient_id: StringName, qty: int) -> bool:
	var ing := content.get_ingredient(ingredient_id)
	if ing == null:
		return false
	return Procurement.buy(state, ing, qty, DayCycle.current_phase)


## 备货阶段即时生产一份该配方到出餐台；成功返回 true（出餐台满 / 料不足 / 非备货阶段则失败）
func request_produce_one(recipe_id: StringName) -> bool:
	if DayCycle.current_phase != DC.Phase.DECISION:
		return false
	var recipe := _find_recipe(recipe_id)
	if recipe == null:
		return false
	return state.produce_instant(recipe)


## 营业阶段把该配方加入制作队列（可重复入队叠加份数）；成功返回 true
func request_enqueue(recipe_id: StringName) -> bool:
	if DayCycle.current_phase != DC.Phase.SIMULATION:
		return false
	var recipe := _find_recipe(recipe_id)
	if recipe == null:
		return false
	state.enqueue_craft(recipe)
	return true


## 撤销一次入队（从队尾移除一份该配方）
func request_dequeue(recipe_id: StringName) -> bool:
	return state.dequeue_craft_last(recipe_id)


## 上架：出餐台第 buffer_index 份 → 货架 shelf_index 空格；成功返回 true
func request_stock(buffer_index: int, shelf_index: int) -> bool:
	return state.move_buffer_to_shelf(buffer_index, shelf_index)


## 出餐台某份拖到垃圾桶：备货=取消退料 / 营业=作废（按当前阶段分流）
func request_discard_buffer(buffer_index: int) -> bool:
	return state.discard_from_buffer(buffer_index, _is_refund_phase())


## 货架某份拖到垃圾桶：备货=取消退料 / 营业=作废
func request_discard_shelf(shelf_index: int) -> bool:
	return state.discard_from_shelf(shelf_index, _is_refund_phase())


## 当前是否处于「退料」语义阶段（仅备货阶段返料；开摊后为作废）
func _is_refund_phase() -> bool:
	return DayCycle.current_phase == DC.Phase.DECISION


## 开摊：决策阶段 → 模拟阶段
func open_stall() -> void:
	DayCycle.begin_simulation()


## 进入下一天：开新一天并重置当日统计（现金与库存跨天保留）
func start_next_day() -> void:
	DayCycle.start_new_day()
	state.reset_daily_stats()


# ===== 3.5 只读查询 =====

func get_cash() -> float:
	return state.cash


func get_stock(ingredient_id: StringName) -> float:
	return state.get_stock(ingredient_id)


func get_max_servings(recipe_id: StringName) -> int:
	var recipe := _find_recipe(recipe_id)
	if recipe == null:
		return 0
	return SushiMath.max_servings_for_recipe(recipe, state.ingredient_stock)


func get_finished_count(recipe_id: StringName) -> int:
	return state.finished_count(recipe_id)


# ===== 成品容器查询（供 UI 渲染出餐台 / 货架 / 队列） =====

func get_buffer_items() -> Array:
	return state.buffer


func get_buffer_capacity() -> int:
	return state.buffer_capacity


func is_buffer_full() -> bool:
	return state.is_buffer_full()


func get_shelf_items() -> Array:
	return state.shelf


func get_shelf_size() -> int:
	return state.shelf_size


func has_empty_shelf_slot() -> bool:
	return state.has_empty_shelf_slot()


func get_shelf_count_of(recipe_id: StringName) -> int:
	return state.shelf_count_of(recipe_id)


func get_queue_counts() -> Dictionary:
	return state.queue_counts()


func get_current_craft_recipe_id() -> StringName:
	var r := state.current_craft_recipe()
	return r.id if r != null else &""


func get_current_craft_ratio() -> float:
	return state.current_craft_ratio()


func is_crafting_paused() -> bool:
	return state.crafting_paused


func get_recipe_display_name(recipe_id: StringName) -> String:
	var r := _find_recipe(recipe_id)
	return r.display_name if r != null else String(recipe_id)


# ===== 供 UI 构建行的内容查询 =====

func get_ingredients() -> Array[Ingredient]:
	return content.get_ingredient_list()


func get_recipes() -> Array[Recipe]:
	return content.get_recipes()


func get_location() -> Location:
	return location


func _find_recipe(recipe_id: StringName) -> Recipe:
	for r in content.recipes:
		if r != null and r.id == recipe_id:
			return r
	return null

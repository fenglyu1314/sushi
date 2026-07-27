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
	sales.process_tick(state, location, tick_index, DC.TICKS_PER_DAY)


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


## 生产某配方 servings 份；返回实际生产份数
func request_produce(recipe_id: StringName, servings: int) -> int:
	var recipe := _find_recipe(recipe_id)
	if recipe == null:
		return 0
	return Production.produce(state, recipe, servings, DayCycle.current_phase)


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

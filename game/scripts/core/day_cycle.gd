extends Node
## 时间 / tick 系统（Autoload 单例）
## 驱动"一天为一局"的双阶段循环：决策(暂停) → 模拟(按真实时间推进) → 结算 → 下一天。
##
## 营业阶段用单一时间时钟（_process 累加 delta）统一驱动：
##   1) 制作时钟 advance_crafting(delta)；
##   2) 按经过时间跨越 tick 边界触发售卖采样（tick_advanced）；
##   3) 累计到 DAY_DURATION_SEC 即进入结算。
## 这样制作与售卖共用同一时间轴，天然同起同停，且"一天多长"由 DAY_DURATION_SEC 单点可调。

enum Phase { DECISION, SIMULATION, SETTLEMENT }

## 一天营业时长（真实秒）——核心手感参数：越大越从容。
## 参考：单份 craft_time≈4s、出餐台容量 4、货架 9 格，一天想做十几二十份 → 60~120s 较合适。
const DAY_DURATION_SEC: float = 90.0

## 售卖采样次数（把全天人流量均摊到各 tick）。越大顾客到达越平滑；
## 与 school_street 人流量 20 相近时约每 tick 到 1 人。
const TICKS_PER_DAY: int = 20

## 每个 tick 的真实秒数（由上面两者推导，不单独配置）。
const TICK_INTERVAL: float = DAY_DURATION_SEC / TICKS_PER_DAY

var current_day: int = 0
var current_phase: int = Phase.DECISION
var current_tick: int = 0

## 制作时钟驱动目标：营业阶段每帧调用其 advance_crafting(delta)。
## 由 GameSession 在 _ready 时通过 set_run_state 注入（day_cycle 不主动依赖会话）。
var _run_state: RunState = null

## 当天已营业秒数（仅 SIMULATION 阶段累加）。
var _day_elapsed: float = 0.0


## 注入当前运行状态，作为营业阶段制作时钟的推进目标
func set_run_state(state: RunState) -> void:
	_run_state = state


## 营业阶段单一时间时钟：推进制作 + 按时间跨 tick 触发售卖 + 到点结算。
## 备货 / 结算阶段不推进（守卫返回），保证制作与售卖同起同停。
func _process(delta: float) -> void:
	if current_phase != Phase.SIMULATION:
		return

	_day_elapsed += delta

	# 1) 推进制作时钟
	if _run_state != null:
		_run_state.advance_crafting(delta)

	# 2) 按经过时间跨越 tick 边界触发售卖采样（可能一帧跨多 tick）
	while current_tick < TICKS_PER_DAY and _day_elapsed >= float(current_tick + 1) * TICK_INTERVAL:
		current_tick += 1
		EventBus.tick_advanced.emit(current_tick)

	# 3) 到达一天营业时长 → 进入结算
	if _day_elapsed >= DAY_DURATION_SEC:
		set_phase(Phase.SETTLEMENT)


## 开启新的一天（day +1，进入决策阶段）
func start_new_day() -> void:
	current_day += 1
	current_tick = 0
	_day_elapsed = 0.0
	EventBus.day_started.emit(current_day)
	set_phase(Phase.DECISION)


## 切换阶段
func set_phase(p: int) -> void:
	current_phase = p
	EventBus.phase_changed.emit(p)
	match p:
		Phase.SIMULATION:
			current_tick = 0
			_day_elapsed = 0.0
		Phase.SETTLEMENT:
			_settle()


## 决策阶段完成后调用，进入模拟
func begin_simulation() -> void:
	if current_phase == Phase.DECISION:
		set_phase(Phase.SIMULATION)


# ===== 只读查询（供 UI 显示营业进度 / 倒计时）=====

## 当天已营业秒数
func get_day_elapsed() -> float:
	return _day_elapsed


## 当天营业剩余秒数（下限 0）
func get_day_remaining() -> float:
	return maxf(0.0, DAY_DURATION_SEC - _day_elapsed)


## 当天营业进度 0→1
func get_day_progress() -> float:
	if DAY_DURATION_SEC <= 0.0:
		return 1.0
	return clampf(_day_elapsed / DAY_DURATION_SEC, 0.0, 1.0)


func _settle() -> void:
	# M0：空结算，仅发出 day_ended 信号
	EventBus.day_ended.emit(current_day)

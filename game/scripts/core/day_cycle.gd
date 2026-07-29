extends Node
## 时间 / tick 系统（Autoload 单例）
## 驱动"一天为一局"的双阶段循环：决策(暂停) → 模拟(按真实时间推进) → 结算 → 下一天。
##
## 营业阶段用单一时间时钟（_process 累加缩放后的 delta）统一驱动：
##   1) 制作时钟 advance_crafting(scaled)；
##   2) 按经过时间跨越 tick 边界触发售卖采样（tick_advanced）；
##   3) 累计到「一天营业时长」即进入结算。
## 这样制作与售卖共用同一时间轴，天然同起同停，且时间参数（一天时长 / tick 密度 /
## 倍速）均由 GameConfig 单点可调（见 res://data/config/game_config.tres）。

enum Phase { DECISION, SIMULATION, SETTLEMENT }

## 配置实例固定路径；缺失 / 加载失败时回退到 GameConfig 默认值实例。
const CONFIG_PATH: String = "res://data/config/game_config.tres"

## 时间参数配置（一天时长 / tick 采样次数 / 时间倍速），_ready 时加载。
var _config: GameConfig = null

var current_day: int = 0
var current_phase: int = Phase.DECISION
var current_tick: int = 0

## 制作时钟驱动目标：营业阶段每帧调用其 advance_crafting(delta)。
## 由 GameSession 在 _ready 时通过 set_run_state 注入（day_cycle 不主动依赖会话）。
var _run_state: RunState = null

## 当天已营业秒数（仅 SIMULATION 阶段累加）。
var _day_elapsed: float = 0.0


## 加载时间参数配置：从固定路径读取 GameConfig；缺失 / 类型不符时用默认实例兜底。
func _ready() -> void:
	var res := load(CONFIG_PATH)
	if res is GameConfig:
		_config = res
	else:
		_config = GameConfig.new()


# ===== 时间参数取值出口（供内外统一读取，均已在 GameConfig 内做非法值兜底）=====

## 一天营业时长（真实秒，常速下）。
func get_day_duration_sec() -> float:
	return _config.get_day_duration_sec()


## 一天售卖采样次数。
func get_ticks_per_day() -> int:
	return _config.get_ticks_per_day()


## 时间倍速系数（0 = 暂停，1.0 = 常速）。
func get_time_scale() -> float:
	return _config.get_time_scale()


## 注入当前运行状态，作为营业阶段制作时钟的推进目标
func set_run_state(state: RunState) -> void:
	_run_state = state


## 营业阶段单一时间时钟：推进制作 + 按时间跨 tick 触发售卖 + 到点结算。
## 备货 / 结算阶段不推进（守卫返回），保证制作与售卖同起同停。
func _process(delta: float) -> void:
	if current_phase != Phase.SIMULATION:
		return

	# 时间倍速缩放：营业倒计时与制作进度共用同一缩放，天然同起同停；
	# time_scale = 0 时 scaled = 0，营业与制作双双静止。
	var scaled := delta * get_time_scale()
	_day_elapsed += scaled

	# 1) 推进制作时钟
	if _run_state != null:
		_run_state.advance_crafting(scaled)

	# 2) 按经过时间跨越 tick 边界触发售卖采样（可能一帧跨多 tick）；
	#    tick 间隔按 day_duration_sec / ticks_per_day 实时推导，改配置即时生效。
	var ticks_per_day := get_ticks_per_day()
	var tick_interval := get_day_duration_sec() / float(ticks_per_day)
	while current_tick < ticks_per_day and _day_elapsed >= float(current_tick + 1) * tick_interval:
		current_tick += 1
		EventBus.tick_advanced.emit(current_tick)

	# 3) 到达一天营业时长 → 进入结算
	if _day_elapsed >= get_day_duration_sec():
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
	return maxf(0.0, get_day_duration_sec() - _day_elapsed)


## 当天营业进度 0→1
func get_day_progress() -> float:
	var duration := get_day_duration_sec()
	if duration <= 0.0:
		return 1.0
	return clampf(_day_elapsed / duration, 0.0, 1.0)


func _settle() -> void:
	# M0：空结算，仅发出 day_ended 信号
	EventBus.day_ended.emit(current_day)

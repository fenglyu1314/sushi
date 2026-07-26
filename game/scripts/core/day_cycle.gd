extends Node
## 时间 / tick 系统（Autoload 单例）
## 驱动"一天为一局"的双阶段循环：决策(暂停) → 模拟(tick推进) → 结算 → 下一天。
## 模拟阶段用固定步长 tick，不依赖帧率，便于加速/暂停/存档。

enum Phase { DECISION, SIMULATION, SETTLEMENT }

# M0 占位数值，后续由数据/平衡表驱动（数值待定）
const TICKS_PER_DAY: int = 8
const TICK_INTERVAL: float = 0.5  # 模拟阶段每个 tick 的真实秒数

var current_day: int = 0
var current_phase: int = Phase.DECISION
var current_tick: int = 0

var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = TICK_INTERVAL
	_timer.timeout.connect(_on_tick)
	add_child(_timer)


## 开启新的一天（day +1，进入决策阶段）
func start_new_day() -> void:
	current_day += 1
	current_tick = 0
	EventBus.day_started.emit(current_day)
	set_phase(Phase.DECISION)


## 切换阶段
func set_phase(p: int) -> void:
	current_phase = p
	EventBus.phase_changed.emit(p)
	match p:
		Phase.DECISION:
			_timer.stop()
		Phase.SIMULATION:
			current_tick = 0
			_timer.start()
		Phase.SETTLEMENT:
			_timer.stop()
			_settle()


## 决策阶段完成后调用，进入模拟
func begin_simulation() -> void:
	if current_phase == Phase.DECISION:
		set_phase(Phase.SIMULATION)


func _on_tick() -> void:
	current_tick += 1
	EventBus.tick_advanced.emit(current_tick)
	if current_tick >= TICKS_PER_DAY:
		set_phase(Phase.SETTLEMENT)


func _settle() -> void:
	# M0：空结算，仅发出 day_ended 信号
	EventBus.day_ended.emit(current_day)

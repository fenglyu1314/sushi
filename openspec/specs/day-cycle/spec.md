### Requirement: 三阶段状态机
`DayCycle` SHALL 以三阶段驱动一天循环：`DECISION`（决策，暂停）→ `SIMULATION`（模拟，tick 推进）→ `SETTLEMENT`（结算）。阶段用 `Phase` 枚举表示。

#### Scenario: 阶段枚举定义
- **WHEN** 审查 `DayCycle` 脚本
- **THEN** 存在 `enum Phase { DECISION, SIMULATION, SETTLEMENT }`

### Requirement: 开启新一天
`DayCycle` SHALL 提供 `start_new_day()` 方法：将 `current_day` 加 1，重置 `current_tick` 为 0，发射 `day_started(day)` 信号，并进入 `DECISION` 阶段。

#### Scenario: 调用 start_new_day
- **WHEN** 调用 `DayCycle.start_new_day()`
- **THEN** `current_day` 递增 1，`current_tick` 归 0，`day_started` 被发射，当前阶段为 `DECISION`

### Requirement: 阶段切换发信号
`DayCycle` SHALL 提供 `set_phase(p)` 方法切换阶段：更新 `current_phase`，发射 `phase_changed(p)` 信号，并按阶段启停 tick 计时（DECISION 停、SIMULATION 启动并重置 tick、SETTLEMENT 停并执行结算）。

#### Scenario: 切换到模拟阶段
- **WHEN** 当前为 `DECISION`，调用 `set_phase(SIMULATION)`
- **THEN** `current_phase` 变为 `SIMULATION`，`phase_changed` 被发射，tick 计时启动，`current_tick` 归 0

#### Scenario: 切换到结算阶段
- **WHEN** 模拟阶段 tick 达上限后调用 `set_phase(SETTLEMENT)`
- **THEN** tick 计时停止，`phase_changed` 被发射，执行结算

### Requirement: 决策阶段进入模拟
`DayCycle` SHALL 提供 `begin_simulation()` 方法：仅当当前阶段为 `DECISION` 时，切换到 `SIMULATION`。

#### Scenario: 决策阶段调用 begin_simulation
- **WHEN** 当前为 `DECISION`，调用 `begin_simulation()`
- **THEN** 阶段切换为 `SIMULATION`

#### Scenario: 非决策阶段调用 begin_simulation 无效
- **WHEN** 当前非 `DECISION`，调用 `begin_simulation()`
- **THEN** 阶段不变

### Requirement: 模拟阶段固定步长 tick 推进
`DayCycle` SHALL 在 `SIMULATION` 阶段用 `Timer` 以固定间隔触发 tick：每次 tick 将 `current_tick` 加 1，发射 `tick_advanced(tick)` 信号；当 `current_tick` 达到 `TICKS_PER_DAY` 时，自动切换到 `SETTLEMENT` 阶段。tick 步长不依赖帧率。

#### Scenario: tick 推进与信号
- **WHEN** 处于 `SIMULATION` 阶段，Timer 触发一次
- **THEN** `current_tick` 加 1，`tick_advanced` 被发射

#### Scenario: tick 达上限进入结算
- **WHEN** `current_tick` 达到 `TICKS_PER_DAY`
- **THEN** 自动切换到 `SETTLEMENT` 阶段

### Requirement: 结算发射 day_ended
`DayCycle` SHALL 在进入 `SETTLEMENT` 阶段时执行结算：M0 阶段结算为空，仅发射 `day_ended(day)` 信号。

#### Scenario: 结算发射信号
- **WHEN** 阶段切换到 `SETTLEMENT`
- **THEN** `day_ended(current_day)` 被发射

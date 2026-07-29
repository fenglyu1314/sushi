## MODIFIED Requirements

### Requirement: 模拟阶段真实时间时钟推进

`DayCycle` SHALL 在 `SIMULATION` 阶段以单一时间时钟按真实时间推进（累加每帧 `delta`，不依赖固定帧率）：随经过时间跨越 tick 采样边界时，每跨一格将 `current_tick` 加 1 并发射 `tick_advanced(tick)` 信号；当已营业时间累计达到「一天营业时长」时，自动切换到 `SETTLEMENT` 阶段。一天的营业时长与 tick 采样次数来自 `GameConfig`（`day_duration_sec` / `ticks_per_day`），单个 tick 间隔由二者推导。

#### Scenario: 按时间跨 tick 边界发信号
- **WHEN** 处于 `SIMULATION` 阶段，累计营业时间跨过一个 tick 采样边界
- **THEN** `current_tick` 加 1，`tick_advanced` 被发射（一帧内跨多格则连续多次）

#### Scenario: 达到一天营业时长进入结算
- **WHEN** 累计营业时间达到 `day_duration_sec`
- **THEN** 自动切换到 `SETTLEMENT` 阶段

## ADDED Requirements

### Requirement: 时间参数来自配置

`DayCycle` SHALL 从 `GameConfig` 取得一天营业时长与 tick 采样次数，而非硬编码常量；配置缺失或非法时使用 `GameConfig` 定义的默认值。修改配置 MUST 无需改动 `DayCycle` 逻辑代码即可改变一天的时长与采样密度。

#### Scenario: 配置生效
- **WHEN** `GameConfig.day_duration_sec` 被设为 `120`
- **THEN** 一天营业时长为 120 真实秒（受 `time_scale` 缩放）

#### Scenario: 缺失配置用默认
- **WHEN** 未提供有效 `GameConfig`
- **THEN** `DayCycle` 以默认 90 秒 / 20 次运行，不崩溃

### Requirement: 营业时钟按倍速缩放

`DayCycle` SHALL 在 `SIMULATION` 阶段按 `GameConfig.time_scale` 缩放时间流逝，缩放同时作用于营业倒计时与制作时钟，保证二者同起同停。当 `time_scale` 为 `0` 时营业时间与制作均暂停；决策阶段与结算阶段不受影响。

#### Scenario: 暂停营业
- **WHEN** `SIMULATION` 阶段 `time_scale` 为 `0`
- **THEN** 营业已用时间不增长、制作进度不推进，一天不结束

#### Scenario: 加速营业
- **WHEN** `SIMULATION` 阶段 `time_scale` 为 `2.0`
- **THEN** 每现实秒推进 2 秒游戏时间，制作进度与营业倒计时同步加速

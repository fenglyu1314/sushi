## ADDED Requirements

### Requirement: 事件总线作为全局 Autoload 存在
系统 SHALL 提供 `EventBus` Autoload 单例，启动后任意脚本可通过全局名 `EventBus` 访问，无需实例化。

#### Scenario: 启动后可全局访问
- **WHEN** 工程启动且 Autoload 已注册
- **THEN** 任意脚本可通过 `EventBus` 全局名访问该单例

### Requirement: 声明日周期信号且不含业务逻辑
`EventBus` SHALL 声明以下信号供系统间通信，且自身不含业务逻辑：
- `day_started(day_index: int)`
- `phase_changed(phase: int)`
- `tick_advanced(tick_index: int)`
- `day_ended(day_index: int)`

#### Scenario: 信号可被发射与监听
- **WHEN** 某系统调用 `EventBus.day_started.emit(1)`
- **THEN** 已连接 `day_started` 的监听方收到回调，参数为 `1`

#### Scenario: 总线不含业务逻辑
- **WHEN** 审查 `event_bus.gd` 内容
- **THEN** 文件只声明信号，无 `_ready` 或处理函数等业务逻辑

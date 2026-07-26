## Context

当前状态：Godot 4.7.1 空工程已建于 `game/`，无任何脚本。M0 需在此基础上建立时间/tick 地基。

约束（见 `docs/02-技术架构.md`）：
- 语言 GDScript；不直接编辑 `project.godot`（Autoload 在编辑器注册）。
- 时间模型：一天为一局 + 内部 tick 推进（决策→模拟→结算）。
- 架构分层：数据层(Resource) → 模拟层(纯逻辑) → 表现层(节点/UI)；模拟层尽量不依赖节点树，便于 M2 起用 GUT 测试。
- 事件总线为全局 Autoload 信号中枢，系统间解耦。

## Goals / Non-Goals

**Goals:**
- 建立可跑通的"一天循环"地基：决策→模拟→结算→下一天。
- 事件总线作为系统间解耦通信中枢。
- 存档机制可存读日周期状态。
- `DayCycle` 核心逻辑（状态转移、tick 计数）与节点树尽量解耦，便于后续测试。

**Non-Goals:**
- 不实现具体玩法（采购/生产/售卖等属 M1+）。
- 不做 UI（M0 用 `print` 验证）。
- 不做美术（纯逻辑验证）。
- 不引入 GUT 测试框架（M2 起）。
- 不敲定 tick 数值/间隔（M0 占位，M1 平衡时确定）。

## Decisions

### 1. 三个组件均做 Autoload 单例
`EventBus` / `DayCycle` / `SaveManager` 都注册为 Autoload。
- 理由：当前阶段/tick/存档需全局访问；`EventBus` 是架构约定的中枢；全局状态散落各场景不便。
- 备选：`DayCycle`/`SaveManager` 做成场景内节点。否决：全局共享状态用 Autoload 更直接，且避免场景切换丢失。

### 2. tick 用 Timer 驱动，而非 _process 累积
`DayCycle` 内部 `Timer` 触发 tick，固定步长。
- 理由：固定步长、不依赖帧率（架构 §3）；暂停即 `timer.stop()`，加速调 `wait_time`。
- 备选：`_process(delta)` 累积时间。否决：帧率波动影响节奏，暂停/加速需额外逻辑。

### 3. EventBus 只声明信号，不含逻辑
- 理由：单一职责，纯通信中枢；业务逻辑在发射方/监听方。
- 备选：总线带处理逻辑。否决：违反解耦初衷。

### 4. phase 参数用 int
`phase_changed(phase: int)`，值对应 `DayCycle.Phase` 枚举。
- 理由：Godot 信号用枚举类型跨脚本引用繁琐，`int` 是常见做法。
- 备选：用枚举类型。否决：信号参数 `int` 更通用，监听方自行与枚举比对。

### 5. 存档用 JSON + user:// 路径
`SaveManager` 用 `JSON.stringify` 写 `user://savegame.json`。
- 理由：JSON 可读易调试；`user://` 是 Godot 跨平台持久化路径；M0 数据简单（几个数字）。
- 备选：Godot Resource 序列化(.tres/.res)。否决：M0 数据过简，JSON 更轻；复杂数据后续再评估。

### 6. Autoload 注册顺序：EventBus → DayCycle → SaveManager
- 理由：`DayCycle` 引用 `EventBus`（emit 信号），`SaveManager` 引用 `DayCycle`（读写状态）。按依赖顺序注册保证 `_ready` 时依赖已就绪。

## Risks / Trade-offs

- [Autoload 单例不利于单元测试] → `DayCycle` 状态转移/tick 计数逻辑写成与节点树无强耦合的方法，M2 引入 GUT 时可针对性测试。
- [tick 数值/间隔为占位] → 代码中标注待定，M1 平衡时确定，不影响 M0 验证。
- [M0 无 UI，仅 print 验证] → 可接受，M0 目标是验证循环跑通；M1 起补 UI。
- [JSON 存档后续可能不够] → M0 仅验证存读机制；复杂存档（库存/布局/进度）后续再评估格式。

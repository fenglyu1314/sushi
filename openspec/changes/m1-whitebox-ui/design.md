## Context

M1 的数据层与模拟层已完成并归档：数据资源类（`Ingredient`/`Recipe`/`CustomerType`/`CustomerWeight`/`Location`/`RecipeIngredient`）、纯逻辑系统（`Procurement`/`Production`/`Sales`/`Settlement`）、运行状态 `RunState`，以及 M0 的 `DayCycle`（Autoload）、`EventBus`（Autoload）、`SaveManager`。当前唯一的"驱动方"是 `m1_harness.gd`：它内联硬编码内容、用写死的采购/生产计划跑 headless 验证机制。

本变更要补上**人可交互的白盒 UI**，让玩家亲自做决策以验证 M1"好不好玩"；同时把内联内容迁移为 `.tres` 数据资源。约束：AI 只写 `.gd` 脚本，`.tres` 与 `.tscn` 由用户在编辑器内按指导创建（`AGENT.md` §3.1/§3.5）；美术全程白盒占位（§4.4）。

关键既有接口（脚本据此对接，不改其行为）：
- `Procurement.buy(state, ingredient, quantity, phase) -> bool`（仅决策阶段、现金足够才成功）。
- `Production.produce(state, recipe, servings, phase) -> int`（返回实际份数，受库存/辅料上限约束）。
- `SushiMath.max_servings_for_recipe(recipe, stock) -> int`（UI 预览"最多可做几份"）。
- `Sales.new(recipes, rng).process_tick(state, location, tick_index, total_ticks)`（每 tick 推进售卖）。
- `Settlement.settle(state, location) -> Dictionary`（收摊结算，返回复盘数据）。
- `DayCycle`：`start_new_day()`、`begin_simulation()`、`Phase{DECISION,SIMULATION,SETTLEMENT}`、常量 `TICKS_PER_DAY`/`TICK_INTERVAL`；`_settle()` 目前只发 `day_ended`（空结算）。
- `EventBus` 信号：`day_started`/`phase_changed`/`tick_advanced`/`day_ended`/`sale_made`/`customer_lost`/`sushi_discarded`/`day_settled`。

## Goals / Non-Goals

**Goals:**
- 玩家能在决策阶段查看现金/库存、采购食材、生产寿司（含"最多可做几份"与成本预览），点"开摊"进入模拟。
- 模拟阶段可视化 tick 推进，实时反馈成交/流失、成品余量与营收。
- 结算阶段呈现完整复盘（营收/采购/租金/浪费/净利 + 各款售出/作废/流失），可"进入下一天"连续多天游玩。
- 内容来自 `.tres` 数据资源，新增/调整内容无需改脚本。
- 全程白盒占位，可读、可运行。

**Non-Goals:**
- 正式美术、动画、音效。
- 空间约束（冰箱/货架占格）、临场排队/取货位/犹豫窗口、热度/情报/流言/随机事件、食材保质期（均属后续里程碑）。
- 新的存档界面（沿用既有 `SaveManager`，可选热键触发，不做 UI）。
- GUT 自动化测试（M2 起）。

## Decisions

### D1 — 内容加载：`ContentDB` 扫描约定目录加载 `.tres`
新增 `game/scripts/systems/content_db.gd`（`RefCounted` 或轻量 Node），从约定目录（建议 `res://data/`，按类型分子目录：`ingredients/`、`recipes/`、`customers/`、`locations/`）用 `ResourceLoader` 扫描并加载全部 `.tres`，构建：
- `ingredients: Dictionary`（id → `Ingredient`）
- `recipes: Array[Recipe]`
- `locations: Dictionary`（id → `Location`）

**为什么按目录扫描而非维护一张手写清单**：符合"加内容不改代码"——用户在编辑器里新建一个 `.tres` 丢进目录即生效。`Recipe`/`Location` 通过 `.tres` 内嵌的 `RecipeIngredient`/`CustomerWeight` 子资源强类型引用其它资源，加载时自动带出依赖，无需手动拼接。
**替代方案**：单一"总清单 .tres" 引用所有内容——更集中但每次加内容都要改清单资源，且仍需用户编辑器操作，收益不大。故选目录扫描。

### D2 — 会话编排：`GameSession` 作为 UI 与系统之间的唯一中枢
新增 `game/scripts/core/game_session.gd`（Node，挂主场景；暂不做 Autoload，避免与后续存档流程耦合过早）。职责：
- 持有 `RunState`、`ContentDB` 内容集、当前 `Location`、`Sales` 实例、`RandomNumberGenerator`。
- 监听 `DayCycle`/`EventBus`，在 `phase_changed` 时协调：模拟阶段每个 `tick_advanced` 调 `Sales.process_tick`；结算阶段调 `Settlement.settle` 并转发复盘数据。
- 向 UI 暴露玩家动作 API：`request_buy(ingredient_id, qty)`、`request_produce(recipe_id, servings)`、`open_stall()`（= `DayCycle.begin_simulation`）、`start_next_day()`。这些方法内部调用既有系统函数并回传结果（成功/失败、实际份数）供 UI 反馈。
- 提供只读查询给 UI：现金、某食材库存、某配方 `max_servings`、成品各款份数等（薄封装 `RunState`/`SushiMath`）。

**为什么加这层而不让 UI 直接调系统**：UI 面板多、阶段切换多，集中编排可避免每个面板各自持有 state/rng 造成状态分裂；也让 UI 只依赖 `GameSession` 一个接口，后续替换/扩展 UI 成本低。

### D3 — 结算触发权归 `GameSession`，`DayCycle._settle` 不改
`DayCycle._settle()` 目前是空结算（只发 `day_ended`）。`GameSession` 监听到进入 `SETTLEMENT`（或 `day_ended`）后调用 `Settlement.settle(state, location)`，由 `Settlement` 内部广播 `day_settled`。这样**不改动 M0 `DayCycle` 的既有需求**，结算业务留在 M1 系统层，符合分层。
**替代方案**：把 `Settlement` 调用塞进 `DayCycle._settle`——会让核心时间系统依赖 M1 业务逻辑，违背"模拟层与节点树/上层解耦"。否决。

### D4 — UI 结构：三面板 + 阶段驱动显隐，全白盒
UI 脚本放 `game/scripts/ui/`，对应场景 `.tscn` 由用户搭建：
- `decision_panel`：现金/库存展示；每种食材一行（数量步进 + 采购按钮 + 单价/小计预览）；每个配方一行（当前可做上限 + 份数步进 + 生产按钮 + 单份成本预览）；"开摊"按钮。
- `simulation_panel`：进度（tick/总 tick）、成品余量列表、实时营收/成交/流失计数、成交/流失滚动日志（订阅 `sale_made`/`customer_lost`）。
- `settlement_panel`：复盘表（营收/采购/租金/浪费/净利）、各款售出/作废/流失明细、现金变化；"进入下一天"按钮；预留"流言"占位区（后续里程碑填充）。

由一个根 UI 控制器按 `phase_changed` 切换三面板可见性。白盒：`Panel`/`ColorRect` + `Label`/`Button`，固定网格对齐，纯色区分（如现金绿、亏损红）。

**为什么分三个独立面板而非单屏全塞**：阶段职责清晰、切换直观，且与"决策→模拟→结算"心智模型一致，利于验证节奏感。

### D5 — 主场景切换：新增白盒主场景，保留 M0/M1 验证入口
新增一个 `main_game.tscn`（用户创建）承载 `GameSession` + UI，作为运行主场景。保留 `main.tscn`（M0 演示）与 `test_m1.tscn`（headless 验证）不动，便于回归对照。是否把 `project.godot` 主场景切到新场景由用户在编辑器决定。

## Risks / Trade-offs

- [内容目录约定与实际不符导致加载为空] → `ContentDB` 加载后校验数量并 `push_warning`；tasks 中明确目录路径与命名，UI 在无内容时显示占位提示而非崩溃。
- [`.tres` 内嵌子资源引用（RecipeIngredient/CustomerWeight）用户配置易错] → tasks 给出逐字段填写清单与"创建顺序"（先食材/顾客，再配方/地点引用它们）。
- [`TICK_INTERVAL=0.5s` 全天仅 8 tick，模拟阶段一闪而过，反馈不足] → 反馈以累计计数 + 滚动日志呈现，保证即使很快也能看清结果；播放速度调参留待手感验证时按需微调（数值待定，不在本变更硬编码新值）。
- [`GameSession` 非 Autoload，后续接存档需要序列化会话状态] → 本变更只依赖既有 `RunState.to_dict/from_dict` 与 `SaveManager`，存档 UI 明确列为 Non-goal，避免过早耦合。
- [AI 不能建 `.tscn`/`.tres`，落地依赖用户手动操作] → tasks 把用户操作与 AI 脚本任务分离标注，脚本先行、场景随后，二者通过约定的节点路径/信号名对齐。

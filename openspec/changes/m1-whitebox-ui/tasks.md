> 标注约定：`[AI]` = AI 落地的脚本任务；`[用户]` = 需在 Godot 编辑器内手动完成（AI 只提供分步指导，见 `AGENT.md` §3.1/§3.5）。

## 1. 数据资源目录与内容 `.tres` 创建

- [ ] 1.1 [用户] 在 Godot 编辑器 FileSystem 中创建目录：`res://data/ingredients/`、`res://data/recipes/`、`res://data/customers/`、`res://data/locations/`（右键 New Folder；此约定与 §2.1 `ContentDB` 扫描路径一致）
- [ ] 1.2 [用户] 创建食材 `.tres`（存入 `data/ingredients/`，New Resource → 选脚本类 `Ingredient`）。占位内容同 M1 content-manifest：
  - `salmon`（三文鱼）：id=`salmon`, display_name="三文鱼", base_price=8.0, unit_amount=300.0, category=MAIN
  - `tuna`（金枪鱼）：id=`tuna`, base_price=10.0, unit_amount=300.0, category=MAIN
  - `tamago`（玉子）：id=`tamago`, base_price=5.0, unit_amount=250.0, category=MAIN
  - `rice`（米饭）：id=`rice`, base_price=3.0, unit_amount=1000.0, category=SUB
  - `nori`（紫菜）：id=`nori`, base_price=2.0, unit_amount=500.0, category=SUB
- [ ] 1.3 [用户] 创建配方 `.tres`（存入 `data/recipes/`，脚本类 `Recipe`）。`ingredients` 数组每项为一个内嵌 `RecipeIngredient`（ingredient 指向 §1.2 对应食材、填 amount_per_serving）；`flavor_tags` 填 StringName 数组：
  - `salmon_nigiri`（三文鱼握寿司）：price=12.0, 用料=[salmon:30, rice:20], tags=[fish, salmon, classic]
  - `tuna_nigiri`（金枪鱼握寿司）：price=14.0, 用料=[tuna:30, rice:20], tags=[fish, tuna]
  - `tamago_nigiri`（玉子握寿司）：price=8.0, 用料=[tamago:25, rice:20, nori:5], tags=[sweet, tamago, veggie]
- [ ] 1.4 [用户] 创建顾客类型 `.tres`（存入 `data/customers/`，脚本类 `CustomerType`）。`preference_tags` 为 Dictionary（StringName→float）：
  - `student_fish`（爱吃鱼的学生）：prefs={fish:2.0, salmon:1.0}, appear_weight=3.0
  - `student_tuna`（金枪鱼党学生）：prefs={tuna:2.0, fish:1.0}, appear_weight=2.0
  - `student_sweet`（嗜甜学生）：prefs={sweet:2.0, tamago:1.0}, appear_weight=1.0
- [ ] 1.5 [用户] 创建地点 `.tres`（存入 `data/locations/`，脚本类 `Location`）：`school_street`（学校街），foot_traffic=20, spending_power=0.9, rent=30.0；`customer_mix` 数组每项为内嵌 `CustomerWeight`（customer_type 指向 §1.4 顾客、weight 分别 3.0/2.0/1.0）
- [ ] 1.6 [用户] 保存全部资源后，确认 FileSystem 中四个目录各含对应 `.tres`，且配方/地点的内嵌引用无红色缺失提示

## 2. 内容加载 ContentDB（content-loading）

- [ ] 2.1 [AI] 新增 `game/scripts/systems/content_db.gd`：扫描 `res://data/{ingredients,recipes,customers,locations}/` 加载全部 `.tres`，构建 `ingredients`(id→Ingredient)、`recipes`(Array[Recipe])、`locations`(id→Location)
- [ ] 2.2 [AI] 提供只读查询：`get_ingredient(id)`、`get_location(id)`、`get_recipes()`；查询不存在的 id 返回 null，遍历返回副本或只读视图避免外部改写
- [ ] 2.3 [AI] 目录缺失/为空时不崩溃：返回空内容集并 `push_warning`，记录各类型加载数量便于自检

## 3. 会话编排 GameSession（game-session）

- [ ] 3.1 [AI] 新增 `game/scripts/core/game_session.gd`（Node）：初始化 `RunState`（设初始现金）、载入 `ContentDB`、选定当前 `Location`、创建 `Sales` 与 `RandomNumberGenerator`
- [ ] 3.2 [AI] 监听 `EventBus`/`DayCycle`：模拟阶段每次 `tick_advanced` 调 `Sales.process_tick(state, location, tick, TICKS_PER_DAY)`
- [ ] 3.3 [AI] 进入结算阶段（监听 `phase_changed`==SETTLEMENT 或 `day_ended`）调 `Settlement.settle(state, location)`（`Settlement` 内部广播 `day_settled`）；不改动 `DayCycle._settle`
- [ ] 3.4 [AI] 暴露玩家动作：`request_buy(ingredient_id, qty)->bool`、`request_produce(recipe_id, servings)->int`、`open_stall()`（=`DayCycle.begin_simulation`）、`start_next_day()`（=`DayCycle.start_new_day` + `reset_daily_stats`）
- [ ] 3.5 [AI] 暴露只读查询：`get_cash()`、`get_stock(id)`、`get_max_servings(recipe_id)`（用 `SushiMath.max_servings_for_recipe`）、`get_finished_count(recipe_id)`
- [ ] 3.6 [AI] 会话启动：加载内容后经 `DayCycle.start_new_day()` 进入第一天决策阶段

## 4. 决策阶段 UI（decision-ui）

- [ ] 4.1 [AI] 新增 `game/scripts/ui/decision_panel.gd`：绑定 `GameSession`，进入决策阶段/每次动作后刷新现金、各食材库存、各配方可做份数
- [ ] 4.2 [AI] 采购交互：每种食材一行（数量步进 + 单价/小计预览 + 采购按钮），调 `request_buy`，成功刷新、现金不足提示
- [ ] 4.3 [AI] 生产交互：每个配方一行（份数步进 + 单份成本预览 + 当前可做上限 + 生产按钮），调 `request_produce` 并反馈实际份数；可做份数为 0 时禁用按钮
- [ ] 4.4 [AI] "开摊"按钮调 `open_stall()`
- [ ] 4.5 [用户] 搭建 `DecisionPanel` 白盒场景/节点（Panel + VBox 行 + Label/SpinBox/Button），挂 `decision_panel.gd`，按脚本约定的节点路径/信号命名连接

## 5. 模拟阶段 UI（simulation-ui）

- [ ] 5.1 [AI] 新增 `game/scripts/ui/simulation_panel.gd`：订阅 `tick_advanced` 更新进度（tick/总 tick）与各款成品剩余份数
- [ ] 5.2 [AI] 订阅 `sale_made`/`customer_lost`：累计成交数、流失数、实时营收，并向滚动日志追加单条记录
- [ ] 5.3 [用户] 搭建 `SimulationPanel` 白盒场景/节点（进度条/Label + 成品列表 + 滚动日志容器），挂脚本并连接

## 6. 结算阶段 UI（settlement-ui）

- [ ] 6.1 [AI] 新增 `game/scripts/ui/settlement_panel.gd`：订阅 `day_settled`，展示营收/采购/租金/浪费/净利与结算后现金，盈亏用不同颜色白盒区分
- [ ] 6.2 [AI] 展示各款售出/作废/流失明细，并明确区分"流失=机会成本不扣钱"与"浪费=沉没成本实亏"
- [ ] 6.3 [AI] "进入下一天"按钮调 `start_next_day()`；预留"流言"等后续内容占位区（仅占位、无数据）
- [ ] 6.4 [用户] 搭建 `SettlementPanel` 白盒场景/节点（复盘表 + 明细列表 + 占位区 + 按钮），挂脚本并连接

## 7. 主场景装配与阶段切换

- [ ] 7.1 [AI] 新增根 UI 控制脚本（如 `game/scripts/ui/game_hud.gd`）：订阅 `phase_changed`，按 DECISION/SIMULATION/SETTLEMENT 切换三面板可见性
- [ ] 7.2 [用户] 新建 `main_game.tscn`：根节点挂 `GameSession` 与 `GameHUD`，作为决策/模拟/结算三面板的父容器
- [ ] 7.3 [用户] 在编辑器将运行主场景切到 `main_game.tscn`（或用 F6 单独运行）；保留 `main.tscn`、`test_m1.tscn` 不动
- [ ] 7.4 [AI] 在无内容资源时于 UI 显示占位提示，避免空内容集导致的空白/报错

## 8. 手感验证（M1 关键判断点）

- [ ] 8.1 [用户] 连玩多天：验证"预测→采购→生产→售卖→止损→复盘"闭环手感，确认能感受到预测成功/失败的反馈
- [ ] 8.2 [用户] 核对复盘数据与预期一致（流失不扣钱、作废实亏、现金随盈亏累积、库存跨天结转）
- [ ] 8.3 [用户] 记录"是否想再玩一天"的主观判断到 `BACKLOG.md`，据此决定是否调设计或推进 M2

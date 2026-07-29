## 1. 配置资源脚本

- [x] 1.1 新增 `game/scripts/data/game_config.gd`：`extends Resource`、`class_name GameConfig`，`@export` 三字段 `day_duration_sec: float = 90.0`、`ticks_per_day: int = 20`、`time_scale: float = 1.0`，附 `@export_range` 与注释
- [x] 1.2 在 `game_config.gd` 提供只读取值方法（`get_day_duration_sec` / `get_ticks_per_day` / `get_time_scale`），对非法值（非正、负）就地回退默认

## 2. 配置资源实例（用户在编辑器内操作）

- [x] 2.1 在编辑器新建目录 `res://data/config/` 并创建 `game_config.tres`（以 `GameConfig` 为脚本），填入初始值；由用户按 AI 给出的分步指导完成（§3.1）

## 3. DayCycle 配置化改造

- [x] 3.1 `day_cycle.gd` 移除 `DAY_DURATION_SEC` / `TICKS_PER_DAY` / `TICK_INTERVAL` 三个 `const`，改为持有 `var _config: GameConfig`，在 `_ready()` 从固定路径 `res://data/config/game_config.tres` 加载；缺失/加载失败时 `_config = GameConfig.new()`（默认值）
- [x] 3.2 新增取值出口方法（`get_day_duration_sec` / `get_ticks_per_day` / `get_time_scale`）供内外统一读取
- [x] 3.3 `_process(delta)` 模拟分支：以 `scaled = delta * get_time_scale()` 参与营业累计与 `advance_crafting(scaled)`；tick 边界按 `day_duration_sec / ticks_per_day` 实时推导；到 `day_duration_sec` 进入结算
- [x] 3.4 `get_day_remaining` / `get_day_progress` 等只读查询改为基于 `get_day_duration_sec()`

## 4. 外部引用改造

- [x] 4.1 `game_session.gd`：`DC.TICKS_PER_DAY` → `DayCycle.get_ticks_per_day()`
- [x] 4.2 `simulation_panel.gd`：`DC.DAY_DURATION_SEC` → `DayCycle.get_day_duration_sec()`
- [x] 4.3 `main.gd`：`DayCycle.TICKS_PER_DAY` → `DayCycle.get_ticks_per_day()`
- [x] 4.4 全局搜索 `TICKS_PER_DAY` / `DAY_DURATION_SEC` / `TICK_INTERVAL` 确认无遗漏引用（额外发现并修正 `m1_harness.gd` 两处）

## 5. 规格纠偏

- [x] 5.1 archive 时将 `day-cycle` delta 并入 `openspec/specs/day-cycle/spec.md`，替换过期的「Timer 固定步长 tick」描述为真实时间时钟 + 配置化时长（由 archive 流程完成，无需手改主 spec）

## 6. 验证

- [x] 6.1 空跑一天：默认配置下一天时长、tick 数、结算触发均与改造前一致
- [x] 6.2 改 `game_config.tres` 的 `day_duration_sec`（如 30 / 180）验证一天时长即时变化，无需改代码
- [x] 6.3 设 `time_scale = 0` 验证营业与制作暂停、一天不结束；设 `2.0` 验证同步加速
- [x] 6.4 删除/重命名 `game_config.tres` 验证回退默认值不崩溃

extends Node
## 事件总线（Autoload 单例）
## 全局信号中枢，系统间解耦通信走这里。按需扩展，不预先堆砌。

# === 日周期 ===
signal day_started(day_index: int)
signal phase_changed(phase: int)        # 取值见 DayCycle.Phase
signal tick_advanced(tick_index: int)
signal day_ended(day_index: int)

# === 摆摊核心循环（M1）===
signal sale_made(recipe_id: StringName, revenue: float)   # 成交：卖出一份寿司
signal customer_lost(recipe_id: StringName)               # 流失：想要的款式无货
signal sushi_discarded(recipe_id: StringName, cost: float) # 作废：未售成品被倒掉（沉没成本）（旧信号，保留兼容）
signal day_settled(review: Dictionary)                    # 日结算完成，携带复盘数据

# === 生产链：制作队列（营业阶段）===
signal craft_started(recipe_id: StringName)               # 队首开始制作
signal craft_progress(recipe_id: StringName, ratio: float) # 当前制作项进度 0→1
signal craft_finished(recipe_id: StringName)              # 一份制作完成并落出餐台
signal craft_skipped(recipe_id: StringName)               # 制作时食材不足，跳过该项
signal crafting_paused()                                  # 出餐台满，制作暂停（冻结落台）
signal crafting_resumed()                                 # 出餐台出空位，制作恢复

# === 生产链：成品容器与作废/退料 ===
signal buffer_changed()                                   # 出餐台内容变化
signal shelf_changed()                                    # 货架内容变化
signal sushi_wasted(recipe_id: StringName, source: StringName) # 作废（沉没成本），source: buffer/shelf/settlement
signal ingredients_returned(recipe_id: StringName)        # 备货取消退料：食材已原额返还

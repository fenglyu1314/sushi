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
signal sushi_discarded(recipe_id: StringName, cost: float) # 作废：未售成品被倒掉（沉没成本）
signal day_settled(review: Dictionary)                    # 日结算完成，携带复盘数据

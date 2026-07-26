extends Node
## 事件总线（Autoload 单例）
## 全局信号中枢，系统间解耦通信走这里。按需扩展，不预先堆砌。

# === 日周期 ===
signal day_started(day_index: int)
signal phase_changed(phase: int)        # 取值见 DayCycle.Phase
signal tick_advanced(tick_index: int)
signal day_ended(day_index: int)

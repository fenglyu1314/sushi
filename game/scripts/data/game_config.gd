extends Resource
class_name GameConfig
## 全局游戏配置资源（game-config）
## 把时间相关的可调参数（一天时长 / 售卖采样密度 / 时间倍速）从代码抽出，
## 编辑器内即可调节手感，无需改动逻辑。实例固定路径 res://data/config/game_config.tres，
## 由 DayCycle 在 _ready 时加载；缺失 / 非法时回退到内置默认值。

## 一天营业的真实秒数（常速下）——核心手感参数：越大越从容。
## 实际时长 = day_duration_sec / time_scale。必须为正数，否则回退默认。
@export_range(1.0, 600.0, 1.0, "or_greater") var day_duration_sec: float = 90.0

## 一天内售卖采样的次数（把全天人流量均摊到各 tick）。越大顾客到达越平滑。
## 必须为正整数，否则回退默认。
@export_range(1, 200, 1, "or_greater") var ticks_per_day: int = 20

## 时间倍速系数：营业时钟每现实秒推进的游戏秒数。
## 0 = 暂停（营业与制作双双静止），1.0 = 常速，2.0 = 双倍速。不得为负，否则回退默认。
@export_range(0.0, 8.0, 0.1, "or_greater") var time_scale: float = 1.0

## 内置默认值（作为非法值的就地回退基准，与各字段默认保持一致）。
const _DEFAULT_DAY_DURATION_SEC: float = 90.0
const _DEFAULT_TICKS_PER_DAY: int = 20
const _DEFAULT_TIME_SCALE: float = 1.0


## 一天营业时长（真实秒）：非正回退默认。
func get_day_duration_sec() -> float:
	if day_duration_sec <= 0.0:
		return _DEFAULT_DAY_DURATION_SEC
	return day_duration_sec


## 一天售卖采样次数：非正回退默认。
func get_ticks_per_day() -> int:
	if ticks_per_day <= 0:
		return _DEFAULT_TICKS_PER_DAY
	return ticks_per_day


## 时间倍速系数：负值回退默认（0 合法，表示暂停）。
func get_time_scale() -> float:
	if time_scale < 0.0:
		return _DEFAULT_TIME_SCALE
	return time_scale

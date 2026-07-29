## Purpose

定义一份全局可配置的游戏参数数据资源，把一天时长、售卖采样密度、时间倍速等可调参数从代码中抽离，使调节游戏节奏无需修改逻辑代码，符合项目「加内容不改代码」的数据驱动约定。

## ADDED Requirements

### Requirement: 全局配置资源字段

系统 SHALL 提供一个全局配置数据资源（Godot Resource），至少包含以下可调字段：`day_duration_sec`（一天营业的真实秒数）、`ticks_per_day`（一天内售卖采样的次数）、`time_scale`（时间倍速系数）。字段命名采用术语表「天」措辞。

#### Scenario: 配置资源可被编辑器编辑
- **WHEN** 在 Godot 编辑器中打开该配置资源实例
- **THEN** `day_duration_sec`、`ticks_per_day`、`time_scale` 三个字段均以可编辑属性呈现，并带有合理默认值

### Requirement: 缺省与非法值兜底

系统 SHALL 在配置资源缺失、无法加载或字段取值非法时回退到内置默认值，保证游戏可正常运行不崩溃。默认值为 `day_duration_sec = 90.0`、`ticks_per_day = 20`、`time_scale = 1.0`。非法约束：`day_duration_sec` 必须为正数、`ticks_per_day` 必须为正整数、`time_scale` 不得为负。

#### Scenario: 配置文件缺失时用默认值
- **WHEN** 固定路径下不存在配置资源文件
- **THEN** 系统采用默认值（90 秒 / 20 次 / 1.0 倍速）继续运行，不抛出致命错误

#### Scenario: 字段取值非法时回退
- **WHEN** 加载到的配置中 `day_duration_sec <= 0` 或 `ticks_per_day <= 0`
- **THEN** 对应字段回退到其默认值，其余合法字段仍生效

### Requirement: 时间倍速语义

配置的 `time_scale` SHALL 表示营业阶段时间流逝的缩放系数：`1.0` 为常速，大于 `1.0` 为加速，`0` 表示暂停（营业时钟与制作时钟均不推进）。

#### Scenario: 倍速为 0 时暂停
- **WHEN** `time_scale` 为 `0`
- **THEN** 营业阶段的时间不推进，一天不会因时间流逝而结束

#### Scenario: 倍速为 2 时加速
- **WHEN** `time_scale` 为 `2.0`
- **THEN** 营业阶段每现实秒推进 2 秒游戏时间，一天在约一半现实时间内结束

## MODIFIED Requirements

### Requirement: 配方数据资源
系统 SHALL 以 `Resource` 定义配方（`Recipe`），至少包含 id、名称、所需食材及每份消耗量、售价、**制作时长 `craft_time`（秒）**，并记录成品占货架格数（本阶段仅记录、不施加空间约束）。

#### Scenario: 读取配方定义
- **WHEN** 加载一个配方资源
- **THEN** 系统可获取其消耗的食材种类与每份消耗量、售价、制作时长与占格数

#### Scenario: 制作按配方时长耗时
- **WHEN** 制作队列开始制作某配方一份
- **THEN** 该份的制作耗时取自该配方的 `craft_time`

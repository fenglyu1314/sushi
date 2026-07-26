### Requirement: 存档管理作为 Autoload
系统 SHALL 提供 `SaveManager` Autoload 单例，启动后可通过全局名 `SaveManager` 访问。

#### Scenario: 启动后可全局访问
- **WHEN** 工程启动且 Autoload 已注册
- **THEN** 任意脚本可通过 `SaveManager` 全局名访问

### Requirement: 保存日周期状态
`SaveManager` SHALL 提供 `save_game()` 方法，将当前日周期状态（`DayCycle.current_day`、`current_phase`、`current_tick`）序列化为 JSON 写入 `user://savegame.json`。

#### Scenario: 保存成功
- **WHEN** 调用 `save_game()`
- **THEN** `user://savegame.json` 存在，内容为含 day/phase/tick 的 JSON

### Requirement: 读取日周期状态
`SaveManager` SHALL 提供 `load_game()` 方法：从 `user://savegame.json` 读取并恢复 `DayCycle` 的日周期状态；读取成功返回 `true`，无存档或解析失败返回 `false`。

#### Scenario: 读取成功恢复状态
- **WHEN** 存在有效存档，调用 `load_game()`
- **THEN** `DayCycle` 的 day/phase/tick 被恢复为存档值，返回 `true`

#### Scenario: 无存档时读取失败
- **WHEN** 不存在存档文件，调用 `load_game()`
- **THEN** 状态不变，返回 `false`

### Requirement: 判断存档是否存在
`SaveManager` SHALL 提供 `has_save()` 方法，返回 `user://savegame.json` 是否存在。

#### Scenario: 存档存在
- **WHEN** 存档文件存在，调用 `has_save()`
- **THEN** 返回 `true`

#### Scenario: 存档不存在
- **WHEN** 存档文件不存在，调用 `has_save()`
- **THEN** 返回 `false`

### Requirement: 删除存档
`SaveManager` SHALL 提供 `delete_save()` 方法：若存档存在则删除。

#### Scenario: 删除已存在存档
- **WHEN** 存档存在，调用 `delete_save()`
- **THEN** 存档文件被删除，`has_save()` 返回 `false`

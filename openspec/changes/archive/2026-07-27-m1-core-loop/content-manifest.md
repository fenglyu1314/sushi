# M1 内容清单（占位数据）

> 本清单供**在 Godot 编辑器内创建 `.tres` 资源实例**使用（遵循 `AGENT.md` §3.1：`.tres` 不由 AI 创建）。
> 所有数值均为**占位初值**，仅用于跑通闭环、验证机制，**不代表平衡后的正式数值**（数值平衡待原型调优，GDD §5.8/§7.8）。
> 建议资源存放目录：`game/data/{ingredients,recipes,customers,locations}/`。
>
> 命令行验证脚本 `scripts/tools/m1_harness.gd` 已用**代码内联**构造同一套占位数据，无需先建 `.tres` 即可运行；此清单用于把同一套内容沉淀为可编辑的正式资源。

## 补充说明：Recipe 新增字段 `flavor_tags`

为实现 `sales`「依顾客喜好标签确定想要的寿司款式」，`Recipe` 增加了 `flavor_tags`（口味标签）字段，作为「顾客喜好标签 → 具体寿司款式」的桥接。此字段是 tasks.md §1.2 明列字段之外、为满足 `sales` spec 必需的实现补充。

---

## 1. 食材 Ingredient（`game/data/ingredients/`）

| id | display_name | base_price | unit_amount | category | 说明 |
|----|--------------|-----------:|------------:|----------|------|
| `salmon` | 三文鱼 | 8.0 | 300 | MAIN | 可做约 10 份（@30/份） |
| `tuna` | 金枪鱼 | 10.0 | 300 | MAIN | |
| `tamago` | 玉子 | 5.0 | 250 | MAIN | |
| `rice` | 米饭 | 3.0 | 1000 | SUB | 辅料，数值上限管理 |
| `nori` | 紫菜 | 2.0 | 500 | SUB | 辅料 |

## 2. 配方 Recipe（`game/data/recipes/`）

> `ingredients` 为 `RecipeIngredient` 数组（每项 = 食材引用 + 每份消耗量）。

| id | display_name | 用料（每份消耗量） | price | shelf_slots | flavor_tags |
|----|--------------|--------------------|------:|:-----------:|-------------|
| `salmon_nigiri` | 三文鱼握寿司 | salmon 30 + rice 20 | 12.0 | 1 | `fish`, `salmon`, `classic` |
| `tuna_nigiri` | 金枪鱼握寿司 | tuna 30 + rice 20 | 14.0 | 1 | `fish`, `tuna` |
| `tamago_nigiri` | 玉子握寿司 | tamago 25 + rice 20 + nori 5 | 8.0 | 1 | `sweet`, `tamago`, `veggie` |

## 3. 顾客类型 CustomerType（`game/data/customers/`）

> `preference_tags` 为「标签 → 权重」字典。

| id | display_name | preference_tags | appear_weight |
|----|--------------|-----------------|--------------:|
| `student_fish` | 爱吃鱼的学生 | `fish`:2.0, `salmon`:1.0 | 3.0 |
| `student_tuna` | 金枪鱼党学生 | `tuna`:2.0, `fish`:1.0 | 2.0 |
| `student_sweet` | 嗜甜学生 | `sweet`:2.0, `tamago`:1.0 | 1.0 |

## 4. 地点 Location（`game/data/locations/`）

> `customer_mix` 为 `CustomerWeight` 数组（每项 = 顾客类型引用 + 权重）。

| id | display_name | customer_mix（类型:权重） | foot_traffic | spending_power | rent |
|----|--------------|---------------------------|-------------:|---------------:|-----:|
| `school_street` | 学校街 | student_fish:3, student_tuna:2, student_sweet:1 | 20 | 0.9 | 30.0 |

extends Resource
class_name CustomerType
## 顾客类型数据资源（game-data-model）
## 以喜好标签（标签→权重）描述顾客偏好，并带整体出现权重。

## 唯一 id
@export var id: StringName = &""

## 显示名称
@export var display_name: String = ""

## 喜好标签集合：标签(StringName) → 权重(float)
## 顾客到达时按此权重抽取一个喜好标签，再匹配带该标签的寿司款式。
@export var preference_tags: Dictionary = {}

## 该顾客类型在客群中的整体出现权重
@export var appear_weight: float = 1.0

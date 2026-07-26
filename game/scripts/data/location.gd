extends Resource
class_name Location
## 地点数据资源（game-data-model）
## 描述一个摆摊点位的客群构成、人流量、消费力与租金。

## 唯一 id
@export var id: StringName = &""

## 显示名称（术语：地点，叙事语境可称「街道」）
@export var display_name: String = ""

## 客群构成：各顾客类型及其权重
@export var customer_mix: Array[CustomerWeight] = []

## 人流量：一个回合（一天）内到达的顾客总量
@export var foot_traffic: int = 0

## 消费力：作用于售价的营收系数（1.0 = 按原价）
@export var spending_power: float = 1.0

## 摊位租金（每回合固定成本，结算阶段扣除）
@export var rent: float = 0.0

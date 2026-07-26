extends Resource
class_name CustomerWeight
## 地点客群构成中的一项（内嵌资源）
## 强类型引用某顾客类型，并记录其在该地点的出现权重。

## 引用的顾客类型资源
@export var customer_type: CustomerType

## 在该地点客群中的权重
@export var weight: float = 1.0

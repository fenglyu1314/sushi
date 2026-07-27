extends RefCounted
class_name ContentDB
## 内容加载（content-loading）— 从约定数据目录加载 .tres 内容资源
## 扫描 res://data/{ingredients,recipes,customers,locations}/ 下全部 .tres，
## 构建运行时内容集：食材(id→Ingredient)、配方(Array[Recipe])、顾客(id→CustomerType)、地点(id→Location)。
## 符合「加内容不改代码」：编辑器内新增一个 .tres 丢进目录即生效。
## Recipe/Location 通过内嵌的 RecipeIngredient/CustomerWeight 强类型引用其它资源，加载时自动带出依赖。

const BASE_DIR := "res://data"

## 食材：id(StringName) → Ingredient
var ingredients: Dictionary = {}
## 配方列表
var recipes: Array[Recipe] = []
## 顾客类型：id(StringName) → CustomerType
var customers: Dictionary = {}
## 地点：id(StringName) → Location
var locations: Dictionary = {}


## 扫描并加载全部内容。目录缺失/为空不崩溃，返回空集并 push_warning。
func load_all() -> void:
	ingredients.clear()
	recipes.clear()
	customers.clear()
	locations.clear()

	for res in _load_dir("ingredients"):
		var ing := res as Ingredient
		if ing != null and ing.id != &"":
			ingredients[ing.id] = ing

	for res in _load_dir("recipes"):
		var r := res as Recipe
		if r != null:
			recipes.append(r)

	for res in _load_dir("customers"):
		var c := res as CustomerType
		if c != null and c.id != &"":
			customers[c.id] = c

	for res in _load_dir("locations"):
		var loc := res as Location
		if loc != null and loc.id != &"":
			locations[loc.id] = loc

	# 自检：记录各类型加载数量
	print("[ContentDB] 加载完成：食材=%d 配方=%d 顾客=%d 地点=%d"
		% [ingredients.size(), recipes.size(), customers.size(), locations.size()])
	if ingredients.is_empty() and recipes.is_empty() and locations.is_empty():
		push_warning("[ContentDB] 未加载到任何内容资源，请确认 %s 下各子目录含 .tres" % BASE_DIR)


## 扫描单个子目录，加载其中全部 .tres 资源
func _load_dir(sub: String) -> Array:
	var out: Array = []
	var path := "%s/%s" % [BASE_DIR, sub]
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("[ContentDB] 目录缺失或无法打开：%s" % path)
		return out
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var clean := fname
			# 导出后资源可能带 .remap 后缀，去除以还原原始资源路径
			if clean.ends_with(".remap"):
				clean = clean.trim_suffix(".remap")
			if clean.ends_with(".tres"):
				var res := ResourceLoader.load("%s/%s" % [path, clean])
				if res != null:
					out.append(res)
				else:
					push_warning("[ContentDB] 加载失败：%s/%s" % [path, clean])
		fname = dir.get_next()
	dir.list_dir_end()
	return out


# ===== 只读查询 =====

## 按 id 取食材；不存在返回 null
func get_ingredient(id: StringName) -> Ingredient:
	return ingredients.get(id, null)


## 按 id 取地点；不存在返回 null
func get_location(id: StringName) -> Location:
	return locations.get(id, null)


## 遍历配方（返回副本数组，避免外部改写内部列表）
func get_recipes() -> Array[Recipe]:
	var copy: Array[Recipe] = []
	copy.assign(recipes)
	return copy


## 遍历食材（返回副本数组）
func get_ingredient_list() -> Array[Ingredient]:
	var out: Array[Ingredient] = []
	for id in ingredients:
		out.append(ingredients[id])
	return out


## 取第一个地点（当指定 id 不存在时的兜底）
func get_first_location() -> Location:
	for id in locations:
		return locations[id]
	return null

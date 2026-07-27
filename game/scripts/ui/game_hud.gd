extends Control
## 根 UI 控制器（7.1）
## 订阅 phase_changed，按 DECISION/SIMULATION/SETTLEMENT 切换三面板可见性。
## 面板通过导出的 NodePath 指定；未设置时按节点名（DecisionPanel/SimulationPanel/SettlementPanel）在子树中查找。

const DC = preload("res://scripts/core/day_cycle.gd")

@export var decision_panel_path: NodePath
@export var simulation_panel_path: NodePath
@export var settlement_panel_path: NodePath

var _decision: Control
var _simulation: Control
var _settlement: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_decision = _resolve(decision_panel_path, "DecisionPanel")
	_simulation = _resolve(simulation_panel_path, "SimulationPanel")
	_settlement = _resolve(settlement_panel_path, "SettlementPanel")
	if _decision == null or _simulation == null or _settlement == null:
		push_warning("[GameHUD] 未能解析全部面板，请确认三面板为本节点子级并命名为 DecisionPanel/SimulationPanel/SettlementPanel，或设置对应 NodePath")
	EventBus.phase_changed.connect(_on_phase_changed)
	# 默认显示决策面板（首个 phase_changed 会随后校正）
	_apply_visibility(DC.Phase.DECISION)


func _resolve(path: NodePath, fallback_name: String) -> Control:
	if path != NodePath("") and has_node(path):
		return get_node(path) as Control
	return find_child(fallback_name, true, false) as Control


func _on_phase_changed(phase: int) -> void:
	_apply_visibility(phase)


func _apply_visibility(phase: int) -> void:
	if _decision != null:
		_decision.visible = (phase == DC.Phase.DECISION)
	if _simulation != null:
		_simulation.visible = (phase == DC.Phase.SIMULATION)
	if _settlement != null:
		_settlement.visible = (phase == DC.Phase.SETTLEMENT)

extends Node
## M0 验证主场景脚本
## 验证目标：能运行一个空的"一天"循环（决策→模拟→结算→下一天）
##
## 操作：
##   决策阶段按 [空格] → 进入模拟
##   结算阶段按 [Enter] → 进入下一天
##   随时按 [S] 存档 / [L] 读档

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.day_ended.connect(_on_day_ended)
	DayCycle.start_new_day()


func _on_day_started(d: int) -> void:
	print("\n=== Day %d 开始 ===" % d)
	print("  阶段：决策（按 [空格] 开始模拟）")


func _on_phase_changed(p: int) -> void:
	match p:
		DayCycle.Phase.DECISION: print("  → 决策阶段")
		DayCycle.Phase.SIMULATION: print("  → 模拟阶段（tick 推进中…）")
		DayCycle.Phase.SETTLEMENT: print("  → 结算阶段")


func _on_tick_advanced(t: int) -> void:
	print("    tick %d / %d" % [t, DayCycle.TICKS_PER_DAY])


func _on_day_ended(d: int) -> void:
	print("  Day %d 结算完成（按 [Enter] 进入下一天）" % d)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			if DayCycle.current_phase == DayCycle.Phase.DECISION:
				DayCycle.begin_simulation()
		KEY_ENTER:
			if DayCycle.current_phase == DayCycle.Phase.SETTLEMENT:
				DayCycle.start_new_day()
		KEY_S:
			SaveManager.save_game()
			print("  [存档已保存]")
		KEY_L:
			if SaveManager.load_game():
				print("  [读档成功] day=%d phase=%d tick=%d" % [
					DayCycle.current_day, DayCycle.current_phase, DayCycle.current_tick])
			else:
				print("  [无存档]")

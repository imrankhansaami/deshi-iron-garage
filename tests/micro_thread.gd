extends SceneTree
## Micro-probe 2: container as a shared MEMBER instead of a bound argument.

var results: Array = []

func _initialize() -> void:
	_run()


func _run() -> void:
	results.resize(4)
	var g: int = WorkerThreadPool.add_group_task(_worker, 4, 4, false, "micro2")
	WorkerThreadPool.wait_for_group_task_completion(g)
	print("MICRO2 after wait: results=%s" % str(results))
	quit()


func _worker(idx: int) -> void:
	results[idx] = {"ok": idx}

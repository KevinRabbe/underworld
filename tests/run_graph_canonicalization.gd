extends SceneTree

const Contracts := preload("res://tests/graph_canonicalization/test_graph_canonicalization.gd")


func _init() -> void:
	var failures: Array[String] = []
	Contracts.run(failures)
	if failures.is_empty():
		print("[GRAPH CANONICALIZATION] PASS")
		quit(0)
		return
	printerr("[GRAPH CANONICALIZATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)

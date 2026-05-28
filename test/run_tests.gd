#!/usr/bin/env godot --headless --script
extends SceneTree

var passed = 0
var failed = 0
var failures = []

func _initialize():
	print("=" * 50)
	print("  VTT Open Test Suite")
	print("=" * 50)
	run_test_file("test/test_segments.gd",   "Segment Intersection")
	run_test_file("test/test_world_coord.gd","World Coordinates")
	run_test_file("test/test_aabb.gd",       "AABB Utility")
	run_test_file("test/test_aoe_shapes.gd", "AoE Shapes")
	print("")
	print("=" * 50)
	print("  Results: ", passed, " passed, ", failed, " failed")
	print("=" * 50)
	if failed > 0:
		for f in failures:
			print("  FAILED: ", f)
	print("")
	quit(failed > 0)

func run_test_file(path: String, label: String):
	var script = load(path)
	if not script:
		push_error("Could not load ", path)
		failed += 1
		failures.append(path)
		return
	var instance = script.new()
	instance.test_runner = self
	instance.run()

func report(pass: bool, name: String):
	if pass:
		passed += 1
		print("  PASS  ", name)
	else:
		failed += 1
		failures.append(name)
		print("  FAIL  ", name)
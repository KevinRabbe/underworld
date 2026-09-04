extends RefCounted

const CaveRuntimeController := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const RuntimeComposition := preload("res://gameplay/resources/runtime/underground_resource_runtime_composition.gd")
const ContentEvidence := preload("res://gameplay/resources/runtime/underground_resource_content_evidence.gd")
const ArchetypeRealizer := preload("res://core/content/archetypes/archetype_realizer.gd")
const PackedSceneArchetypeAdapter := preload("res://core/content/archetypes/packed_scene_archetype_adapter.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")


static func run(runtime_parent: Node3D) -> Array[String]:
	var failures: Array[String] = []
	var controller = CaveRuntimeController.new()
	runtime_parent.add_child(controller)
	controller.configure("world:resource-composition", "manifest:resource-composition")

	var authority: Dictionary = ContentEvidence.build_first_iron_authority()
	for failure in ContentEvidence.verification_failures(authority):
		failures.append("runtime composition content authority: %s" % failure)
	if not failures.is_empty():
		_cleanup(null, controller)
		return failures

	var realizer = ArchetypeRealizer.new()
	var adapter_failures: Array[String] = realizer.register_adapter(PackedSceneArchetypeAdapter.new())
	for failure in adapter_failures:
		failures.append("runtime composition archetype adapter: %s" % failure)
	if not failures.is_empty():
		_cleanup(null, controller)
		return failures

	var composition = RuntimeComposition.new()
	var configure_failures: Array[String] = composition.configure(
		controller,
		runtime_parent,
		runtime_parent,
		authority,
		WorldDeltaStore.new(),
		realizer
	)
	for failure in configure_failures:
		failures.append("runtime composition configure: %s" % failure)
	if not configure_failures.is_empty():
		_cleanup(composition, controller)
		return failures

	_expect_true(failures, "resource runtime composition reports configured", composition.configured())
	_expect_true(failures, "resource runtime composition starts inactive", not composition.activation_enabled())
	_expect_true(failures, "configured residency service exists", composition.residency() != null)
	_expect_true(failures, "configured action service exists", composition.action_service() != null)
	_expect_true(failures, "configured realization service exists", composition.realization() != null)
	_expect_true(failures, "configured harvest sink exists", composition.harvest_sink() != null)
	_expect_true(failures, "realization is inert after configuration", not composition.realization().activation_enabled())
	_expect_true(failures, "harvest ingress is inert after configuration", not composition.harvest_sink().activation_enabled())
	_expect_equal(failures, "no resident cave cells means zero live resource Nodes", composition.realization().live_placement_count(), 0)

	var enable_failures: Array[String] = composition.set_activation_enabled(true)
	for failure in enable_failures:
		failures.append("runtime composition enable: %s" % failure)
	_expect_true(failures, "resource runtime composition becomes active", composition.activation_enabled())
	_expect_true(failures, "realization activates with composition", composition.realization().activation_enabled())
	_expect_true(failures, "harvest ingress activates with composition", composition.harvest_sink().activation_enabled())
	_expect_equal(failures, "activation does not fabricate historical resource Nodes", composition.realization().live_placement_count(), 0)

	var disable_failures: Array[String] = composition.set_activation_enabled(false)
	for failure in disable_failures:
		failures.append("runtime composition disable: %s" % failure)
	_expect_true(failures, "resource runtime composition becomes inactive", not composition.activation_enabled())
	_expect_true(failures, "disable closes harvest ingress", not composition.harvest_sink().activation_enabled())
	_expect_true(failures, "disable retires realization authority", not composition.realization().activation_enabled())
	_expect_equal(failures, "disable leaves zero live resource Nodes", composition.realization().live_placement_count(), 0)

	# Idempotent toggles are safe for an external domain owner that may project the
	# same committed state more than once while transitions settle.
	_expect_true(failures, "repeated disable is idempotent", composition.set_activation_enabled(false).is_empty())
	_expect_true(failures, "re-enable after clean disable succeeds", composition.set_activation_enabled(true).is_empty())
	_expect_true(failures, "re-enabled ingress is active", composition.harvest_sink().activation_enabled())

	composition.dispose()
	_expect_true(failures, "dispose clears configured state", not composition.configured())
	_expect_true(failures, "dispose clears activation state", not composition.activation_enabled())
	_expect_true(failures, "dispose releases residency reference", composition.residency() == null)
	_expect_true(failures, "dispose releases action reference", composition.action_service() == null)
	_expect_true(failures, "dispose releases realization reference", composition.realization() == null)
	_expect_true(failures, "dispose releases harvest sink reference", composition.harvest_sink() == null)

	_cleanup(null, controller)
	return failures


static func _cleanup(composition, controller) -> void:
	if composition != null:
		composition.dispose()
	if controller != null and is_instance_valid(controller):
		var parent = controller.get_parent()
		if parent != null:
			parent.remove_child(controller)
		controller.free()


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, expected, actual])

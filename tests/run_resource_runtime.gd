extends SceneTree

const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const RuntimeService := preload("res://gameplay/resources/runtime/underground_resource_runtime_service.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const ArchetypeRealizer := preload("res://core/content/archetypes/archetype_realizer.gd")
const PackedSceneArchetypeAdapter := preload("res://core/content/archetypes/packed_scene_archetype_adapter.gd")
const RuntimeTests := preload("res://tests/resources/test_underground_resource_runtime.gd")
const REQUIRED_RESOURCE_RUNTIME_DEPENDENCY_PATHS: Array[String] = [
	"worldgen/identity/stable_address.gd",
	"worldgen/identity/stable_id.gd",
	"content/placement/underground_placement_record.gd",
	"core/content/registry/content_registry.gd",
	"core/content/registry/content_definition.gd",
	"core/content/references/content_reference.gd",
	"core/content/identity/content_id.gd",
	"core/content/archetypes/archetype_realizer.gd",
	"core/content/archetypes/archetype_definition.gd",
	"core/content/archetypes/archetype_composition.gd",
	"core/content/archetypes/archetype_realization_adapter.gd",
	"core/content/archetypes/packed_scene_archetype_adapter.gd",
	"core/content/archetypes/archetype_family_validator.gd",
	"core/content/schema/category_schema_registry.gd",
	"core/content/schema/capability_schema_registry.gd",
	"core/content/schema/category_schema.gd",
	"core/content/schema/capability_schema.gd",
	"core/content/schema/schema_id.gd",
	"core/content/validation/content_validation_pipeline.gd",
	"core/content/validation/content_validation_evidence.gd",
	"core/content/validation/content_family_validator.gd",
	"core/content/validation/content_reference_cycle_policy.gd",
	"core/content/validation/finite_number.gd",
	"gameplay/resources/runtime/**",
	"gameplay/resources/definitions/resource_definition.gd",
	"gameplay/resources/definitions/resource_yield_rule.gd",
	"gameplay/resources/definitions/authored_harvestable_resource_definition.gd",
	"gameplay/resources/state/resource_depletion_state.gd",
	"worldgen/persistence/world_delta_store.gd",
	"content/resources/**",
	"content/items/resources/iron_chunk_definition.tres",
	"content/items/resources/stone_definition.tres",
	"content/items/tools/stone_pickaxe_definition.tres",
	"presentation/world/resources/**",
	"gameplay/items/definitions/item_definition.gd",
	"gameplay/items/equipment/equipment_hotbar_state.gd",
	"gameplay/items/equipment/equipped_item_resolver.gd",
	"gameplay/items/equipment/equipment_slot_rule.gd",
	"gameplay/items/equipment/equipment_service.gd",
	"gameplay/items/weapons/definitions/weapon_definition.gd",
	"gameplay/items/weapons/definitions/weapon_attack_set_definition.gd",
	"gameplay/items/weapons/runtime/weapon_attack_resolver.gd",
	"gameplay/combat/attacks/player_attack_definition.gd",
	"gameplay/items/inventory/item_container_state.gd",
	"gameplay/items/inventory/inventory_transaction_plan.gd",
	"gameplay/items/inventory/inventory_transaction_service.gd",
	"gameplay/items/inventory/inventory_transaction_checkpoint.gd",
	"gameplay/items/inventory/inventory_state_codec.gd",
	"gameplay/items/inventory/item_stack_state.gd",
	"gameplay/items/inventory/item_instance_state.gd",
	"tests/resources/test_underground_resource_runtime.gd",
	"tests/run_resource_runtime.gd",
	"tests/run_numeric_validation.gd",
	"tests/run_persistence_state.gd",
	"tests/run_content.gd",
	"tests/run_inventory.gd",
	".github/workflows/resource-runtime-validation.yml",
]
const DIRECT_EMBEDDED_RUNNER_PATHS: Array[String] = [
	"tests/run_numeric_validation.gd",
	"tests/run_persistence_state.gd",
	"tests/run_content.gd",
	"tests/run_inventory.gd",
]
const FORBIDDEN_BROAD_RESOURCE_RUNTIME_TRIGGERS: Array[String] = [
	"core/**",
	"core/content/**",
	"gameplay/**",
	"gameplay/items/**",
	"**",
	"**/*",
]


class CommitFailingInventory extends ItemContainerState:
	var fail_add_stack: bool = false

	func add_stack(definition, quantity: int, stack_state: Dictionary = {}) -> Dictionary:
		if fail_add_stack:
			return {
				"success": false,
				"diagnostics": ["injected resource-runtime commit-phase add failure"],
			}
		return super.add_stack(definition, quantity, stack_state)


func _init() -> void:
	var failures: Array[String] = RuntimeTests.run()
	_test_workflow_dependency_triggers(failures)
	_test_workflow_trigger_precision_policy(failures)
	_test_pull_request_path_parser_false_positives(failures)
	_test_push_main_trigger_policy(failures)
	_test_compatibility_only_realization_preserves_state(failures)
	_test_commit_phase_failure_restores_world_delta(failures)
	if failures.is_empty():
		print("[RESOURCE RUNTIME VALIDATION] PASS")
		print("  iron content / archetype realization / semantic pickaxe eligibility / atomic inventory yield / persistent depletion / idempotence / strict restore compatibility / commit-phase rollback / precise workflow dependency triggers passed")
		quit(0)
		return

	printerr("[RESOURCE RUNTIME VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)


func _test_workflow_dependency_triggers(failures: Array[String]) -> void:
	const WORKFLOW_PATH := "res://.github/workflows/resource-runtime-validation.yml"
	if not FileAccess.file_exists(WORKFLOW_PATH):
		failures.append("Resource Runtime workflow file is missing")
		return
	var workflow_file := FileAccess.open(WORKFLOW_PATH, FileAccess.READ)
	if workflow_file == null:
		failures.append("Resource Runtime workflow could not be opened for dependency-trigger validation")
		return
	var workflow_text: String = workflow_file.get_as_text()
	var parser_failures: Array[String] = []
	var pull_request_paths: Array[String] = _pull_request_path_filters(
		workflow_text,
		parser_failures
	)
	for parser_failure in parser_failures:
		failures.append(parser_failure)
	for policy_failure in _resource_runtime_trigger_policy_failures(
		pull_request_paths,
		REQUIRED_RESOURCE_RUNTIME_DEPENDENCY_PATHS
	):
		failures.append(policy_failure)
	for push_failure in _push_main_trigger_failures(workflow_text):
		failures.append(push_failure)


func _resource_runtime_trigger_policy_failures(
	pull_request_paths: Array[String],
	required_paths: Array[String]
) -> Array[String]:
	var result: Array[String] = []
	for forbidden_path in FORBIDDEN_BROAD_RESOURCE_RUNTIME_TRIGGERS:
		if pull_request_paths.has(forbidden_path):
			result.append(
				"Resource Runtime dependency trigger must remain precise; forbidden broad trigger is not allowed: %s" % forbidden_path
			)
	for dependency_path in required_paths:
		if not pull_request_paths.has(dependency_path):
			result.append(
				"Resource Runtime pull_request.paths is missing direct runtime/fixture dependency trigger: %s" % dependency_path
			)
	return result


func _test_workflow_trigger_precision_policy(failures: Array[String]) -> void:
	var representative_required: Array[String] = [
		"core/content/validation/content_validation_pipeline.gd",
		"core/content/archetypes/archetype_definition.gd",
		"gameplay/resources/runtime/**",
		"content/resources/**",
		"presentation/world/resources/**",
		"tests/run_resource_runtime.gd",
	]
	var precise_yaml := "on:\n  pull_request:\n    paths:\n      - 'core/content/validation/content_validation_pipeline.gd'\n      - 'core/content/archetypes/archetype_definition.gd'\n      - 'gameplay/resources/runtime/**'\n      - 'content/resources/**'\n      - 'presentation/world/resources/**'\n      - 'tests/run_resource_runtime.gd'\n"
	var precise_parser_failures: Array[String] = []
	var precise_paths: Array[String] = _pull_request_path_filters(precise_yaml, precise_parser_failures)
	if not precise_parser_failures.is_empty():
		failures.append("precise Resource Runtime trigger fixture failed parsing: %s" % [precise_parser_failures])
	else:
		var precise_policy_failures: Array[String] = _resource_runtime_trigger_policy_failures(
			precise_paths,
			representative_required
		)
		if not precise_policy_failures.is_empty():
			failures.append("precise Resource Runtime trigger fixture was rejected: %s" % [precise_policy_failures])

	var missing_semantic_paths: Array[String] = precise_paths.duplicate()
	missing_semantic_paths.erase("core/content/validation/content_validation_pipeline.gd")
	if _resource_runtime_trigger_policy_failures(
		missing_semantic_paths,
		representative_required
	).is_empty():
		failures.append("Resource Runtime trigger policy did not detect removed semantic dependency")

	var missing_control_paths: Array[String] = precise_paths.duplicate()
	missing_control_paths.erase("tests/run_resource_runtime.gd")
	if _resource_runtime_trigger_policy_failures(
		missing_control_paths,
		representative_required
	).is_empty():
		failures.append("Resource Runtime trigger policy did not detect removed control path")

	for embedded_runner_path in DIRECT_EMBEDDED_RUNNER_PATHS:
		var embedded_paths: Array[String] = DIRECT_EMBEDDED_RUNNER_PATHS.duplicate()
		embedded_paths.erase(embedded_runner_path)
		if _resource_runtime_trigger_policy_failures(
			embedded_paths,
			DIRECT_EMBEDDED_RUNNER_PATHS
		).is_empty():
			failures.append(
				"Resource Runtime trigger policy did not detect removed embedded runner: %s" % embedded_runner_path
			)

	for forbidden_path in FORBIDDEN_BROAD_RESOURCE_RUNTIME_TRIGGERS:
		var broad_paths: Array[String] = precise_paths.duplicate()
		broad_paths.append(forbidden_path)
		var broad_failures: Array[String] = _resource_runtime_trigger_policy_failures(
			broad_paths,
			representative_required
		)
		if broad_failures.is_empty():
			failures.append(
				"Resource Runtime precision policy accepted forbidden broad trigger: %s" % forbidden_path
			)


func _test_pull_request_path_parser_false_positives(failures: Array[String]) -> void:
	const WORLD_DELTA_PATH := "worldgen/persistence/world_delta_store.gd"
	const STABLE_ID_PATH := "worldgen/identity/stable_id.gd"
	const CONTROL_PATH := "tests/run_resource_runtime.gd"

	# A dependency that appears only as a comment and under a later sibling trigger
	# must never be reported as a pull_request path.
	var negative_yaml := "on:\n  pull_request:\n    paths:\n      - 'tests/run_resource_runtime.gd'\n      # 'worldgen/persistence/world_delta_store.gd'\n  push:\n    paths:\n      - 'worldgen/persistence/world_delta_store.gd'\n"
	var negative_failures: Array[String] = []
	var negative_paths: Array[String] = _pull_request_path_filters(negative_yaml, negative_failures)
	for parser_failure in negative_failures:
		failures.append("synthetic negative pull_request.paths parser fixture failed: %s" % parser_failure)
	if not negative_paths.has(CONTROL_PATH):
		failures.append("synthetic negative parser fixture did not retain the real pull_request path")
	if negative_paths.has(WORLD_DELTA_PATH):
		failures.append("pull_request.paths parser leaked dependency text from a comment or sibling push trigger")

	# The same dependency must be returned when it is genuinely inside the exact
	# pull_request.paths sequence.
	var positive_yaml := "on:\n  pull_request:\n    paths:\n      - 'worldgen/persistence/world_delta_store.gd'\n  push:\n    branches:\n      - main\n"
	var positive_failures: Array[String] = []
	var positive_paths: Array[String] = _pull_request_path_filters(positive_yaml, positive_failures)
	for parser_failure in positive_failures:
		failures.append("synthetic positive pull_request.paths parser fixture failed: %s" % parser_failure)
	if not positive_paths.has(WORLD_DELTA_PATH):
		failures.append("pull_request.paths parser failed to include dependency under exact pull_request.paths")

	# A sibling key inside pull_request ends the paths sequence. A later list entry
	# under that sibling must not leak into the extracted path set.
	var sibling_yaml := "on:\n  pull_request:\n    paths:\n      - 'tests/run_resource_runtime.gd'\n    types:\n      - 'worldgen/identity/stable_id.gd'\n  push:\n    branches:\n      - main\n"
	var sibling_failures: Array[String] = []
	var sibling_paths: Array[String] = _pull_request_path_filters(sibling_yaml, sibling_failures)
	for parser_failure in sibling_failures:
		failures.append("synthetic sibling-termination parser fixture failed: %s" % parser_failure)
	if not sibling_paths.has(CONTROL_PATH):
		failures.append("synthetic sibling parser fixture did not retain the pre-sibling pull_request path")
	if sibling_paths.has(STABLE_ID_PATH):
		failures.append("pull_request.paths parser leaked an entry from a later sibling mapping")

	# Negative GitHub path filters are ordered and can negate an earlier required
	# positive dependency. This lane deliberately supports positive-only filters so
	# the self-audit does not need to reimplement GitHub minimatch semantics.
	var negated_yaml := "on:\n  pull_request:\n    paths:\n      - 'worldgen/persistence/world_delta_store.gd'\n      - '!worldgen/persistence/world_delta_store.gd'\n"
	var negated_failures: Array[String] = []
	var negated_paths: Array[String] = _pull_request_path_filters(negated_yaml, negated_failures)
	if negated_failures.is_empty():
		failures.append("pull_request.paths parser accepted a negative path filter that can negate required coverage")
	if negated_paths.has("!worldgen/persistence/world_delta_store.gd"):
		failures.append("pull_request.paths parser published a forbidden negative path filter")


func _pull_request_path_filters(
	workflow_text: String,
	failures: Array[String]
) -> Array[String]:
	var result: Array[String] = []
	var found_pull_request: bool = false
	var found_paths: bool = false
	var in_pull_request: bool = false
	var in_paths: bool = false

	for raw_line in workflow_text.split("\n"):
		var line: String = str(raw_line).replace("\r", "")
		if line == "  pull_request:":
			found_pull_request = true
			in_pull_request = true
			in_paths = false
			continue
		if not in_pull_request:
			continue

		# Any new two-space key ends the pull_request mapping.
		if line.begins_with("  ") and not line.begins_with("    "):
			break

		if not in_paths:
			if line == "    paths:":
				found_paths = true
				in_paths = true
			continue

		# Any new four-space key ends the paths sequence.
		if line.begins_with("    ") and not line.begins_with("      "):
			break
		if line.begins_with("      - "):
			var encoded_value: String = line.substr(8)
			if encoded_value.length() < 2:
				failures.append("Resource Runtime pull_request.paths contains an empty list entry")
				continue
			var quote: String = encoded_value.substr(0, 1)
			if (quote != "'" and quote != "\"") or not encoded_value.ends_with(quote):
				failures.append(
					"Resource Runtime pull_request.paths entry must be a quoted scalar: %s" % encoded_value
				)
				continue
			var path_value: String = encoded_value.substr(1, encoded_value.length() - 2)
			if path_value.is_empty() or path_value != path_value.strip_edges():
				failures.append("Resource Runtime pull_request.paths contains an invalid path scalar")
				continue
			if path_value.begins_with("!"):
				failures.append(
					"Resource Runtime pull_request.paths negative filters are not allowed: %s" % path_value
				)
				continue
			if result.has(path_value):
				failures.append(
					"Resource Runtime pull_request.paths contains duplicate entry: %s" % path_value
				)
				continue
			result.append(path_value)
			continue

		var trimmed: String = line.strip_edges()
		if not trimmed.is_empty() and not trimmed.begins_with("#"):
			failures.append(
				"Resource Runtime pull_request.paths contains unexpected non-list content: %s" % trimmed
			)

	if not found_pull_request:
		failures.append("Resource Runtime workflow is missing on.pull_request")
	elif not found_paths:
		failures.append("Resource Runtime workflow is missing on.pull_request.paths")
	return result


func _test_push_main_trigger_policy(failures: Array[String]) -> void:
	var valid_yaml := "on:\n  pull_request:\n    paths:\n      - 'main'\n  push:\n    branches:\n      - main\n      - 'gameplay/resource-runtime-*'\n"
	var valid_failures: Array[String] = _push_main_trigger_failures(valid_yaml)
	if not valid_failures.is_empty():
		failures.append("valid Resource Runtime push trigger fixture was rejected: %s" % [valid_failures])

	var missing_main_yaml := "on:\n  push:\n    branches:\n      - 'release/*'\n"
	if _push_main_trigger_failures(missing_main_yaml).is_empty():
		failures.append("Resource Runtime push trigger policy accepted branches without main")

	var worker_only_yaml := "on:\n  push:\n    branches:\n      - 'gameplay/resource-runtime-*'\n"
	if _push_main_trigger_failures(worker_only_yaml).is_empty():
		failures.append("Resource Runtime push trigger policy accepted worker-only branches")

	var filtered_main_yaml := "on:\n  push:\n    branches:\n      - main\n    paths:\n      - 'tests/**'\n"
	if _push_main_trigger_failures(filtered_main_yaml).is_empty():
		failures.append("Resource Runtime push trigger policy accepted path-filtered main dispatch")

	var ignored_main_yaml := "on:\n  push:\n    branches:\n      - main\n    paths-ignore:\n      - 'docs/**'\n"
	if _push_main_trigger_failures(ignored_main_yaml).is_empty():
		failures.append("Resource Runtime push trigger policy accepted paths-ignore on main dispatch")

	var sibling_alias_yaml := "on:\n  pull_request:\n    paths:\n      - 'main'\n  push:\n    branches:\n      - 'gameplay/resource-runtime-*'\n"
	if _push_main_trigger_failures(sibling_alias_yaml).is_empty():
		failures.append("Resource Runtime push trigger policy treated sibling pull_request.paths as main push evidence")


func _push_main_trigger_failures(workflow_text: String) -> Array[String]:
	var result: Array[String] = []
	var found_push: bool = false
	var found_branches: bool = false
	var in_push: bool = false
	var in_branches: bool = false
	var branches: Array[String] = []

	for raw_line in workflow_text.split("\n"):
		var line: String = str(raw_line).replace("\r", "")
		if line == "  push:":
			found_push = true
			in_push = true
			in_branches = false
			continue
		if not in_push:
			continue

		# Any new two-space key ends the push mapping.
		if line.begins_with("  ") and not line.begins_with("    "):
			break

		if line == "    paths:" or line == "    paths-ignore:":
			result.append(
				"Resource Runtime push:main quarantine proof must remain unconditional by path; %s is not allowed" % line.strip_edges().trim_suffix(":")
			)
			in_branches = false
			continue

		if line == "    branches:":
			found_branches = true
			in_branches = true
			continue

		# Any sibling mapping under push ends the branches sequence.
		if line.begins_with("    ") and not line.begins_with("      "):
			in_branches = false
			continue

		if in_branches and line.begins_with("      - "):
			var encoded_value: String = line.substr(8).strip_edges()
			if encoded_value.is_empty():
				result.append("Resource Runtime push.branches contains an empty list entry")
				continue
			var branch_value: String = encoded_value
			var quote: String = encoded_value.substr(0, 1)
			if quote == "'" or quote == "\"":
				if encoded_value.length() < 2 or not encoded_value.ends_with(quote):
					result.append("Resource Runtime push.branches contains an invalid quoted scalar: %s" % encoded_value)
					continue
				branch_value = encoded_value.substr(1, encoded_value.length() - 2)
			if branch_value.is_empty() or branch_value != branch_value.strip_edges():
				result.append("Resource Runtime push.branches contains an invalid branch scalar")
				continue
			if branches.has(branch_value):
				result.append("Resource Runtime push.branches contains duplicate entry: %s" % branch_value)
				continue
			branches.append(branch_value)

	if not found_push:
		result.append("Resource Runtime workflow is missing on.push")
	elif not found_branches:
		result.append("Resource Runtime workflow is missing on.push.branches")
	elif not branches.has("main"):
		result.append("Resource Runtime workflow push.branches must contain exact main")
	return result


func _test_compatibility_only_realization_preserves_state(failures: Array[String]) -> void:
	var fixture: Dictionary = RuntimeTests._content_fixture(failures)
	if fixture.is_empty():
		return
	var definition = fixture["resource"]
	var archetype = fixture["archetype"]
	var placement = RuntimeTests._placement()
	var registry_before: Array = fixture["registry"].canonical_manifest()
	var resource_before: Dictionary = definition.canonical_descriptor()
	var placement_before: Dictionary = placement.canonical_data()

	var realizer = ArchetypeRealizer.new()
	var adapter_failures: Array[String] = realizer.register_adapter(PackedSceneArchetypeAdapter.new())
	if not adapter_failures.is_empty():
		failures.append("compatibility-only immutability fixture rejected packed.scene adapter: %s" % [adapter_failures])
		return
	var compatibility_only_validation: Dictionary = {
		"success": true,
		"diagnostics": [],
		"validated_definition_ids": [archetype.content_id],
	}
	var rejected: Dictionary = RuntimeService.new().realize_placement(
		placement,
		fixture["registry"],
		compatibility_only_validation,
		realizer
	)
	if bool(rejected.get("success", true)):
		failures.append("compatibility-only state immutability fixture was accepted")
	if rejected.get("instance", null) != null:
		failures.append("compatibility-only state immutability fixture realized an instance")
	var found_evidence_diagnostic: bool = false
	for diagnostic in rejected.get("diagnostics", []):
		if str(diagnostic).contains("CONTENT-006 validation evidence: expected CONTENT-006 snapshot-bound validation evidence"):
			found_evidence_diagnostic = true
			break
	if not found_evidence_diagnostic:
		failures.append("compatibility-only state immutability fixture missed CONTENT-006 evidence diagnostic")
	if fixture["registry"].canonical_manifest() != registry_before:
		failures.append("compatibility-only rejection changed content registry state")
	if definition.canonical_descriptor() != resource_before:
		failures.append("compatibility-only rejection changed resource definition state")
	if placement.canonical_data() != placement_before:
		failures.append("compatibility-only rejection changed placement state")


func _test_commit_phase_failure_restores_world_delta(failures: Array[String]) -> void:
	var fixture: Dictionary = RuntimeTests._content_fixture(failures)
	if fixture.is_empty():
		return
	var equipment_fixture: Dictionary = RuntimeTests._pickaxe_equipment(fixture["pickaxe"], failures)
	if equipment_fixture.is_empty():
		return
	var placement = RuntimeTests._placement()

	# Fresh placement: preflight succeeds, the runtime temporarily writes depletion,
	# the real container add fails during commit, and rollback must restore true
	# object_state absence rather than materializing an empty dictionary entry.
	var fresh_inventory = CommitFailingInventory.new()
	fresh_inventory.configure(2)
	fresh_inventory.fail_add_stack = true
	var fresh_store = WorldDeltaStore.new()
	var fresh_before_inventory: String = fresh_inventory.canonical_json()
	var fresh_before_store: Dictionary = fresh_store.snapshot()
	var fresh_result: Dictionary = RuntimeService.new().mine(
		placement,
		fixture["registry"],
		equipment_fixture["equipment"],
		fresh_inventory,
		fresh_store,
		"commit-failure-fresh"
	)
	if bool(fresh_result.get("success", true)):
		failures.append("fresh commit-phase inventory failure was accepted")
	if fresh_inventory.canonical_json() != fresh_before_inventory:
		failures.append("fresh commit-phase failure changed canonical inventory state")
	if fresh_store.snapshot() != fresh_before_store:
		failures.append("fresh commit-phase failure changed complete WorldDeltaStore snapshot")
	var fresh_object_state = fresh_store.snapshot().get("object_state", {})
	if fresh_object_state is Dictionary and fresh_object_state.has(placement.placement_stable_id):
		failures.append("fresh commit-phase rollback materialized an object_state entry that was absent before mining")

	# Existing depletion: rollback must reproduce the exact prior non-empty envelope,
	# not merely remove or replace the current placement entry.
	var existing_inventory = CommitFailingInventory.new()
	existing_inventory.configure(2)
	var existing_store = WorldDeltaStore.new()
	var service = RuntimeService.new()
	var setup: Dictionary = service.mine(
		placement,
		fixture["registry"],
		equipment_fixture["equipment"],
		existing_inventory,
		existing_store,
		"commit-failure-existing-setup"
	)
	if not bool(setup.get("success", false)):
		failures.append("existing commit-phase rollback fixture setup failed: %s" % [setup.get("diagnostics", [])])
		return
	existing_inventory.fail_add_stack = true
	var existing_before_inventory: String = existing_inventory.canonical_json()
	var existing_before_store: Dictionary = existing_store.snapshot()
	var existing_before_envelope: Dictionary = existing_store.get_object_state(placement.placement_stable_id)
	var existing_result: Dictionary = service.mine(
		placement,
		fixture["registry"],
		equipment_fixture["equipment"],
		existing_inventory,
		existing_store,
		"commit-failure-existing"
	)
	if bool(existing_result.get("success", true)):
		failures.append("existing-state commit-phase inventory failure was accepted")
	if existing_inventory.canonical_json() != existing_before_inventory:
		failures.append("existing-state commit-phase failure changed canonical inventory state")
	if existing_store.snapshot() != existing_before_store:
		failures.append("existing-state commit-phase failure changed complete WorldDeltaStore snapshot")
	if existing_store.get_object_state(placement.placement_stable_id) != existing_before_envelope:
		failures.append("existing-state commit-phase rollback did not restore the exact prior depletion envelope")

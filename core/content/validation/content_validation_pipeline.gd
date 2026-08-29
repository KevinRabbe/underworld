extends RefCounted

const ContentId := preload("res://core/content/identity/content_id.gd")
const SchemaId := preload("res://core/content/schema/schema_id.gd")
const ContentDefinition := preload("res://core/content/registry/content_definition.gd")
const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const ContentReference := preload("res://core/content/references/content_reference.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentFamilyValidator := preload("res://core/content/validation/content_family_validator.gd")
const ReferenceCyclePolicy := preload("res://core/content/validation/content_reference_cycle_policy.gd")


func validate_all(
	definitions: Array,
	category_registry,
	capability_registry,
	family_validators: Array = [],
	cycle_policy = null
) -> Dictionary:
	return _validate(
		definitions,
		category_registry,
		capability_registry,
		family_validators,
		cycle_policy,
		[],
		""
	)


func validate_family(
	definitions: Array,
	definition_family: String,
	category_registry,
	capability_registry,
	family_validators: Array = [],
	cycle_policy = null
) -> Dictionary:
	return _validate(
		definitions,
		category_registry,
		capability_registry,
		family_validators,
		cycle_policy,
		[],
		definition_family
	)


func validate_ids(
	definitions: Array,
	target_ids: Array,
	category_registry,
	capability_registry,
	family_validators: Array = [],
	cycle_policy = null
) -> Dictionary:
	return _validate(
		definitions,
		category_registry,
		capability_registry,
		family_validators,
		cycle_policy,
		target_ids,
		""
	)


func _validate(
	definitions: Array,
	category_registry,
	capability_registry,
	family_validators: Array,
	cycle_policy,
	raw_target_ids: Array,
	target_family: String
) -> Dictionary:
	var diagnostics: Array = []
	var id_targeting_requested: bool = not raw_target_ids.is_empty()
	var target_ids: Dictionary = {}
	for raw_target_id in raw_target_ids:
		var target_id: String = str(raw_target_id)
		var target_failures: Array[String] = ContentId.validate(target_id)
		if not target_failures.is_empty():
			for failure in target_failures:
				_add_diagnostic(
					diagnostics,
					"target_invalid",
					target_id,
					"request.target_ids",
					str(failure)
				)
			continue
		target_ids[target_id] = true

	if not target_family.is_empty():
		for failure in ContentId.validate_family(target_family):
			_add_diagnostic(
				diagnostics,
				"target_family_invalid",
				target_family,
				"request.definition_family",
				str(failure)
			)

	var category_ready: bool = (
		category_registry != null and category_registry is CategorySchemaRegistry
	)
	if not category_ready:
		_add_diagnostic(
			diagnostics,
			"category_registry_invalid",
			"<validation>",
			"configuration.category_registry",
			"expected CategorySchemaRegistry"
		)
	elif not category_registry.is_valid():
		for failure in category_registry.diagnostics():
			_add_diagnostic(
				diagnostics,
				"category_registry_invalid",
				"<validation>",
				"configuration.category_registry",
				str(failure)
			)

	var capability_ready: bool = (
		capability_registry != null and capability_registry is CapabilitySchemaRegistry
	)
	if not capability_ready:
		_add_diagnostic(
			diagnostics,
			"capability_registry_invalid",
			"<validation>",
			"configuration.capability_registry",
			"expected CapabilitySchemaRegistry"
		)
	elif not capability_registry.is_valid():
		for failure in capability_registry.diagnostics():
			_add_diagnostic(
				diagnostics,
				"capability_registry_invalid",
				"<validation>",
				"configuration.capability_registry",
				str(failure)
			)

	var validators: Array = _prepare_family_validators(family_validators, diagnostics)
	var effective_cycle_policy = _prepare_cycle_policy(cycle_policy, diagnostics)

	# Reuse the accepted ContentRegistry as the authoritative typed-resolution
	# index. Validation below never owns a parallel content lookup registry.
	var content_registry = ContentRegistry.new()
	content_registry.index_definitions(definitions)

	var id_counts: Dictionary = {}
	var available_ids: Dictionary = {}
	for candidate in definitions:
		if candidate == null or not candidate is ContentDefinition:
			continue
		var candidate_id: String = str(candidate.content_id)
		if ContentId.is_valid(candidate_id):
			id_counts[candidate_id] = int(id_counts.get(candidate_id, 0)) + 1
			available_ids[candidate_id] = true

	for target_id in target_ids.keys():
		if not available_ids.has(target_id):
			_add_diagnostic(
				diagnostics,
				"target_missing",
				str(target_id),
				"request.target_ids",
				"target definition is not present in validation input"
			)

	var selected_ids: Dictionary = {}
	var reference_edges: Array = []
	for candidate in definitions:
		if candidate == null or not candidate is ContentDefinition:
			if not id_targeting_requested and target_family.is_empty():
				_add_diagnostic(
					diagnostics,
					"definition_type_invalid",
					"<incompatible-definition>",
					"definition",
					"expected ContentDefinition Resource"
				)
			continue

		var selected: bool = _is_selected_definition(
			candidate,
			target_ids,
			target_family,
			id_targeting_requested
		)
		var candidate_id: String = str(candidate.content_id)
		var definition_failures: Array[String] = candidate.validate_definition()
		var base_valid: bool = definition_failures.is_empty()
		var unique_valid_id: bool = (
			ContentId.is_valid(candidate_id)
			and int(id_counts.get(candidate_id, 0)) == 1
		)

		if selected:
			if ContentId.is_valid(candidate_id):
				selected_ids[candidate_id] = true
			for failure in definition_failures:
				_add_diagnostic(
					diagnostics,
					"definition_invalid",
					_candidate_label(candidate),
					"definition",
					str(failure)
				)
			if ContentId.is_valid(candidate_id) and int(id_counts.get(candidate_id, 0)) > 1:
				_add_diagnostic(
					diagnostics,
					"duplicate_content_id",
					candidate_id,
					"definition.content_id",
					"duplicate semantic content id: %s" % candidate_id
				)

			if base_valid:
				_validate_schema_declarations(
					candidate,
					category_registry,
					category_ready,
					capability_registry,
					capability_ready,
					diagnostics
				)
				_run_family_validators(candidate, validators, {
					"content_registry": content_registry,
					"category_registry": category_registry,
					"capability_registry": capability_registry,
				}, diagnostics)

		if base_valid and unique_valid_id:
			_collect_reference_validation(
				candidate,
				content_registry,
				selected,
				reference_edges,
				diagnostics
			)

	_validate_reference_cycles(
		reference_edges,
		selected_ids,
		effective_cycle_policy,
		diagnostics
	)

	var canonical_diagnostics: Array = _canonicalize_diagnostics(diagnostics)
	var validated_ids: Array[String] = []
	for key in selected_ids.keys():
		validated_ids.append(str(key))
	validated_ids.sort()
	return {
		"success": canonical_diagnostics.is_empty(),
		"validated_definition_ids": validated_ids,
		"diagnostic_count": canonical_diagnostics.size(),
		"diagnostics": canonical_diagnostics,
	}


func _validate_schema_declarations(
	definition,
	category_registry,
	category_ready: bool,
	capability_registry,
	capability_ready: bool,
	diagnostics: Array
) -> void:
	for category_id in definition.category_ids:
		if not SchemaId.is_valid_category(category_id):
			continue
		if category_ready and category_registry.is_valid() and not category_registry.has_schema(category_id):
			_add_diagnostic(
				diagnostics,
				"category_unknown",
				str(definition.content_id),
				"definition.category_ids",
				"unknown category schema id: %s" % category_id
			)

	for capability_id in definition.capability_ids:
		if not SchemaId.is_valid_capability(capability_id):
			continue
		if capability_ready and capability_registry.is_valid() and not capability_registry.has_schema(capability_id):
			_add_diagnostic(
				diagnostics,
				"capability_unknown",
				str(definition.content_id),
				"definition.capability_ids",
				"unknown capability schema id: %s" % capability_id
			)


func _prepare_family_validators(candidates: Array, diagnostics: Array) -> Array:
	var result: Array = []
	for candidate in candidates:
		if candidate == null or not candidate is ContentFamilyValidator:
			_add_diagnostic(
				diagnostics,
				"family_validator_invalid",
				"<validation>",
				"configuration.family_validators",
				"expected ContentFamilyValidator"
			)
			continue
		var failures: Array[String] = candidate.validate_validator()
		if not failures.is_empty():
			for failure in failures:
				_add_diagnostic(
					diagnostics,
					"family_validator_invalid",
					"<validation>",
					"configuration.family_validators",
					str(failure)
				)
			continue
		result.append(candidate)
	return result


func _prepare_cycle_policy(candidate, diagnostics: Array):
	var policy = candidate
	if policy == null:
		policy = ReferenceCyclePolicy.new()
	if not policy is ReferenceCyclePolicy:
		_add_diagnostic(
			diagnostics,
			"cycle_policy_invalid",
			"<validation>",
			"configuration.reference_cycle_policy",
			"expected ContentReferenceCyclePolicy"
		)
		return ReferenceCyclePolicy.new()
	var failures: Array[String] = policy.validate_policy()
	if not failures.is_empty():
		for failure in failures:
			_add_diagnostic(
				diagnostics,
				"cycle_policy_invalid",
				"<validation>",
				"configuration.reference_cycle_policy",
				str(failure)
			)
		return ReferenceCyclePolicy.new()
	return policy


func _run_family_validators(
	definition,
	validators: Array,
	context: Dictionary,
	diagnostics: Array
) -> void:
	for validator in validators:
		if not validator.applies_to(definition):
			continue
		for failure in validator.validate_definition(definition, context):
			_add_diagnostic(
				diagnostics,
				"family_rule",
				str(definition.content_id),
				"family.%s" % str(validator.definition_family),
				str(failure)
			)


func _collect_reference_validation(
	definition,
	content_registry,
	selected: bool,
	edges: Array,
	diagnostics: Array
) -> void:
	var references: Array = definition.validation_references()
	for candidate in references:
		if candidate == null or not candidate is ContentReference:
			if selected:
				_add_diagnostic(
					diagnostics,
					"reference_type_invalid",
					str(definition.content_id),
					"definition.references",
					"expected ContentReference"
				)
			continue

		var reference_failures: Array[String] = candidate.validate_reference()
		if not candidate.source_id.is_empty() and candidate.source_id != definition.content_id:
			reference_failures.append(
				"reference source id '%s' does not match owning definition '%s'" % [
					candidate.source_id,
					definition.content_id,
				]
			)
		reference_failures.sort()
		if not reference_failures.is_empty():
			if selected:
				for failure in reference_failures:
					_add_diagnostic(
						diagnostics,
						"reference_invalid",
						str(definition.content_id),
						"reference.%s" % str(candidate.role),
						str(failure)
					)
			continue

		if candidate.target_id.is_empty() and not candidate.required:
			continue

		var resolved: Dictionary = content_registry.resolve(
			candidate.target_id,
			candidate.expected_family
		)
		var resolution_failures: Array = resolved.get("diagnostics", [])
		if not resolution_failures.is_empty():
			if selected:
				for failure in resolution_failures:
					_add_diagnostic(
						diagnostics,
						"reference_resolution",
						str(definition.content_id),
						"reference.%s" % str(candidate.role),
						str(failure)
					)
			continue

		edges.append({
			"source_id": str(definition.content_id),
			"role": str(candidate.role),
			"target_id": str(candidate.target_id),
		})


func _validate_reference_cycles(
	edges: Array,
	selected_ids: Dictionary,
	cycle_policy,
	diagnostics: Array
) -> void:
	for component in _strongly_connected_components(edges):
		if not _component_is_cyclic(component, edges):
			continue
		var internal_edges: Array = _component_edges(component, edges)
		if cycle_policy.allows_cycle_edges(internal_edges):
			continue
		var nodes: Array[String] = []
		for node in component:
			nodes.append(str(node))
		nodes.sort()
		var edge_labels: Array[String] = []
		for edge in internal_edges:
			edge_labels.append("%s -[%s]-> %s" % [
				str(edge.get("source_id", "")),
				str(edge.get("role", "")),
				str(edge.get("target_id", "")),
			])
		edge_labels.sort()
		var message: String = "disallowed reference cycle nodes=%s edges=%s" % [
			",".join(nodes),
			"; ".join(edge_labels),
		]
		for node in nodes:
			if selected_ids.has(node):
				_add_diagnostic(
					diagnostics,
					"reference_cycle",
					node,
					"definition.references",
					message
				)


func _strongly_connected_components(edges: Array) -> Array:
	var nodes: Dictionary = {}
	var adjacency: Dictionary = {}
	for edge in edges:
		var source_id: String = str(edge.get("source_id", ""))
		var target_id: String = str(edge.get("target_id", ""))
		nodes[source_id] = true
		nodes[target_id] = true
	for node in nodes.keys():
		adjacency[str(node)] = []
	for edge in edges:
		var source_id: String = str(edge.get("source_id", ""))
		var target_id: String = str(edge.get("target_id", ""))
		var neighbors: Array = adjacency[source_id]
		if not neighbors.has(target_id):
			neighbors.append(target_id)
			neighbors.sort()
		adjacency[source_id] = neighbors

	var ordered_nodes: Array[String] = []
	for node in nodes.keys():
		ordered_nodes.append(str(node))
	ordered_nodes.sort()

	var indices: Dictionary = {}
	var lowlinks: Dictionary = {}
	var stack: Array[String] = []
	var on_stack: Dictionary = {}
	var counter: Array[int] = [0]
	var components: Array = []
	for node in ordered_nodes:
		if not indices.has(node):
			_tarjan_visit(
				node,
				adjacency,
				indices,
				lowlinks,
				stack,
				on_stack,
				counter,
				components
			)
	return components


func _tarjan_visit(
	node: String,
	adjacency: Dictionary,
	indices: Dictionary,
	lowlinks: Dictionary,
	stack: Array[String],
	on_stack: Dictionary,
	counter: Array[int],
	components: Array
) -> void:
	indices[node] = counter[0]
	lowlinks[node] = counter[0]
	counter[0] += 1
	stack.append(node)
	on_stack[node] = true

	var neighbors: Array = adjacency.get(node, [])
	for raw_neighbor in neighbors:
		var neighbor: String = str(raw_neighbor)
		if not indices.has(neighbor):
			_tarjan_visit(
				neighbor,
				adjacency,
				indices,
				lowlinks,
				stack,
				on_stack,
				counter,
				components
			)
			lowlinks[node] = mini(int(lowlinks[node]), int(lowlinks[neighbor]))
		elif bool(on_stack.get(neighbor, false)):
			lowlinks[node] = mini(int(lowlinks[node]), int(indices[neighbor]))

	if int(lowlinks[node]) != int(indices[node]):
		return
	var component: Array[String] = []
	while not stack.is_empty():
		var member: String = stack.pop_back()
		on_stack[member] = false
		component.append(member)
		if member == node:
			break
	component.sort()
	components.append(component)


func _component_is_cyclic(component: Array, edges: Array) -> bool:
	if component.size() > 1:
		return true
	if component.is_empty():
		return false
	var node: String = str(component[0])
	for edge in edges:
		if str(edge.get("source_id", "")) == node and str(edge.get("target_id", "")) == node:
			return true
	return false


func _component_edges(component: Array, edges: Array) -> Array:
	var members: Dictionary = {}
	for node in component:
		members[str(node)] = true
	var result: Array = []
	for edge in edges:
		var source_id: String = str(edge.get("source_id", ""))
		var target_id: String = str(edge.get("target_id", ""))
		if members.has(source_id) and members.has(target_id):
			result.append(edge)
	return result


func _is_selected_definition(
	definition,
	target_ids: Dictionary,
	target_family: String,
	id_targeting_requested: bool
) -> bool:
	if id_targeting_requested and not target_ids.has(str(definition.content_id)):
		return false
	if not target_family.is_empty() and str(definition.definition_family) != target_family:
		return false
	return true


static func _candidate_label(definition) -> String:
	var content_id: String = str(definition.content_id)
	return content_id if not content_id.is_empty() else "<unidentified-definition>"


static func _add_diagnostic(
	diagnostics: Array,
	code: String,
	source_id: String,
	path: String,
	message: String
) -> void:
	diagnostics.append({
		"code": code,
		"source_id": source_id,
		"path": path,
		"message": message,
	})


static func _canonicalize_diagnostics(diagnostics: Array) -> Array:
	var by_key: Dictionary = {}
	for diagnostic in diagnostics:
		var key: String = "%s|%s|%s|%s" % [
			str(diagnostic.get("code", "")),
			str(diagnostic.get("source_id", "")),
			str(diagnostic.get("path", "")),
			str(diagnostic.get("message", "")),
		]
		by_key[key] = diagnostic
	var keys: Array[String] = []
	for key in by_key.keys():
		keys.append(str(key))
	keys.sort()
	var result: Array = []
	for key in keys:
		var diagnostic: Dictionary = by_key[key]
		result.append({
			"code": str(diagnostic.get("code", "")),
			"source_id": str(diagnostic.get("source_id", "")),
			"path": str(diagnostic.get("path", "")),
			"message": str(diagnostic.get("message", "")),
		})
	return result
extends RefCounted

const ContentId := preload("res://core/content/identity/content_id.gd")
const SchemaId := preload("res://core/content/schema/schema_id.gd")
const SemanticRoleSchema := preload("res://core/content/schema/semantic_role_schema.gd")
const SemanticRoleSchemaRegistry := preload("res://core/content/schema/semantic_role_schema_registry.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_schema_id_namespaces(failures)
	_test_registry_order_independence(failures)
	_test_registry_failures(failures)
	return failures


static func _test_schema_id_namespaces(failures: Array[String]) -> void:
	_expect_true(
		failures,
		"valid animation role schema id",
		SchemaId.is_valid_animation_role("animation_role.action.parry")
	)
	_expect_true(
		failures,
		"valid rig role schema id",
		SchemaId.is_valid_rig_role("rig_role.socket.hand.right")
	)
	_expect_true(
		failures,
		"animation role rejects rig namespace",
		not SchemaId.is_valid_animation_role("rig_role.hand.right")
	)
	_expect_true(
		failures,
		"rig role rejects animation namespace",
		not SchemaId.is_valid_rig_role("animation_role.action.parry")
	)
	_expect_equal(
		failures,
		"namespace_of animation role",
		SchemaId.namespace_of("animation_role.action.parry"),
		"animation_role"
	)
	_expect_equal(
		failures,
		"namespace_of rig role",
		SchemaId.namespace_of("rig_role.socket.hand.right"),
		"rig_role"
	)
	_expect_true(
		failures,
		"ContentId rejects animation role as authored content",
		not ContentId.is_valid("animation_role.action.parry")
	)
	_expect_true(
		failures,
		"ContentId rejects rig role as authored content",
		not ContentId.is_valid("rig_role.socket.hand.right")
	)
	_expect_true(
		failures,
		"ContentId reserves animation_role family",
		not ContentId.is_valid_family("animation_role")
	)
	_expect_true(
		failures,
		"ContentId reserves rig_role family",
		not ContentId.is_valid_family("rig_role")
	)


static func _test_registry_order_independence(failures: Array[String]) -> void:
	var schemas_a: Array = [
		_role("animation_role.action.parry"),
		_role("rig_role.socket.hand.right"),
		_role("animation_role.locomotion.idle"),
	]
	var schemas_b: Array = [
		_role("animation_role.locomotion.idle"),
		_role("animation_role.action.parry"),
		_role("rig_role.socket.hand.right"),
	]
	var registry_a = SemanticRoleSchemaRegistry.new()
	var diagnostics_a: Array[String] = registry_a.index_schemas(schemas_a)
	var registry_b = SemanticRoleSchemaRegistry.new()
	var diagnostics_b: Array[String] = registry_b.index_schemas(schemas_b)
	if not diagnostics_a.is_empty() or not diagnostics_b.is_empty():
		failures.append("SemanticRoleSchemaRegistry rejected valid roles: %s / %s" % [diagnostics_a, diagnostics_b])
		return
	_expect_equal(
		failures,
		"semantic role canonical manifest is order independent",
		registry_a.canonical_manifest(),
		registry_b.canonical_manifest()
	)
	_expect_true(
		failures,
		"registry resolves animation role",
		registry_a.has_animation_role("animation_role.action.parry")
	)
	_expect_true(
		failures,
		"registry resolves rig role",
		registry_a.has_rig_role("rig_role.socket.hand.right")
	)
	_expect_equal(
		failures,
		"animation namespace filtering",
		registry_a.schema_ids_for_namespace("animation_role"),
		["animation_role.action.parry", "animation_role.locomotion.idle"]
	)


static func _test_registry_failures(failures: Array[String]) -> void:
	var duplicate_a = SemanticRoleSchemaRegistry.new()
	var duplicate_b = SemanticRoleSchemaRegistry.new()
	var role_v1 = _role("animation_role.action.parry", 1)
	var role_v2 = _role("animation_role.action.parry", 2)
	var diagnostics_a: Array[String] = duplicate_a.index_schemas([role_v1, role_v2])
	var diagnostics_b: Array[String] = duplicate_b.index_schemas([role_v2, role_v1])
	_expect_equal(
		failures,
		"duplicate semantic role diagnostics are deterministic",
		diagnostics_a,
		diagnostics_b
	)
	_expect_true(
		failures,
		"duplicate semantic role rejected clearly",
		_has_fragment(diagnostics_a, "duplicate semantic role schema id")
	)
	_expect_true(
		failures,
		"duplicate semantic role is not first/last-wins",
		not duplicate_a.has_schema("animation_role.action.parry")
	)

	var invalid_revision = _role("rig_role.hand.right", 0)
	_expect_true(
		failures,
		"semantic role revision zero rejected",
		_has_fragment(invalid_revision.validate_schema(), "revision must be >= 1")
	)

	var incompatible = SemanticRoleSchemaRegistry.new()
	_expect_true(
		failures,
		"incompatible semantic role schema type rejected",
		_has_fragment(incompatible.index_schemas([Resource.new()]), "incompatible semantic role schema type")
	)


static func _role(schema_id: String, revision: int = 1):
	return SemanticRoleSchema.new().configure(schema_id, revision)


static func _has_fragment(values: Array, fragment: String) -> bool:
	for value in values:
		if str(value).contains(fragment):
			return true
	return false


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(
	failures: Array[String],
	label: String,
	actual: Variant,
	expected: Variant
) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])

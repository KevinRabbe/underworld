extends RefCounted
class_name UnderworldGeneratedEntranceBootstrapAdapter

## Production-facing semantic boundary for bootstrapping one independently
## selected generated entrance. This adapter accepts no MAP-015 constants or
## fixture toggle and delegates only to the generic cave-runtime authority.
static func bootstrap(
	controller,
	world_seed: int,
	region_coord: Vector2i,
	entrance_id: String
) -> Array[String]:
	if controller == null or not controller.has_method("bootstrap_generated_entrance"):
		return ["Generated entrance bootstrap requires generic cave runtime authority"]
	if entrance_id.is_empty():
		return ["Generated entrance bootstrap requires a generated entrance id"]
	var result = controller.call("bootstrap_generated_entrance", world_seed, region_coord, entrance_id)
	if not result is Array:
		return ["Generated entrance bootstrap returned malformed diagnostics"]
	var diagnostics: Array[String] = []
	for diagnostic in result:
		diagnostics.append(str(diagnostic))
	return diagnostics
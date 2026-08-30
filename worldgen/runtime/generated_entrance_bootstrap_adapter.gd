extends RefCounted
class_name UnderworldGeneratedEntranceBootstrapAdapter

## Production-facing compatibility seam for the accepted cave-runtime bootstrap.
##
## The runtime implementation predates ordinary entrance selection and its legacy
## method is named `bootstrap_fixture`, but it is parameterized entirely by the
## supplied world seed, generated region coordinate and generated entrance id.
## This adapter deliberately accepts no MAP-015 constants or fixture toggle and
## gives production composition a semantic generated-entrance boundary until the
## runtime method can be renamed without widening M3 closeout scope.
static func bootstrap(
	controller,
	world_seed: int,
	region_coord: Vector2i,
	entrance_id: String
) -> Array[String]:
	if controller == null or not controller.has_method("bootstrap_fixture"):
		return ["Generated entrance bootstrap requires cave runtime bootstrap authority"]
	if entrance_id.is_empty():
		return ["Generated entrance bootstrap requires a generated entrance id"]
	var result = controller.call("bootstrap_fixture", world_seed, region_coord, entrance_id)
	if not result is Array:
		return ["Generated entrance bootstrap returned malformed diagnostics"]
	var diagnostics: Array[String] = []
	for diagnostic in result:
		diagnostics.append(str(diagnostic))
	return diagnostics
